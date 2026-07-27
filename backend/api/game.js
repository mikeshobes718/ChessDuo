import { Chess } from "chess.js";
import {
  applyMove,
  colorForToken,
  createPlayerToken,
  createRoomCode,
  hashPlayerToken,
  normalizeRoomCode,
  publicGame,
} from "../lib/game.js";

function requireEnvironment() {
  const values = {
    supabaseUrl: process.env.SUPABASE_URL,
    serviceKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  };
  if (!values.supabaseUrl || !values.serviceKey) {
    throw new Error("Server configuration is incomplete");
  }
  return values;
}

function supabaseHeaders(extra = {}) {
  const { serviceKey } = requireEnvironment();
  return {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    ...extra,
  };
}

async function databaseRequest(path, options = {}) {
  const { supabaseUrl } = requireEnvironment();
  const response = await fetch(`${supabaseUrl.replace(/\/$/, "")}/rest/v1/${path}`, {
    ...options,
    headers: supabaseHeaders(options.headers),
  });
  if (!response.ok) {
    const error = new Error(`Database request failed with status ${response.status}`);
    error.status = response.status === 409 ? 409 : 500;
    throw error;
  }
  if (response.status === 204) return null;
  return response.json();
}

async function getGame(roomCode) {
  const query = new URLSearchParams({
    room_code: `eq.${normalizeRoomCode(roomCode)}`,
    select: "*",
    limit: "1",
  });
  const rows = await databaseRequest(`games?${query}`);
  return rows[0] ?? null;
}

async function insertGame(game) {
  const rows = await databaseRequest("games", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify(game),
  });
  return rows[0];
}

async function updateGame(game, expectedVersion, changes) {
  const query = new URLSearchParams({
    id: `eq.${game.id}`,
    version: `eq.${expectedVersion}`,
    select: "*",
  });
  const rows = await databaseRequest(`games?${query}`, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify({
      ...changes,
      version: expectedVersion + 1,
      updated_at: new Date().toISOString(),
    }),
  });
  if (!rows.length) {
    const error = new Error("Game changed; refresh and try again");
    error.status = 409;
    throw error;
  }
  return rows[0];
}

function validName(value) {
  const name = String(value ?? "").trim();
  if (!name || name.length > 40) throw new Error("Name must be 1 to 40 characters");
  return name;
}

function requestedVersion(value) {
  if (!Number.isInteger(value) || value < 0) throw new Error("A valid version is required");
  return value;
}

function authenticatedGame(game, token) {
  if (!game) {
    const error = new Error("Room not found");
    error.status = 404;
    throw error;
  }
  const color = colorForToken(game, token);
  if (!color) {
    const error = new Error("Invalid player token");
    error.status = 401;
    throw error;
  }
  return color;
}

function fallbackCoaching(kind, move, legalMoves) {
  if (kind === "hint") {
    const candidate = legalMoves[0];
    return candidate
      ? `Try ${candidate.san}. Before moving, check whether your king and pieces stay safe.`
      : "There are no legal moves in this position.";
  }
  return `You played ${move.san}. Now check your opponent's threats before planning your next move.`;
}

async function coachingText({ kind, fen, color, move, legalMoves }) {
  const fallback = fallbackCoaching(kind, move, legalMoves);
  if (!process.env.OPENROUTER_API_KEY) return fallback;

  const instruction =
    kind === "hint"
      ? "Give one helpful hint without overexplaining. You may name one legal move."
      : `The player just made ${move.san}. Give one encouraging lesson about that move or the new position.`;
  try {
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: process.env.OPENROUTER_MODEL || "openai/gpt-4o-mini",
        temperature: 0.3,
        max_tokens: 80,
        messages: [
          {
            role: "system",
            content:
              "You are a friendly chess coach for beginners. Reply in at most two short sentences. Be concrete and concise.",
          },
          {
            role: "user",
            content: `${instruction}\nPlayer: ${color}\nFEN: ${fen}\nLegal moves: ${legalMoves
              .map((item) => item.san)
              .join(", ")}`,
          },
        ],
      }),
      signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) return fallback;
    const data = await response.json();
    return String(data.choices?.[0]?.message?.content ?? "").trim() || fallback;
  } catch {
    return fallback;
  }
}

async function createGame(body) {
  const token = createPlayerToken();
  const name = validName(body.name);
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      const game = await insertGame({
        room_code: createRoomCode(),
        white_name: name,
        white_token_hash: hashPlayerToken(token),
        fen: new Chess().fen(),
        status: "waiting",
        coach_text: "Share the room code with your opponent.",
      });
      return { ...publicGame(game, "white"), playerToken: token };
    } catch (error) {
      if (error.status !== 409 || attempt === 4) throw error;
    }
  }
}

async function joinGame(body) {
  const game = await getGame(body.roomCode);
  if (!game) {
    const error = new Error("Room not found");
    error.status = 404;
    throw error;
  }
  if (game.status !== "waiting" || game.black_token_hash) {
    const error = new Error("Room is not available");
    error.status = 409;
    throw error;
  }
  const token = createPlayerToken();
  const updated = await updateGame(game, game.version, {
    black_name: validName(body.name),
    black_token_hash: hashPlayerToken(token),
    status: "active",
    coach_text: "White moves first. Look for safe ways to control the center.",
  });
  return { ...publicGame(updated, "black"), playerToken: token };
}

async function gameState(body) {
  const game = await getGame(body.roomCode);
  const color = authenticatedGame(game, body.playerToken);
  return publicGame(game, color);
}

async function makeMove(body) {
  const game = await getGame(body.roomCode);
  const color = authenticatedGame(game, body.playerToken);
  if (game.status !== "active") throw new Error("Game is not active");
  const version = requestedVersion(body.version);
  if (version !== game.version) {
    const error = new Error("Game changed; refresh and try again");
    error.status = 409;
    throw error;
  }

  const result = applyMove(game.fen, color, body.move);
  const coachText = await coachingText({
    kind: "move",
    fen: result.fen,
    color,
    move: result.move,
    legalMoves: result.legalMoves,
  });
  const updated = await updateGame(game, version, {
    fen: result.fen,
    status: result.status,
    coach_text: coachText,
    last_move: result.move,
  });
  return publicGame(updated, color);
}

async function hint(body) {
  const game = await getGame(body.roomCode);
  const color = authenticatedGame(game, body.playerToken);
  if (game.status !== "active") throw new Error("Game is not active");
  const turn = new Chess(game.fen).turn() === "w" ? "white" : "black";
  if (turn !== color) throw new Error("Hints are available on your turn");
  const version = requestedVersion(body.version);
  if (version !== game.version) {
    const error = new Error("Game changed; refresh and try again");
    error.status = 409;
    throw error;
  }
  const current = publicGame(game, color);
  const coachText = await coachingText({
    kind: "hint",
    fen: game.fen,
    color,
    legalMoves: current.legalMoves,
  });
  const updated = await updateGame(game, version, { coach_text: coachText });
  return publicGame(updated, color);
}

async function resign(body) {
  const game = await getGame(body.roomCode);
  const color = authenticatedGame(game, body.playerToken);
  if (game.status !== "active") throw new Error("Game is not active");
  const version = requestedVersion(body.version);
  if (version !== game.version) {
    const error = new Error("Game changed; refresh and try again");
    error.status = 409;
    throw error;
  }
  const winner = color === "white" ? "black" : "white";
  const updated = await updateGame(game, version, {
    status: `${winner}_won`,
    coach_text: `${color === "white" ? game.white_name : game.black_name} resigned.`,
  });
  return publicGame(updated, color);
}

function applyCors(request, response) {
  const origin = request.headers.origin;
  const allowed = String(process.env.CORS_ORIGINS ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  if (origin && allowed.includes(origin)) {
    response.setHeader("Access-Control-Allow-Origin", origin);
    response.setHeader("Vary", "Origin");
  }
  response.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

export default async function handler(request, response) {
  applyCors(request, response);
  if (request.method === "OPTIONS") return response.status(204).end();
  if (request.method !== "POST") {
    response.setHeader("Allow", "POST, OPTIONS");
    return response.status(405).json({ error: "Method not allowed" });
  }

  try {
    const body = request.body ?? {};
    const actions = {
      create: createGame,
      join: joinGame,
      state: gameState,
      move: makeMove,
      hint,
      resign,
    };
    const action = actions[body.action];
    if (!action) throw new Error("Unknown action");
    return response.status(200).json(await action(body));
  } catch (error) {
    const status = Number.isInteger(error.status) ? error.status : 400;
    const message = status >= 500 ? "Server request failed" : error.message;
    return response.status(status).json({ error: message });
  }
}
