import { Chess } from "npm:chess.js@1.4.0";

const APP_API_VERSION = "2.8.0";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const openRouterKey = Deno.env.get("OPENROUTER_API_KEY") ?? "";
const openAIKey = Deno.env.get("OPENAI_API_KEY") ?? "";
const apnsKey = Deno.env.get("APNS_KEY") ?? "";
const apnsKeyId = Deno.env.get("APNS_KEY_ID") ?? "";
const apnsTeamId = Deno.env.get("APNS_TEAM_ID") ?? "";
const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "";
const pushConfigured = Boolean(apnsKey && apnsKeyId && apnsTeamId && apnsBundleId);
const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

type AppLang = "en" | "pt" | "es";

function normalizeLanguage(value: unknown): AppLang {
  const raw = String(value ?? "en").trim().toLowerCase();
  if (raw.startsWith("pt")) return "pt";
  if (raw.startsWith("es")) return "es";
  return "en";
}

function languageName(lang: AppLang) {
  if (lang === "pt") return "Brazilian Portuguese";
  if (lang === "es") return "Spanish";
  return "English";
}

const uiCopy: Record<AppLang, {
  goal: string;
  whiteWon: string;
  blackWon: string;
  draw: string;
  createCoach: string;
  joinCoach: (white: string, joiner: string) => string;
  rematchCoach: string;
  pushJoined: (name: string, code: string) => string;
  pushYourTurn: (name: string, code: string) => string;
  pushDrawOffer: (name: string, code: string) => string;
  pushUndoOffer: (name: string, code: string) => string;
  pushDrawAnswer: (name: string, code: string) => string;
  pushUndoAnswer: (name: string, code: string) => string;
  pushRematch: (name: string, code: string) => string;
  pushGameOver: (text: string, code: string) => string;
  tipMove: (mover: string, from: string, to: string, san: string, next: string) => string;
  tipHint: (from: string, to: string, san: string) => string;
  tipHintNone: string;
  tipGeneric: string;
}> = {
  en: {
    goal: "Goal: put the other king in checkmate (attacked with no escape).",
    whiteWon: "White won",
    blackWon: "Black won",
    draw: "Draw",
    createCoach: "Share the room code (or tap Share). Colors are picked at random when your partner joins — White moves first. Tip: FaceTime while you play so you can talk through moves together.",
    joinCoach: (white, black) => `Both players are ready. ${white} plays White and moves first. ${black} plays Black. Tap a white piece to see where it can go.`,
    rematchCoach: "Rematch started. Same colors. White moves first. Goal: put the other king in checkmate.",
    pushJoined: (name, code) => `${name} joined room ${code}. It's your move.`,
    pushYourTurn: (name, code) => `${name} moved. It's your turn in room ${code}.`,
    pushDrawOffer: (name, code) => `${name} offers a draw in room ${code}.`,
    pushUndoOffer: (name, code) => `${name} asks to undo a move in room ${code}.`,
    pushDrawAnswer: (name, code) => `${name} answered your draw offer in room ${code}.`,
    pushUndoAnswer: (name, code) => `${name} answered your undo request in room ${code}.`,
    pushRematch: (name, code) => `${name} started a rematch in room ${code}.`,
    pushGameOver: (text, code) => `${text} in room ${code}. Tap to see the match review.`,    tipMove: (mover, from, to, san, next) => `Quick tip: ${mover} played ${from} → ${to} (${san}). ${next}, look for checks, captures, and threats.`,
    tipHint: (from, to, san) => `Quick tip: try ${from} → ${to} (${san}). Look for checks, captures, and safe developing moves.`,
    tipHintNone: "Quick tip: there are no legal moves in this position.",
    tipGeneric: "Quick tip: look for checks, captures, and threats.",
  },
  pt: {
    goal: "Objetivo: dar xeque-mate no rei adversário (atacado sem escape).",
    whiteWon: "Brancas venceram",
    blackWon: "Pretas venceram",
    draw: "Empate",
    createCoach: "Compartilhe o código da sala (ou toque em Compartilhar). As cores são sorteadas quando seu parceiro entrar — as Brancas começam. Dica: façam FaceTime enquanto jogam.",
    joinCoach: (white, black) => `Os dois estão prontos. ${white} joga de Brancas e começa. ${black} joga de Pretas. Toque numa peça branca para ver para onde ela pode ir.`,
    rematchCoach: "Revanche começada. Mesmas cores. As Brancas jogam primeiro. Objetivo: dar xeque-mate.",
    pushJoined: (name, code) => `${name} entrou na sala ${code}. Sua vez.`,
    pushYourTurn: (name, code) => `${name} jogou. Sua vez na sala ${code}.`,
    pushDrawOffer: (name, code) => `${name} propôs empate na sala ${code}.`,
    pushUndoOffer: (name, code) => `${name} pediu para desfazer na sala ${code}.`,
    pushDrawAnswer: (name, code) => `${name} respondeu à oferta de empate na sala ${code}.`,
    pushUndoAnswer: (name, code) => `${name} respondeu ao pedido de desfazer na sala ${code}.`,
    pushRematch: (name, code) => `${name} começou uma revanche na sala ${code}.`,
    tipMove: (mover, from, to, san, next) => `Dica rápida: ${mover} jogou ${from} → ${to} (${san}). ${next}, procure xeques, capturas e ameaças.`,
    tipHint: (from, to, san) => `Dica rápida: tente ${from} → ${to} (${san}). Procure xeques, capturas e desenvolvimento seguro.`,
    tipHintNone: "Dica rápida: não há jogadas legais nesta posição.",
    tipGeneric: "Dica rápida: procure xeques, capturas e ameaças.",
  },
  es: {
    goal: "Objetivo: dar jaque mate al rey rival (atacado sin escape).",
    whiteWon: "Ganaron las Blancas",
    blackWon: "Ganaron las Negras",
    draw: "Tablas",
    createCoach: "Comparte el código de la sala (o toca Compartir). Los colores se eligen al azar cuando tu pareja se una — las Blancas empiezan. Consejo: hagan FaceTime mientras juegan.",
    joinCoach: (white, black) => `Los dos están listos. ${white} juega con Blancas y mueve primero. ${black} juega con Negras. Toca una pieza blanca para ver a dónde puede ir.`,
    rematchCoach: "Revancha empezada. Mismos colores. Las Blancas mueven primero. Objetivo: dar jaque mate.",
    pushJoined: (name, code) => `${name} entró en la sala ${code}. Es tu turno.`,
    pushYourTurn: (name, code) => `${name} movió. Es tu turno en la sala ${code}.`,
    pushDrawOffer: (name, code) => `${name} propone tablas en la sala ${code}.`,
    pushUndoOffer: (name, code) => `${name} pide deshacer en la sala ${code}.`,
    pushDrawAnswer: (name, code) => `${name} respondió a tu oferta de tablas en la sala ${code}.`,
    pushUndoAnswer: (name, code) => `${name} respondió a tu pedido de deshacer en la sala ${code}.`,
    pushRematch: (name, code) => `${name} empezó una revancha en la sala ${code}.`,
    tipMove: (mover, from, to, san, next) => `Consejo rápido: ${mover} jugó ${from} → ${to} (${san}). ${next}, busca jaques, capturas y amenazas.`,
    tipHint: (from, to, san) => `Consejo rápido: prueba ${from} → ${to} (${san}). Busca jaques, capturas y desarrollo seguro.`,
    tipHintNone: "Consejo rápido: no hay jugadas legales en esta posición.",
    tipGeneric: "Consejo rápido: busca jaques, capturas y amenazas.",
  }
};


type Game = {
  id: string;
  room_code: string;
  white_name: string;
  black_name: string | null;
  white_token_hash: string;
  black_token_hash: string | null;
  fen: string;
  status: string;
  coach_text: string;
  coach_source?: string;
  coach_history?: Array<{ text: string; source: string; at: string }>;
  last_move: Record<string, string> | null;
  suggested_hint?: Record<string, string> | null;
  quiz?: Record<string, unknown> | null;
  move_count?: number;
  move_history?: MoveReviewEntry[];
  review?: MatchReview | null;
  draw_offer_by?: string | null;
  undo_offer_by?: string | null;
  white_hints_used?: number;
  black_hints_used?: number;
  hints_day?: string;
  version: number;
};

type MoveReviewEntry = {
  from: string;
  to: string;
  san: string;
  by: string;
  assisted: boolean;
  precision: number;
  label: string;
};

type PlayerReview = {
  name: string;
  accuracy: number;
  unaidedAccuracy: number | null;
  moveCount: number;
  assistedCount: number;
  bestPrecision: number;
  lowestPrecision: number;
};

type MatchReview = {
  white: PlayerReview;
  black: PlayerReview;
  moves: MoveReviewEntry[];
};

class HttpError extends Error {
  constructor(message: string, readonly status = 400) {
    super(message);
  }
}

const jsonHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: jsonHeaders });
}

function roomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
}

function playerToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function hashToken(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function base64UrlToBytes(value: string) {
  const padded = value.replaceAll("-", "+").replaceAll("_", "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  const raw = atob(padded);
  return Uint8Array.from(raw, (character) => character.charCodeAt(0));
}

function base64UrlEncode(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function pemToDer(pem: string) {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (character) => character.charCodeAt(0));
}

let cachedApnsJwt: { token: string; exp: number } | null = null;

async function apnsJwt() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedApnsJwt && cachedApnsJwt.exp - 60 > now) return cachedApnsJwt.token;
  const header = { alg: "ES256", kid: apnsKeyId };
  const payload = { iss: apnsTeamId, iat: now, exp: now + 1800 };
  const encode = (value: unknown) => base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
  const unsigned = `${encode(header)}.${encode(payload)}`;
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(apnsKey).buffer as ArrayBuffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, cryptoKey, new TextEncoder().encode(unsigned)));
  // APNs wants a raw r||s signature, not DER.
  const half = signature.length / 2;
  let r = signature.slice(0, half);
  let s = signature.slice(half);
  const trim = (part: Uint8Array) => {
    let start = 0;
    while (start < part.length - 1 && part[start] === 0) start += 1;
    let out = part.slice(start);
    if (out.length > 32) out = out.slice(out.length - 32);
    return out;
  };
  r = trim(r);
  s = trim(s);
  const rawSignature = new Uint8Array(64);
  rawSignature.set(r, Math.max(0, 32 - r.length));
  rawSignature.set(s, 32 + Math.max(0, 32 - s.length));
  const token = `${unsigned}.${base64UrlEncode(rawSignature)}`;
  cachedApnsJwt = { token, exp: now + 1800 };
  return token;
}

async function deletePushToken(apnsToken: string) {
  try {
    const query = new URLSearchParams({ apns_token: `eq.${apnsToken}` });
    await database(`push_tokens?${query}`, { method: "DELETE" });
  } catch (error) {
    console.error("deletePushToken failed", error);
  }
}

async function sendApns(deviceToken: string, payload: Record<string, unknown>, collapseId: string) {
  if (!pushConfigured) return;
  try {
    const jwt = await apnsJwt();
    const response = await fetch(`https://api.push.apple.com/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": apnsBundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-collapse-id": collapseId,
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) {
      const detail = await response.text();
      console.error("APNs delivery failed", response.status, detail);
      if (response.status === 410 || response.status === 403) {
        await deletePushToken(deviceToken);
      } else if (response.status === 400 && detail.includes("BadDeviceToken")) {
        await deletePushToken(deviceToken);
      }
    }
  } catch (error) {
    console.error("APNs delivery failed", error);
  }
}

type PushOptions = {
  title?: string;
  badge?: number;
  requiresTurnAlerts?: boolean;
};

// Shared delivery for every game push (turn, nudge, offers). Keeps sound, thread, and deep link consistent.
async function pushToColor(
  game: Game,
  color: "white" | "black",
  kind: string,
  alert: string,
  options: PushOptions = {},
) {
  if (!pushConfigured) return;
  const hash = color === "white" ? game.white_token_hash : game.black_token_hash;
  if (!hash) return;
  const query = new URLSearchParams({
    player_token_hash: `eq.${hash}`,
    select: "apns_token",
  });
  if (options.requiresTurnAlerts) {
    query.set("turn_alerts_enabled", "eq.true");
  }
  try {
    const rows = await database(`push_tokens?${query}`);
    for (const row of rows ?? []) {
      await sendApns(
        String(row.apns_token ?? ""),
        {
          aps: {
            alert: { title: options.title ?? "Chess Duo", body: alert },
            badge: options.badge ?? 1,
            sound: "default",
            "thread-id": game.room_code,
          },
          roomCode: game.room_code,
          kind,
          url: `chessduo://room/${game.room_code}`,
        },
        `${game.room_code}-${kind}`,
      );
    }
  } catch (error) {
    console.error("pushToColor failed", error);
  }
}

async function pushToOpponent(
  game: Game,
  color: string,
  kind: string,
  alert: string,
  options: PushOptions = {},
) {
  if (color !== "white" && color !== "black") return;
  await pushToColor(game, color === "white" ? "black" : "white", kind, alert, options);
}

// Pushes must outlive the response, otherwise the isolate can freeze before APNs answers.
function schedulePush(task: Promise<unknown>) {
  try {
    const waitUntil = (globalThis as { EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void } }).EdgeRuntime?.waitUntil;
    if (waitUntil) waitUntil(task);
    else task.catch((error) => console.error("push failed", error));
  } catch (error) {
    console.error("push scheduling failed", error);
  }
}

async function registerPush(body: Record<string, unknown>) {
  const token = String(body.playerToken ?? body.token ?? "");
  const apnsToken = String(body.apnsToken ?? "").trim();
  if (!token) throw new HttpError("Missing player token", 401);
  if (!/^[0-9a-fA-F]{64}$/.test(apnsToken)) throw new HttpError("Invalid device token", 400);
  const hash = await hashToken(token);
  const roomCode = String(body.roomCode ?? "").trim().toUpperCase() || null;
  const row: Record<string, unknown> = { player_token_hash: hash, room_code: roomCode, apns_token: apnsToken.toLowerCase(), updated_at: new Date().toISOString() };
  // Only write the toggle when the client sends it, so older builds never reset a user's choice.
  if (body.turnAlerts !== undefined) {
    row.turn_alerts_enabled = body.turnAlerts === true;
  }
  // Atomic upsert on apns_token: two racing registrations must not collide on the unique index.
  await database(`push_tokens?on_conflict=apns_token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Prefer: "return=representation,resolution=merge-duplicates",
    },
    body: JSON.stringify(row),
  });
  return { registered: true };
}

async function database(path: string, init: RequestInit = {}) {
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    const detail = await response.text();
    console.error("Database request failed", response.status, detail);
    throw new HttpError(
      response.status === 409 ? "Room code collision" : "Database request failed",
      response.status === 409 ? 409 : 500,
    );
  }
  return response.status === 204 ? null : response.json();
}

async function getGame(code: string): Promise<Game | null> {
  const query = new URLSearchParams({
    room_code: `eq.${String(code ?? "").trim().toUpperCase()}`,
    select: "*",
    limit: "1",
  });
  const rows = await database(`games?${query}`);
  return rows?.[0] ?? null;
}

async function insertGame(game: Record<string, unknown>): Promise<Game> {
  const rows = await database("games", {
    method: "POST",
    headers: { "Content-Type": "application/json", Prefer: "return=representation" },
    body: JSON.stringify(game),
  });
  return rows[0];
}

async function updateGame(game: Game, changes: Record<string, unknown>): Promise<Game> {
  const query = new URLSearchParams({
    id: `eq.${game.id}`,
    version: `eq.${game.version}`,
    select: "*",
  });
  const rows = await database(`games?${query}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json", Prefer: "return=representation" },
    body: JSON.stringify({
      ...changes,
      version: game.version + 1,
      updated_at: new Date().toISOString(),
    }),
  });
  if (!rows.length) throw new HttpError("Game changed; refresh and try again", 409);
  return rows[0];
}

async function colorFor(game: Game, token: string) {
  const hash = await hashToken(String(token ?? ""));
  if (hash === game.white_token_hash) return "white";
  if (hash === game.black_token_hash) return "black";
  throw new HttpError("Invalid player token", 401);
}

function legalMoves(chess: Chess) {
  return chess.moves({ verbose: true }).map(({ from, to, promotion, san, captured, flags }) => ({
    from,
    to,
    ...(promotion ? { promotion } : {}),
    san,
    captured: captured ?? null,
    isCapture: Boolean(captured) || String(flags).includes("c"),
    isCheck: String(san).includes("+") || String(san).includes("#"),
  }));
}

function resultText(status: string, lang: AppLang = "en") {
  const copy = uiCopy[lang];
  if (status === "white_won") return copy.whiteWon;
  if (status === "black_won") return copy.blackWon;
  if (status === "draw") return copy.draw;
  return null;
}

type Difficulty = "easy" | "medium" | "hard";

const pieceValues: Record<string, number> = {
  p: 100,
  n: 320,
  b: 330,
  r: 500,
  q: 900,
  k: 20000,
};

// Piece-square tables (white perspective; black mirrored). Encourages center control and development.
const pst: Record<string, number[]> = {
  p: [
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ],
  n: [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ],
  b: [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ],
  r: [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ],
  q: [
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ],
  k: [
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
  ],
};

function normalizeDifficulty(value: unknown): Difficulty {
  const raw = String(value ?? "medium").trim().toLowerCase();
  if (raw === "easy" || raw === "hard") return raw;
  return "medium";
}

function difficultySettings(difficulty: Difficulty) {
  // Stronger than before, but stay under Edge Function WORKER_RESOURCE_LIMIT.
  if (difficulty === "easy") {
    return { depth: 2, maxDepth: 2, quiescePly: 0, nodeLimit: 4500, rootMoves: 12, noise: 35, noiseCap: 80, blunderChance: 0.1, timeMs: 0 };
  }
  if (difficulty === "hard") {
    // Iterative deepening 2 -> 4 under a wall-clock cap: the clock, not the position, decides how deep Hard gets.
    return { depth: 2, maxDepth: 4, quiescePly: 4, nodeLimit: 30000, rootMoves: 20, noise: 0, noiseCap: 0, blunderChance: 0, timeMs: 1500 };
  }
  return { depth: 2, maxDepth: 2, quiescePly: 2, nodeLimit: 8000, rootMoves: 16, noise: 10, noiseCap: 28, blunderChance: 0.02, timeMs: 0 };
}

class SearchTimeout extends Error {}

function openingBookPick(chess: Chess): EngineMove | null {
  // Compact book for the first few moves — stops the computer opening like a random beginner.
  const key = chess.fen().split(" ").slice(0, 2).join(" ");
  const lines: Record<string, string[]> = {
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w": ["e2e4", "d2d4", "c2c4", "g1f3"],
    "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b": ["e7e5", "c7c5", "e7e6", "c7c6", "g8f6"],
    "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b": ["d7d5", "g8f6", "e7e6", "c7c5"],
    "rnbqkbnr/pppppppp/8/8/2P5/8/PP1PPPPP/RNBQKBNR b": ["e7e5", "c7c5", "g8f6", "e7e6"],
    "rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b": ["d7d5", "g8f6", "c7c5", "e7e6"],
    "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w": ["g1f3", "f1c4", "b1c3", "d2d4"],
    "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w": ["g1f3", "b1c3", "d2d4", "c2c3"],
    "rnbqkb1r/pppppppp/5n2/8/4P3/8/PPPP1PPP/RNBQKBNR w": ["e4e5", "b1c3", "d2d4", "g1f3"],
    "rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w": ["c2c4", "g1f3", "b1c3", "c1f4"],
    "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b": ["b8c6", "g8f6", "d7d6"],
    "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w": ["f1b5", "f1c4", "d2d4", "b1c3"],
    "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b": ["d7d6", "e7e6", "b8c6", "g8f6"],
  };
  const choices = lines[key];
  if (!choices?.length) return null;
  const legal = chess.moves({ verbose: true }) as EngineMove[];
  const matched = choices
    .map((uci) => legal.find((move) => `${move.from}${move.to}${move.promotion ?? ""}` === uci || `${move.from}${move.to}` === uci))
    .filter(Boolean) as EngineMove[];
  if (!matched.length) return null;
  return matched[Math.floor(Math.random() * matched.length)];
}

function squareIndex(color: "w" | "b", rank: number, file: number) {
  return color === "w" ? rank * 8 + file : (7 - rank) * 8 + file;
}

function evaluateBoard(chess: Chess): number {
  // One legal-move generation per eval, reused for mate/stalemate/mobility. chess.js's
  // isCheckmate/isStalemate/isDraw would each regenerate the same list.
  const legalCount = searchChess(chess)._moves().length;
  const inCheckNow = chess.inCheck();
  if (inCheckNow && legalCount === 0) {
    return chess.turn() === "w" ? -100000 : 100000;
  }
  if (legalCount === 0) {
    return 0;
  }
  if (chess.isDrawByFiftyMoves() || chess.isInsufficientMaterial() || chess.isThreefoldRepetition()) {
    return 0;
  }

  let score = 0;
  const board = chess.board();
  let whiteDev = 0;
  let blackDev = 0;
  for (let rank = 0; rank < 8; rank += 1) {
    for (let file = 0; file < 8; file += 1) {
      const piece = board[rank][file];
      if (!piece) continue;
      const table = pst[piece.type] ?? pst.p;
      const value = (pieceValues[piece.type] ?? 0) + (table[squareIndex(piece.color, rank, file)] ?? 0);
      score += piece.color === "w" ? value : -value;
      // Reward getting knights/bishops off the back rank.
      if ((piece.type === "n" || piece.type === "b") && ((piece.color === "w" && rank < 7) || (piece.color === "b" && rank > 0))) {
        if (piece.color === "w") whiteDev += 12;
        else blackDev += 12;
      }
    }
  }
  score += whiteDev - blackDev;

  const rights = chess.fen().split(" ")[2] ?? "";
  if (rights.includes("K") || rights.includes("Q")) score += 18;
  if (rights.includes("k") || rights.includes("q")) score -= 18;

  // Castled kings are usually safer — reward being tucked away.
  for (const square of ["g1", "c1"]) {
    const king = (chess as { get: (s: string) => { type: string; color: string } | null }).get(square);
    if (king?.type === "k" && king.color === "w") score += 22;
  }
  for (const square of ["g8", "c8"]) {
    const king = (chess as { get: (s: string) => { type: string; color: string } | null }).get(square);
    if (king?.type === "k" && king.color === "b") score -= 22;
  }

  // Center occupation bonus.
  for (const square of ["d4", "e4", "d5", "e5"]) {
    const piece = (chess as { get: (s: string) => { type: string; color: string } | null }).get(square);
    if (!piece) continue;
    const bonus = piece.type === "p" ? 18 : 10;
    score += piece.color === "w" ? bonus : -bonus;
  }

  const mobility = searchChess(chess)._moves().length;
  score += chess.turn() === "w" ? mobility * 4 : -mobility * 4;
  if (chess.inCheck()) {
    score += chess.turn() === "w" ? -35 : 35;
  }
  return score;
}

type EngineMove = {
  from: string;
  to: string;
  san: string;
  captured?: string;
  flags: string;
  piece: string;
  promotion?: string;
};

function orderMoves(moves: EngineMove[]) {
  const center = new Set(["d4", "e4", "d5", "e5", "c4", "f4", "c5", "f5"]);
  return [...moves].sort((a, b) => {
    let scoreA = 0;
    let scoreB = 0;
    if (a.captured) scoreA += 10 * (pieceValues[a.captured] ?? 0) - (pieceValues[a.piece] ?? 0);
    if (b.captured) scoreB += 10 * (pieceValues[b.captured] ?? 0) - (pieceValues[b.piece] ?? 0);
    if (a.san.includes("#")) scoreA += 100000;
    if (b.san.includes("#")) scoreB += 100000;
    if (a.san.includes("+")) scoreA += 55;
    if (b.san.includes("+")) scoreB += 55;
    if (a.flags.includes("k") || a.flags.includes("q")) scoreA += 45;
    if (b.flags.includes("k") || b.flags.includes("q")) scoreB += 45;
    if (a.promotion) scoreA += 800;
    if (b.promotion) scoreB += 800;
    if (center.has(a.to)) scoreA += 18;
    if (center.has(b.to)) scoreB += 18;
    if (a.piece === "n" || a.piece === "b") scoreA += 8;
    if (b.piece === "n" || b.piece === "b") scoreB += 8;
    return scoreB - scoreA;
  });
}

// chess.js's public move APIs regenerate every legal move (plus SAN strings and FENs)
// on each call, which makes them ~100x slower than the internal generator. The edge
// function pins chess.js@1.4.0, so the search drives _moves/_makeMove/_undoMove
// directly and only pays for pretty moves at the root.
const SEARCH_PROMOTION = 16;
const SEARCH_KSIDE = 32;
const SEARCH_QSIDE = 64;

type SearchMove = {
  from: number;
  to: number;
  flags: number;
  piece: string;
  captured?: string;
  promotion?: string;
};

type SearchChess = {
  _moves: () => SearchMove[];
  _makeMove: (move: SearchMove) => void;
  _undoMove: () => unknown;
};

function searchChess(chess: Chess) {
  return chess as unknown as SearchChess;
}

function algebraicSquare(square: number) {
  return "abcdefgh"[square & 15] + "87654321"[square >> 4];
}

function searchMoveKey(move: { from: number; to: number; promotion?: string }) {
  return `${algebraicSquare(move.from)}${algebraicSquare(move.to)}${move.promotion ?? ""}`;
}

function orderSearchMoves(moves: SearchMove[]) {
  const scored = moves.map((move) => {
    let score = 0;
    if (move.captured) score += 10 * (pieceValues[move.captured] ?? 0) - (pieceValues[move.piece] ?? 0);
    if (move.promotion) score += 800;
    if (move.flags & (SEARCH_KSIDE | SEARCH_QSIDE)) score += 45;
    const file = move.to & 15;
    const rank = move.to >> 4;
    if (file >= 2 && file <= 5 && rank >= 3 && rank <= 4) score += 18;
    if (move.piece === "n" || move.piece === "b") score += 8;
    return { move, score };
  });
  scored.sort((a, b) => b.score - a.score);
  return scored.map((item) => item.move);
}

function quiescence(
  chess: Chess,
  alpha: number,
  beta: number,
  side: number,
  ply: number,
  counter: { nodes: number; limit: number; deadline: number },
): number {
  counter.nodes += 1;
  if ((counter.nodes & 63) === 0 && Date.now() > counter.deadline) throw new SearchTimeout();
  const standPat = side * evaluateBoard(chess);
  if (ply <= 0 || counter.nodes > counter.limit) return standPat;
  if (standPat >= beta) return beta;
  if (standPat > alpha) alpha = standPat;

  const game = searchChess(chess);
  const captures = orderSearchMoves(
    game._moves().filter((move) => Boolean(move.captured)),
  ).slice(0, 12);
  for (const move of captures) {
    game._makeMove(move);
    const score = -quiescence(chess, -beta, -alpha, -side, ply - 1, counter);
    game._undoMove();
    if (score >= beta) return beta;
    if (score > alpha) alpha = score;
  }
  return alpha;
}

function negamax(
  chess: Chess,
  depth: number,
  alpha: number,
  beta: number,
  side: number,
  quiescePly: number,
  counter: { nodes: number; limit: number; deadline: number },
): number {
  counter.nodes += 1;
  if ((counter.nodes & 63) === 0 && Date.now() > counter.deadline) throw new SearchTimeout();
  if (counter.nodes > counter.limit) return side * evaluateBoard(chess);
  if (depth <= 0) return quiescence(chess, alpha, beta, side, quiescePly, counter);

  // No legal moves means mate or stalemate; evaluateBoard scores both. Skipping isGameOver()
  // here avoids a second throwaway move generation at every node.
  const moves = orderSearchMoves(searchChess(chess)._moves());
  if (!moves.length) return side * evaluateBoard(chess);

  const game = searchChess(chess);
  let best = -Infinity;
  for (const move of moves) {
    game._makeMove(move);
    const score = -negamax(chess, depth - 1, -beta, -alpha, -side, quiescePly, counter);
    game._undoMove();
    if (score > best) best = score;
    if (score > alpha) alpha = score;
    if (alpha >= beta) break;
  }
  return best;
}

function rankedMoves(
  chess: Chess,
  depth = 1,
  quiescePly = 0,
  nodeLimit = 8000,
  rootMoves = 16,
  deadline = Infinity,
  previous?: Array<{ move: EngineMove; score: number }>,
): { scored: Array<{ move: EngineMove; score: number }>; completed: boolean; nodes: number } {
  const root = new Chess(chess.fen());
  let moves = orderMoves(root.moves({ verbose: true }) as EngineMove[]);
  if (previous?.length) {
    // Search the last iteration's best moves first — better alpha-beta cutoffs at the next depth.
    const rank = new Map(previous.map((item, index) => [`${item.move.from}${item.move.to}${item.move.promotion ?? ""}`, index]));
    moves = moves.sort(
      (a, b) =>
        (rank.get(`${a.from}${a.to}${a.promotion ?? ""}`) ?? 999) - (rank.get(`${b.from}${b.to}${b.promotion ?? ""}`) ?? 999),
    );
  }
  moves = moves.slice(0, Math.max(4, rootMoves));
  // Match each pretty root move to its internal move once, so the search below
  // never pays for SAN/FEN generation again.
  const lookup = new Map(searchChess(root)._moves().map((move) => [searchMoveKey(move), move]));
  const side = root.turn() === "w" ? 1 : -1;
  const counter = { nodes: 0, limit: nodeLimit, deadline };
  const game = searchChess(root);
  let alpha = -Infinity;
  let completed = true;
  const scored: Array<{ move: EngineMove; score: number }> = [];
  try {
    for (const move of moves) {
      if (counter.nodes > counter.limit) {
        completed = false;
        break;
      }
      const internal = lookup.get(`${move.from}${move.to}${move.promotion ?? ""}`);
      if (!internal) {
        completed = false;
        break;
      }
      game._makeMove(internal);
      const score = -negamax(
        root,
        Math.max(0, depth - 1),
        -Infinity,
        -alpha,
        -side,
        quiescePly,
        counter,
      );
      game._undoMove();
      scored.push({ move, score });
      if (score > alpha) alpha = score;
    }
  } catch (error) {
    if (!(error instanceof SearchTimeout)) throw error;
    completed = false;
  }
  scored.sort((a, b) => b.score - a.score);
  return { scored, completed, nodes: counter.nodes };
}

function enginePick(chess: Chess, difficulty: Difficulty = "medium") {
  const settings = difficultySettings(difficulty);
  const legal = orderMoves(chess.moves({ verbose: true }) as EngineMove[]);
  // Mate in one: always take it, on every level.
  const mateNow = legal.find((move) => move.san.includes("#"));
  if (mateNow) return mateNow;

  if (chess.history().length < 10) {
    const book = openingBookPick(chess);
    const bookChance = difficulty === "hard" ? 0.92 : difficulty === "medium" ? 0.7 : 0.45;
    if (book && Math.random() < bookChance) return book;
  }

  let ranked: Array<{ move: EngineMove; score: number }> = [];
  try {
    if (difficulty === "hard") {
      // Iterative deepening: always keep the deepest fully completed iteration, so a
      // slow position degrades to a shallower search instead of a timeout.
      const deadline = Date.now() + settings.timeMs;
      let previous: Array<{ move: EngineMove; score: number }> | undefined;
      for (let depth = settings.depth; depth <= settings.maxDepth; depth += 1) {
        if (Date.now() > deadline) break;
        const result = rankedMoves(
          chess,
          depth,
          settings.quiescePly,
          settings.nodeLimit,
          settings.rootMoves,
          deadline,
          previous,
        );
        if (result.completed && result.scored.length) {
          ranked = result.scored;
          previous = result.scored;
          if (result.scored[0].score >= 99900) break;
        } else if (!ranked.length && result.scored.length) {
          ranked = result.scored;
        }
        if (!result.completed) break;
      }
    } else {
      ranked = rankedMoves(
        chess,
        settings.depth,
        settings.quiescePly,
        settings.nodeLimit,
        settings.rootMoves,
      ).scored;
    }
  } catch {
    ranked = rankedMoves(chess, 1, 0, 1200, 10).scored;
  }
  if (!ranked.length) {
    return legal[0] ?? null;
  }

  const best = ranked[0].score;
  if (settings.blunderChance > 0 && ranked.length > 1 && Math.random() < settings.blunderChance) {
    const weaker = ranked.slice(1, Math.min(ranked.length, difficulty === "easy" ? 4 : 2));
    return weaker[Math.floor(Math.random() * weaker.length)]?.move ?? ranked[0].move;
  }

  const noisy = ranked.map((item) => ({
    move: item.move,
    score: item.score + (Math.random() * 2 - 1) * Math.min(settings.noise, settings.noiseCap),
  })).sort((a, b) => b.score - a.score);

  if (difficulty === "easy") {
    const floor = best - 90;
    const pool = noisy.filter((item) => item.score >= floor);
    const pickFrom = pool.length ? pool.slice(0, Math.min(3, pool.length)) : noisy.slice(0, 2);
    return pickFrom[Math.floor(Math.random() * pickFrom.length)].move;
  }

  return noisy[0].move;
}

function precisionLabel(precision: number) {
  if (precision >= 95) return "Excellent";
  if (precision >= 85) return "Great";
  if (precision >= 70) return "Good";
  if (precision >= 55) return "Okay";
  return "Imprecise";
}

function precisionForMove(
  chessBefore: Chess,
  played: { from: string; to: string },
) {
  try {
    // Very light scoring — must never tip the Edge Function over its memory limit.
    const ranked = rankedMoves(chessBefore, 1, 0, 900, 10).scored;
    if (!ranked.length) return 100;
    const best = ranked[0].score;
    const worst = ranked[ranked.length - 1].score;
    const found = ranked.find((item) => item.move.from === played.from && item.move.to === played.to);
    if (!found) return 35;
    if (found.score >= best) return 100;
    const span = Math.max(1, best - worst);
    const ratio = (found.score - worst) / span;
    return Math.max(35, Math.min(99, Math.round(40 + ratio * 59)));
  } catch {
    return 70;
  }
}

function buildMatchReview(
  history: MoveReviewEntry[],
  whiteName: string,
  blackName: string | null,
): MatchReview {
  const summarize = (by: "white" | "black", name: string): PlayerReview => {
    const moves = history.filter((item) => item.by === by);
    const unaided = moves.filter((item) => !item.assisted);
    const avg = (items: MoveReviewEntry[]) =>
      items.length
        ? Math.round(items.reduce((sum, item) => sum + item.precision, 0) / items.length)
        : 0;
    return {
      name,
      accuracy: avg(moves),
      unaidedAccuracy: unaided.length ? avg(unaided) : null,
      moveCount: moves.length,
      assistedCount: moves.filter((item) => item.assisted).length,
      bestPrecision: moves.length ? Math.max(...moves.map((item) => item.precision)) : 0,
      lowestPrecision: moves.length ? Math.min(...moves.map((item) => item.precision)) : 0,
    };
  };
  return {
    white: summarize("white", whiteName),
    black: summarize("black", blackName ?? "Black"),
    moves: history,
  };
}

function attackedSquares(chess: Chess, byColor: "w" | "b") {
  const board = chess.board();
  const threatened: string[] = [];
  for (let rank = 0; rank < 8; rank += 1) {
    for (let file = 0; file < 8; file += 1) {
      const piece = board[rank][file];
      if (!piece || piece.color === byColor) continue;
      const square = `${"abcdefgh"[file]}${8 - rank}`;
      try {
        if (typeof (chess as { isAttacked?: (square: string, color: string) => boolean }).isAttacked === "function") {
          if ((chess as { isAttacked: (square: string, color: string) => boolean }).isAttacked(square, byColor)) {
            threatened.push(square);
          }
        }
      } catch {
        // older chess.js builds may not expose isAttacked
      }
    }
  }
  return threatened;
}

function capturedTray(fen: string) {
  const expected: Record<string, number> = {
    P: 8, N: 2, B: 2, R: 2, Q: 1, K: 1,
    p: 8, n: 2, b: 2, r: 2, q: 1, k: 1,
  };
  const present: Record<string, number> = {};
  for (const ch of (fen.split(" ")[0] ?? "").replace(/[0-9\/]/g, "")) {
    present[ch] = (present[ch] ?? 0) + 1;
  }
  const whiteTaken: string[] = [];
  const blackTaken: string[] = [];
  for (const [piece, count] of Object.entries(expected)) {
    const missing = count - (present[piece] ?? 0);
    for (let i = 0; i < missing; i += 1) {
      if (piece === piece.toUpperCase()) blackTaken.push(piece);
      else whiteTaken.push(piece);
    }
  }
  return { whiteTaken, blackTaken };
}

function historyPush(game: Game, text: string, source: string) {
  const previous = Array.isArray(game.coach_history) ? game.coach_history : [];
  return [...previous, { text, source, at: new Date().toISOString() }].slice(-12);
}

function lessonForMove(
  moveCount: number,
  moverName: string,
  san: string,
  from: string,
  to: string,
  lang: AppLang = "en",
) {
  const F = from.toUpperCase();
  const T = to.toUpperCase();
  const lessons: Record<AppLang, string[]> = {
    en: [
      `${moverName} moved ${F} to ${T} (${san}). Pawns move forward one square, and capture one square diagonally.`,
      `${moverName} played ${F} → ${T}. Knights move in an L shape and can jump over pieces.`,
      `${moverName} played ${san} (${F} → ${T}). Try to control the center squares e4, d4, e5, and d5.`,
      `${moverName} played ${F} → ${T}. Bishops stay on the same square color and slide diagonally.`,
      `${moverName} played ${san}. Rooks like open lines — they slide any number of squares vertically or horizontally.`,
      `${moverName} played ${F} → ${T}. Keep your king safer by developing pieces before launching attacks.`,
    ],
    pt: [
      `${moverName} moveu ${F} para ${T} (${san}). Peões andam uma casa para frente e capturam uma casa na diagonal.`,
      `${moverName} jogou ${F} → ${T}. Cavalos andam em L e podem pular peças.`,
      `${moverName} jogou ${san} (${F} → ${T}). Tente controlar o centro: e4, d4, e5 e d5.`,
      `${moverName} jogou ${F} → ${T}. Bispos ficam na mesma cor de casa e deslizam na diagonal.`,
      `${moverName} jogou ${san}. Torres gostam de linhas abertas — deslizam na vertical ou horizontal.`,
      `${moverName} jogou ${F} → ${T}. Deixe o rei mais seguro desenvolvendo peças antes de atacar.`,
    ],
    es: [
      `${moverName} movió ${F} a ${T} (${san}). Los peones avanzan una casilla y capturan en diagonal.`,
      `${moverName} jugó ${F} → ${T}. Los caballos se mueven en L y pueden saltar piezas.`,
      `${moverName} jugó ${san} (${F} → ${T}). Intenta controlar el centro: e4, d4, e5 y d5.`,
      `${moverName} jugó ${F} → ${T}. Los alfiles se quedan en el mismo color y se deslizan en diagonal.`,
      `${moverName} jugó ${san}. Las torres gustan de líneas abiertas — se deslizan en vertical u horizontal.`,
      `${moverName} jugó ${F} → ${T}. Mantén el rey más seguro desarrollando piezas antes de atacar.`,
    ],
  };
  const list = lessons[lang] ?? lessons.en;
  return list[Math.min(moveCount, list.length - 1)];
}

function displayCoachForLanguage(game: Game, lang: AppLang) {
  const copy = uiCopy[lang];
  if (game.status === "waiting" || !game.black_name) {
    return { text: copy.createCoach, source: "quick" };
  }
  const last = game.last_move;
  if (!last || !last.from || !last.to) {
    return {
      text: copy.joinCoach(game.white_name, game.black_name),
      source: "quick",
    };
  }
  const mover = last.by === "black" ? (game.black_name ?? "Black") : game.white_name;
  const next = last.by === "black" ? game.white_name : (game.black_name ?? "Black");
  const from = String(last.from).toUpperCase();
  const to = String(last.to).toUpperCase();
  const san = String(last.san ?? "");
  const moveCount = game.move_count ?? 0;
  if (moveCount > 0 && moveCount <= 6) {
    return {
      text: lessonForMove(moveCount - 1, mover, san, String(last.from), String(last.to), lang),
      source: "lesson",
    };
  }
  return {
    text: copy.tipMove(mover, from, to, san || `${from}-${to}`, next),
    source: "quick",
  };
}

function displayCoachHistory(game: Game, lang: AppLang) {
  const moves = Array.isArray(game.move_history) ? game.move_history : [];
  const stamp = `v${game.version}`;
  if (!moves.length) {
    const latest = displayCoachForLanguage(game, lang);
    return latest.text ? [{ text: latest.text, source: latest.source, at: stamp }] : [];
  }
  const copy = uiCopy[lang];
  return moves.slice(-16).map((entry, offset, list) => {
    const absoluteIndex = moves.length - list.length + offset;
    const mover = entry.by === "black" ? (game.black_name ?? "Black") : game.white_name;
    const next = entry.by === "black" ? game.white_name : (game.black_name ?? "Black");
    const from = String(entry.from ?? "").toUpperCase();
    const to = String(entry.to ?? "").toUpperCase();
    const san = String(entry.san ?? "");
    const text = absoluteIndex < 6
      ? lessonForMove(absoluteIndex, mover, san, String(entry.from ?? ""), String(entry.to ?? ""), lang)
      : copy.tipMove(mover, from, to, san || `${from}-${to}`, next);
    return { text, source: absoluteIndex < 6 ? "lesson" : "quick", at: `${stamp}-${absoluteIndex}` };
  });
}

function displayQuizForLanguage(game: Game, lang: AppLang) {
  const quiz = game.quiz as null | {
    question?: string;
    options?: Array<{ square: string; label: string }>;
    answerSquare?: string;
  };
  if (!quiz || !quiz.answerSquare || !Array.isArray(quiz.options)) return null;
  const side = (game.fen.split(" ")[1] === "b")
    ? (game.black_name ?? "Black")
    : game.white_name;
  const questions: Record<AppLang, string> = {
    en: `Quick quiz for ${side}: which square can capture something right now?`,
    pt: `Quiz rápido para ${side}: qual casa pode capturar algo agora?`,
    es: `Quiz rápido para ${side}: ¿qué casilla puede capturar algo ahora?`,
  };
  return {
    ...quiz,
    question: questions[lang] ?? questions.en,
  };
}



async function archiveMatch(game: Game) {
  if (!["white_won", "black_won", "draw"].includes(game.status)) return;
  const history = Array.isArray(game.move_history) ? game.move_history : [];
  const review = game.review ?? buildMatchReview(history, game.white_name, game.black_name);
  try {
    await database("match_archives", {
      method: "POST",
      headers: { "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({
        game_id: game.id,
        room_code: game.room_code,
        white_name: game.white_name,
        black_name: game.black_name,
        white_token_hash: game.white_token_hash,
        black_token_hash: game.black_token_hash,
        status: game.status,
        move_count: game.move_count ?? 0,
        move_history: history,
        review,
        ended_at: new Date().toISOString(),
      }),
    });
  } catch (error) {
    console.error("archiveMatch failed", error);
  }
}

function fenFromHistory(entries: MoveReviewEntry[]) {
  const chess = new Chess();
  for (const entry of entries) {
    try {
      chess.move({
        from: String(entry.from),
        to: String(entry.to),
        promotion: "q",
      });
    } catch {
      // ignore illegal rebuild steps
    }
  }
  return chess.fen();
}

function endGameCopy(lang: AppLang) {
  return {
    en: {
      resign: (name: string, w: string, wa: number, b: string, ba: number) =>
        `${name} resigned. Match review: ${w} ${wa}% accuracy, ${b} ${ba}% accuracy.`,
      drawOffer: (name: string) => `${name} offered a draw. Accept or decline.`,
      drawAccepted: (w: string, wa: number, b: string, ba: number) =>
        `Draw agreed. Match review: ${w} ${wa}% accuracy, ${b} ${ba}% accuracy.`,
      drawDeclined: (name: string) => `${name} declined the draw. Keep playing.`,
      undoOffer: (name: string) => `${name} wants to undo the last move. Accept or decline.`,
      undoAccepted: (name: string) => `Last move undone (agreed with ${name}).`,
      undoDeclined: (name: string) => `${name} declined the undo. Keep playing.`,
      youOfferedDraw: "You offered a draw. Waiting for your partner...",
      youOfferedUndo: "You asked to undo. Waiting for your partner...",
    },
    pt: {
      resign: (name: string, w: string, wa: number, b: string, ba: number) =>
        `${name} desistiu. Revisão: ${w} ${wa}% de precisão, ${b} ${ba}% de precisão.`,
      drawOffer: (name: string) => `${name} ofereceu empate. Aceite ou recuse.`,
      drawAccepted: (w: string, wa: number, b: string, ba: number) =>
        `Empate combinado. Revisão: ${w} ${wa}% de precisão, ${b} ${ba}% de precisão.`,
      drawDeclined: (name: string) => `${name} recusou o empate. Continuem jogando.`,
      undoOffer: (name: string) => `${name} quer desfazer a última jogada. Aceite ou recuse.`,
      undoAccepted: (name: string) => `Última jogada desfeita (combinado com ${name}).`,
      undoDeclined: (name: string) => `${name} recusou o desfazer. Continuem jogando.`,
      youOfferedDraw: "Você ofereceu empate. Esperando o parceiro...",
      youOfferedUndo: "Você pediu desfazer. Esperando o parceiro...",
    },
    es: {
      resign: (name: string, w: string, wa: number, b: string, ba: number) =>
        `${name} se rindió. Resumen: ${w} ${wa}% de precisión, ${b} ${ba}% de precisión.`,
      drawOffer: (name: string) => `${name} ofreció tablas. Acepta o rechaza.`,
      drawAccepted: (w: string, wa: number, b: string, ba: number) =>
        `Tablas acordadas. Resumen: ${w} ${wa}% de precisión, ${b} ${ba}% de precisión.`,
      drawDeclined: (name: string) => `${name} rechazó las tablas. Sigan jugando.`,
      undoOffer: (name: string) => `${name} quiere deshacer la última jugada. Acepta o rechaza.`,
      undoAccepted: (name: string) => `Última jugada deshecha (acordado con ${name}).`,
      undoDeclined: (name: string) => `${name} rechazó deshacer. Sigan jugando.`,
      youOfferedDraw: "Ofreciste tablas. Esperando a tu pareja...",
      youOfferedUndo: "Pediste deshacer. Esperando a tu pareja...",
    },
  }[lang];
}

function safeEnginePick(chess: Chess, difficulty: Difficulty) {
  try {
    const pick = enginePick(chess, difficulty);
    if (pick) return pick;
  } catch {
    // fall through
  }
  try {
    const pick = enginePick(chess, "easy");
    if (pick) return pick;
  } catch {
    // fall through
  }
  const legal = chess.moves({ verbose: true }) as EngineMove[];
  if (!legal.length) return null;
  // Prefer captures / checks when completely falling back.
  const ordered = orderMoves(legal);
  return ordered[0] ?? legal[0];
}

function maybeQuiz(
  chess: Chess,
  names: { white: string; black: string | null },
  lang: AppLang = "en",
) {
  const moves = chess.moves({ verbose: true }).filter((move) => move.captured);
  if (moves.length < 1 || Math.random() > 0.35) return null;
  const target = moves[Math.floor(Math.random() * moves.length)];
  const side = chess.turn() === "w" ? names.white : names.black ?? "Black";
  const distractors = chess
    .moves({ verbose: true })
    .filter((move) => move.to !== target.to)
    .slice(0, 3)
    .map((move) => ({ square: move.to, label: move.to.toUpperCase() }));
  const options = [
    { square: target.to, label: target.to.toUpperCase() },
    ...distractors,
  ]
    .sort(() => Math.random() - 0.5)
    .slice(0, 3);
  const questions: Record<AppLang, string> = {
    en: `Quick quiz for ${side}: which square can capture something right now?`,
    pt: `Quiz rápido para ${side}: qual casa pode capturar algo agora?`,
    es: `Quiz rápido para ${side}: ¿qué casilla puede capturar algo ahora?`,
  };
  return {
    question: questions[lang] ?? questions.en,
    options,
    answerSquare: target.to,
  };
}

function publicGame(game: Game, color: string, lang: AppLang = "en") {
  const chess = new Chess(game.fen);
  const turn = chess.turn() === "w" ? "white" : "black";
  const opponentColor = turn === "white" ? "b" : "w";
  const captures = capturedTray(game.fen);
  const copy = uiCopy[lang];
  const displayCoach = displayCoachForLanguage(game, lang);
  return {
    roomCode: game.room_code,
    fen: game.fen,
    turn,
    legalMoves: game.status === "active" && color !== "spectator" ? legalMoves(chess) : [],
    playerColor: color,
    names: { white: game.white_name, black: game.black_name },
    status: game.status,
    coachText: displayCoach.text,
    coachSource: displayCoach.source,
    coachHistory: displayCoachHistory(game, lang),
    version: game.version,
    moveCount: game.move_count ?? 0,
    gameOver: !["waiting", "active"].includes(game.status),
    isCheck: chess.inCheck(),
    result: resultText(game.status, lang),
    lastMove: game.last_move,
    // Hints are private per player — never broadcast suggested moves through shared state.
    suggestedHint: null,
    quiz: displayQuizForLanguage(game, lang),
    threatenedSquares: game.status === "active" ? attackedSquares(chess, opponentColor) : [],
    captured: captures,
    apiVersion: APP_API_VERSION,
    goalText: copy.goal,
    moveHistory: Array.isArray(game.move_history) ? game.move_history : [],
    review: game.review ?? null,
    language: lang,
    drawOfferBy: game.draw_offer_by ?? null,
    undoOfferBy: game.undo_offer_by ?? null,
    ...nudgePublicFields(game, color),
  };
}

function name(value: unknown) {
  const result = String(value ?? "").trim();
  if (!result || result.length > 40) throw new HttpError("Name must be 1 to 40 characters");
  return result;
}

async function askAI(messages: Array<{ role: string; content: string }>) {
  const providers = [
    {
      name: "OpenRouter",
      url: "https://openrouter.ai/api/v1/chat/completions",
      key: openRouterKey,
      model: Deno.env.get("OPENROUTER_MODEL") ?? "openai/gpt-5.6-luna",
    },
    {
      name: "OpenAI",
      url: "https://api.openai.com/v1/chat/completions",
      key: openAIKey,
      model: Deno.env.get("OPENAI_MODEL") ?? "gpt-5.4-mini",
    },
  ];
  for (const provider of providers) {
    if (!provider.key) continue;
    try {
      const response = await fetch(provider.url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${provider.key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: provider.model,
          temperature: 0.3,
          max_tokens: 160,
          messages,
        }),
        signal: AbortSignal.timeout(10000),
      });
      if (!response.ok) {
        console.error(`${provider.name} request failed`, response.status, await response.text());
        continue;
      }
      const data = await response.json();
      const text = String(data.choices?.[0]?.message?.content ?? "").trim();
      if (text) return text;
    } catch (error) {
      console.error(`${provider.name} request failed`, error);
    }
  }
  return null;
}

async function coaching(options: {
  kind: "move" | "hint";
  chess: Chess;
  color: string;
  whiteName: string;
  blackName: string | null;
  move?: { san: string; from: string; to: string; captured?: string | null };
  suggestion?: { san: string; from: string; to: string } | null;
  moveCount: number;
  language?: AppLang;
}) {
  const { kind, chess, color, whiteName, blackName, move, suggestion, moveCount } = options;
  const lang = options.language ?? "en";
  const copy = uiCopy[lang];
  const available = legalMoves(chess);
  const mover = color === "white" ? whiteName : blackName ?? "Black";
  const next = color === "white" ? blackName ?? "Black" : whiteName;
  const fallback = kind === "hint"
    ? suggestion
      ? copy.tipHint(suggestion.from.toUpperCase(), suggestion.to.toUpperCase(), suggestion.san)
      : copy.tipHintNone
    : move
      ? copy.tipMove(mover, move.from.toUpperCase(), move.to.toUpperCase(), move.san, next)
      : copy.tipGeneric;

  if (kind === "move" && moveCount <= 6 && move) {
    return { text: lessonForMove(moveCount - 1, mover, move.san, move.from, move.to, lang), source: "lesson" as const };
  }

  if (!openRouterKey && !openAIKey) return { text: fallback, source: "quick" as const };

  const task = kind === "hint"
    ? `Give a hint to ${mover}. Suggest exactly this legal move if helpful: ${suggestion?.from?.toUpperCase()} to ${suggestion?.to?.toUpperCase()} (${suggestion?.san}).`
    : `Explain what ${mover} just did with ${move?.from?.toUpperCase()} to ${move?.to?.toUpperCase()} (${move?.san}${move?.captured ? `, capturing` : ""}). Then tell ${next} what to notice.`;

  const text = await askAI([
    {
      role: "system",
      content:
        `You are a warm chess teacher for two complete beginners named in the prompt. Reply in ${languageName(lang)} only. Never use jargon unless you immediately explain it in parentheses. At most 3 short sentences. Always mention squares like E2 → E4. Never invent an illegal move. Format: 1) what happened 2) what to watch for 3) optional next idea with squares.`,
    },
    {
      role: "user",
      content: `${task}\nWhite: ${whiteName}\nBlack: ${blackName ?? "waiting"}\nSide to move context color: ${color}\nFEN: ${chess.fen()}\nLegal moves: ${available.map((item) => `${item.san} (${item.from}->${item.to})`).join(", ")}`,
    },
  ]);

  if (!text) return { text: fallback, source: "quick" as const };
  return { text, source: "ai" as const };
}

async function create(body: Record<string, unknown>) {
  const token = playerToken();
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      const lang = normalizeLanguage(body.language);
      const coachText = uiCopy[lang].createCoach;
      const game = await insertGame({
        room_code: roomCode(),
        white_name: name(body.name),
        white_token_hash: await hashToken(token),
        fen: new Chess().fen(),
        status: "waiting",
        coach_text: coachText,
        coach_source: "quick",
        coach_history: [{ text: coachText, source: "quick", at: new Date().toISOString() }],
        move_count: 0,
        move_history: [],
        review: null,
      });
      return { ...publicGame(game, "white", lang), playerToken: token };
    } catch (error) {
      if (!(error instanceof HttpError) || error.status !== 409 || attempt === 4) throw error;
    }
  }
}

async function join(body: Record<string, unknown>) {
  const game = await getGame(String(body.roomCode ?? ""));
  if (!game) throw new HttpError("Room not found", 404);
  if (game.status !== "waiting" || game.black_token_hash) throw new HttpError("Room is not available", 409);
  const token = playerToken();
  const lang = normalizeLanguage(body.language);
  const joiner = name(body.name);
  const joinerHash = await hashToken(token);
  // Randomize colors so the room creator is not always White.
  const joinerIsWhite = Math.random() < 0.5;
  // IMPORTANT: keep token hashes aligned with the correct seats.
  const whiteHash = joinerIsWhite ? joinerHash : game.white_token_hash;
  const blackHash = joinerIsWhite ? game.white_token_hash : joinerHash;
  const whiteName = joinerIsWhite ? joiner : game.white_name;
  const blackName = joinerIsWhite ? game.white_name : joiner;
  const coachText = uiCopy[lang].joinCoach(whiteName, blackName);
  const updated = await updateGame(game, {
    white_name: whiteName,
    black_name: blackName,
    white_token_hash: whiteHash,
    black_token_hash: blackHash,
    status: "active",
    coach_text: coachText,
    coach_source: "quick",
    coach_history: historyPush(game, coachText, "quick"),
    quiz: null,
    suggested_hint: null,
  });
  const creatorColor = joinerIsWhite ? "black" : "white";
  schedulePush(pushToColor(updated, creatorColor, "joined", uiCopy[lang].pushJoined(blackName, game.room_code)));
  return {
    ...publicGame(updated, joinerIsWhite ? "white" : "black", lang),
    playerToken: token,
  };
}

async function spectate(body: Record<string, unknown>) {
  const game = await getGame(String(body.roomCode ?? ""));
  if (!game) throw new HttpError("Room not found", 404);
  return publicGame(game, "spectator", normalizeLanguage(body.language));
}

async function authenticated(body: Record<string, unknown>) {
  const game = await getGame(String(body.roomCode ?? ""));
  if (!game) throw new HttpError("Room not found", 404);
  return { game, color: await colorFor(game, String(body.playerToken ?? "")) };
}

async function updateCoachOnly(gameId: string, changes: Record<string, unknown>) {
  const query = new URLSearchParams({ id: `eq.${gameId}`, select: "id" });
  try {
    await database(`games?${query}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify(changes),
    });
  } catch (error) {
    console.error("updateCoachOnly failed", error);
  }
}

async function runMoveCoachInBackground(game: Game, lang: AppLang) {
  try {
    const chess = new Chess(game.fen);
    const last = game.last_move ?? {};
    const coach = await coaching({
      kind: "move",
      chess,
      color: String(last.by ?? "white"),
      whiteName: game.white_name,
      blackName: game.black_name,
      move: {
        san: String(last.san ?? ""),
        from: String(last.from ?? ""),
        to: String(last.to ?? ""),
        captured: last.captured ? String(last.captured) : null,
      },
      moveCount: game.move_count ?? 0,
      language: lang,
    });
    await updateCoachOnly(game.id, {
      coach_text: coach.text,
      coach_source: coach.source,
      coach_history: historyPush(game, coach.text, coach.source),
    });
  } catch (error) {
    console.error("runMoveCoachInBackground failed", error);
  }
}

async function applyPlayedMove(
  game: Game,
  color: string,
  request: { from: string; to: string; promotion?: string },
  options: { computerAssisted?: boolean; difficulty?: Difficulty; language?: AppLang } = {},
) {
  const lang = options.language ?? "en";

  const chessBefore = new Chess(game.fen);
  const turn = chessBefore.turn() === "w" ? "white" : "black";
  if (turn !== color) throw new HttpError("It is not your turn");

  const from = String(request.from ?? "").toLowerCase();
  const to = String(request.to ?? "").toLowerCase();
  // Skip a second engine pass after playForMe — that double search was OOMing Hard.
  const precision = options.computerAssisted
    ? 88
    : precisionForMove(chessBefore, { from, to });
  const label = precisionLabel(precision);

  const chess = new Chess(game.fen);
  let played;
  try {
    played = chess.move({
      from,
      to,
      promotion: String(request.promotion ?? "q").toLowerCase(),
    });
  } catch {
    throw new HttpError("That move is not allowed. Pieces can only go to the highlighted squares.");
  }
  if (!played) throw new HttpError("That move is not allowed. Pieces can only go to the highlighted squares.");

  const status = chess.isCheckmate()
    ? color === "white" ? "white_won" : "black_won"
    : chess.isDraw()
    ? "draw"
    : "active";
  const moveCount = (game.move_count ?? 0) + 1;
  const playerName = color === "white" ? game.white_name : game.black_name;
  const history = Array.isArray(game.move_history) ? [...game.move_history] : [];
  history.push({
    from: played.from,
    to: played.to,
    san: played.san,
    by: color,
    assisted: Boolean(options.computerAssisted),
    precision,
    label,
  });
  const review = !["waiting", "active"].includes(status)
    ? buildMatchReview(history, game.white_name, game.black_name)
    : null;

  let coach: { text: string; source: string };
  if (options.computerAssisted) {
    const copy = uiCopy[lang];
    const next = color === "white" ? game.black_name ?? "Black" : game.white_name;
    coach = {
      text: copy.tipMove(
        playerName ?? "Player",
        played.from.toUpperCase(),
        played.to.toUpperCase(),
        played.san,
        next,
      ),
      source: "quick",
    };
  } else {
    // Keep the AI coach out of the request path — persist the move now, refine the coach later.
    coach = {
      text: uiCopy[lang].tipMove(
        playerName ?? "Player",
        played.from.toUpperCase(),
        played.to.toUpperCase(),
        played.san,
        color === "white" ? game.black_name ?? "Black" : game.white_name,
      ),
      source: "quick",
    };
  }

  const labels: Record<AppLang, {
    computer: (level: string, name: string, from: string, to: string, san: string) => string;
    capture: (name: string, square: string) => string;
    mate: (name: string) => string;
    check: string;
    review: (w: string, wa: number, b: string, ba: number) => string;
  }> = {
    en: {
      computer: (level, name, from, to, san) => `Computer${level} played for ${name}: ${from} → ${to} (${san}). `,
      capture: (name, square) => `Capture! ${name} took a piece on ${square}. `,
      mate: (name) => `Checkmate! ${name} wins. `,
      check: "Check! The king is under attack. ",
      review: (w, wa, b, ba) => ` Match review: ${w} ${wa}% accuracy, ${b} ${ba}% accuracy.`,
    },
    pt: {
      computer: (level, name, from, to, san) => `Computador${level} jogou por ${name}: ${from} → ${to} (${san}). `,
      capture: (name, square) => `Captura! ${name} tomou uma peça em ${square}. `,
      mate: (name) => `Xeque-mate! ${name} venceu. `,
      check: "Xeque! O rei está sob ataque. ",
      review: (w, wa, b, ba) => ` Revisão: ${w} ${wa}% de precisão, ${b} ${ba}% de precisão.`,
    },
    es: {
      computer: (level, name, from, to, san) => `Computadora${level} jugó por ${name}: ${from} → ${to} (${san}). `,
      capture: (name, square) => `¡Captura! ${name} tomó una pieza en ${square}. `,
      mate: (name) => `¡Jaque mate! ${name} gana. `,
      check: "¡Jaque! El rey está bajo ataque. ",
      review: (w, wa, b, ba) => ` Resumen: ${w} ${wa}% de precisión, ${b} ${ba}% de precisión.`,
    },
  };
  const L = labels[lang] ?? labels.en;
  let text = coach.text;
  if (options.computerAssisted) {
    const level = options.difficulty ? ` (${options.difficulty})` : "";
    text = L.computer(level, playerName, played.from.toUpperCase(), played.to.toUpperCase(), played.san) + text;
  }
  if (played.captured) {
    text = L.capture(playerName, played.to.toUpperCase()) + text;
  }
  if (chess.isCheckmate()) {
    text = L.mate(playerName) + text;
  } else if (chess.inCheck()) {
    text = L.check + text;
  }
  if (review) {
    text = `${text}${L.review(game.white_name, review.white.accuracy, game.black_name ?? "Black", review.black.accuracy)}`;
  }

  const quiz = status === "active"
    ? maybeQuiz(chess, { white: game.white_name, black: game.black_name }, lang)
    : null;
  const updated = await updateGame(game, {
    fen: chess.fen(),
    status,
    coach_text: text,
    coach_source: coach.source,
    coach_history: historyPush(game, text, coach.source),
    last_move: {
      from: played.from,
      to: played.to,
      san: played.san,
      captured: played.captured ?? "",
      by: color,
      assisted: options.computerAssisted ? "1" : "",
      precision: String(precision),
      label,
    },
    suggested_hint: null,
    quiz,
    move_count: moveCount,
    move_history: history,
    review,
    draw_offer_by: null,
    undo_offer_by: null,
  });
  if (review) await archiveMatch(updated);
  if (!options.computerAssisted && (openRouterKey || openAIKey)) {
    const coachGame: Game = { ...updated, coach_text: "", coach_source: "quick" };
    try {
      const waitUntil = (globalThis as { EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void } }).EdgeRuntime?.waitUntil;
      if (waitUntil) {
        waitUntil(runMoveCoachInBackground(coachGame, lang));
      } else {
        runMoveCoachInBackground(coachGame, lang);
      }
    } catch (error) {
      console.error("coach scheduling failed", error);
    }
  }
  const opponentColor: "white" | "black" = color === "white" ? "black" : "white";
  const opponentName = color === "white" ? game.black_name ?? "Black" : game.white_name;
  if (status === "active") {
    schedulePush(pushToOpponent(
      updated,
      color,
      "turn",
      uiCopy[lang].pushYourTurn(opponentName, String(played.san ?? ""), updated.room_code),
      { title: uiCopy[lang].pushYourMoveTitle, requiresTurnAlerts: true },
    ));
  } else {
    const result = resultText(status, lang) ?? "Game over";
    schedulePush(pushToOpponent(updated, color, "gameover", uiCopy[lang].pushGameOver(result, updated.room_code)));
  }
  return publicGame(updated, color, lang);
}

async function move(body: Record<string, unknown>) {
  const { game, color } = await authenticated(body);
  if (game.status !== "active") throw new HttpError("Game is not active");
  if (Number(body.version) !== game.version) throw new HttpError("Game changed; refresh and try again", 409);
  const requested = (body.move ?? {}) as Record<string, unknown>;
  const assisted = body.assisted === true || body.computerAssisted === true;
  return applyPlayedMove(game, color, {
    from: String(requested.from ?? ""),
    to: String(requested.to ?? ""),
    promotion: String(requested.promotion ?? "q"),
  }, {
    language: normalizeLanguage(body.language),
    computerAssisted: assisted,
    difficulty: assisted ? normalizeDifficulty(body.difficulty) : undefined,
  });
}

async function playForMe(body: Record<string, unknown>) {
  const lang = normalizeLanguage(body.language);
  const difficulty = normalizeDifficulty(body.difficulty);
  let lastError: unknown = null;

  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      const { game, color } = await authenticated(body);
      if (game.status !== "active") throw new HttpError("Game is not active");
      const chess = new Chess(game.fen);
      const turn = chess.turn() === "w" ? "white" : "black";
      if (turn !== color) throw new HttpError("The computer can only move on your turn");
      const pick = safeEnginePick(chess, difficulty);
      if (!pick) throw new HttpError("There are no legal moves right now");
      return await applyPlayedMove(
        game,
        color,
        {
          from: pick.from,
          to: pick.to,
          promotion: pick.promotion ?? "q",
        },
        { computerAssisted: true, difficulty, language: lang },
      );
    } catch (error) {
      lastError = error;
      const status = error instanceof HttpError ? error.status : 500;
      // Retry version races / transient resource failures.
      if (status === 409 || status >= 500) {
        await new Promise((resolve) => setTimeout(resolve, 140 * (attempt + 1)));
        continue;
      }
      throw error;
    }
  }
  if (lastError instanceof HttpError) throw lastError;
  throw new HttpError("Couldn't play that turn; try again", 500);
}

async function hint(body: Record<string, unknown>) {
  const { game, color } = await authenticated(body);
  if (game.status !== "active") throw new HttpError("Game is not active");
  if (Number(body.version) !== game.version) throw new HttpError("Game changed; refresh and try again", 409);
  const chess = new Chess(game.fen);
  const turn = chess.turn() === "w" ? "white" : "black";
  if (turn !== color) throw new HttpError("Hints are available on your turn");

  // Medium is enough for a tip and stays inside Edge Function limits.
  const pick = enginePick(chess, "medium");
  const suggestion = pick
    ? { from: pick.from, to: pick.to, san: pick.san, promotion: pick.promotion ?? "" }
    : null;
  const lang = normalizeLanguage(body.language);
  const coach = await coaching({
    kind: "hint",
    chess,
    color,
    whiteName: game.white_name,
    blackName: game.black_name,
    suggestion,
    moveCount: game.move_count ?? 0,
    language: lang,
  });
  // Private to the requester only — do not write hint text or squares into shared game state.
  return {
    ...publicGame(game, color, lang),
    coachText: coach.text,
    coachSource: coach.source,
    hint: coach.text,
    suggestedHint: suggestion,
    privateHint: true,
  };
}

async function resign(body: Record<string, unknown>) {
  const { game, color } = await authenticated(body);
  if (game.status !== "active") throw new HttpError("Game is not active");
  if (Number(body.version) !== game.version) throw new HttpError("Game changed; refresh and try again", 409);
  const lang = normalizeLanguage(body.language);
  const winner = color === "white" ? "black" : "white";
  const history = Array.isArray(game.move_history) ? game.move_history : [];
  const review = buildMatchReview(history, game.white_name, game.black_name);
  const name = color === "white" ? game.white_name : game.black_name ?? "Black";
  const coachText = endGameCopy(lang).resign(
    name,
    game.white_name,
    review.white.accuracy,
    game.black_name ?? "Black",
    review.black.accuracy,
  );
  const updated = await updateGame(game, {
    status: `${winner}_won`,
    coach_text: coachText,
    coach_source: "quick",
    coach_history: historyPush(game, coachText, "quick"),
    suggested_hint: null,
    quiz: null,
    review,
    move_history: history,
    draw_offer_by: null,
    undo_offer_by: null,
  });
  await archiveMatch(updated);
  return publicGame(updated, color, lang);
}

async function offerDraw(body: Record<string, unknown>) {
  const { game, color } = await authenticated(body);
  if (game.status !== "active") throw new HttpError("Game is not active");
  if (Number(body.version) !== game.version) throw new HttpError("Game changed; refresh and try again", 409);
  const lang = normalizeLanguage(body.language);
  if (game.draw_offer_by === color) return publicGame(game, color, lang);
  if (game.draw_offer_by && game.draw_offer_by !== color) {
    // Partner already offered — treat as accept.
    return respondDraw({ ...body, accept: true });
  }
  const name = color === "white" ? game.white_name : game.black_name ?? "Black";
  const coachText = endGameCopy(lang).drawOffer(name);
  const updated = await updateGame(game, {
    draw_offer_by: color,
    coach_text: coachText,
    coach_source: "quick",
    coach_history: historyPush(game, coachText, "quick"),
  });
  schedulePush(pushToOpponent(updated, color, "drawoffer", uiCopy[lang].pushDrawOffer(name, updated.room_code)));
  return publicGame(updated, color, lang);
}

async function respondDraw(body: Record<string, unknown>) {
  const { game, color } = await authenticated(body);
  if (game.status !== "active") throw new HttpError("Game is not active");
  if (Number(body.version) !== game.version) throw new HttpError("Game changed; refresh and try again", 409);
  const lang = normalizeLanguage(body.language);
  const offer = game.draw_offer_by;
  if (!offer || offer === color) throw new HttpError("There is no draw offer to answer");
  const accept = body.accept === true || String(body.accept ?? "").toLowerCase() === "true";
  const copy = endGameCopy(lang);
  const offererName = offer === "white" ? game.white_name : game.black_name ?? "Black";
  if (!accept) {
    const name = color === "white" ? game.white_name : game.black_name ?? "Black";
    const coachText = copy.drawDeclined(name);
    const updated = await updateGame(game, {
      draw_offer_by: null,
      coach_text: coachText,
      coach_source: "quick",
      coach_history: historyPush(game, coachText, "quick"),
    });
    schedulePush(pushToColor(updated, offer, "drawanswer", uiCopy[lang].pushDrawAnswer(offererName, updated.room_code)));
    return publicGame(updated, color, lang);
  }
  const history = Array.isArray(game.move_history) ? game.move_history : [];
  const review = buildMatchReview(history, game.white_name, game.black_name);
  const coachText = copy.drawAccepted(
    game.white_name,
    review.white.accuracy,
    game.black_name ?? "Black",
    review.black.accuracy,
  );
  const updated = await updateGame(game, {
    status: "draw",
    coach_text: coachText,
    coach_source: "quick",
    coach_history: historyPush(game, coachText, "quick"),
    suggested_hint: null,
    quiz: null,
    review,
    move_history: history,
    draw_offer_by: null,
    undo_offer_by: null,
  });
  pushToColor(updated, offer, "drawanswer", uiCopy[lang].pushDrawAnswer(offererName, updated.room_code));
  await archiveMatch(updated);
  return publicGame(updated, color, lang);
}

async function offerUndo(body: Record<string, unknown>) {
  const { game, color } = await authenticated(body);
  if (game.status !== "active") throw new HttpError("Game is not active");
  if (Number(body.version) !== game.version) throw new HttpError("Game changed; refresh and try again", 409);
  const lang = normalizeLanguage(body.language);
  const history = Array.isArray(game.move_history) ? game.move_history : [];
  if (!history.length) throw new HttpError("Nothing to undo yet");
  if (game.undo_offer_by === color) return publicGame(game, color, lang);
  if (game.undo_offer_by && game.undo_offer_by !== color) {
    return respondUndo({ ...body, accept: true });
  }
  const name = color === "white" ? game.white_name : game.black_name ?? "Black";
  const coachText = endGameCopy(lang).undoOffer(name);
  const updated = await updateGame(game, {
    undo_offer_by: color,
    coach_text: coachText,
    coach_source: "quick",
    coach_history: historyPush(game, coachText, "quick"),
  });
  schedulePush(pushToOpponent(updated, color, "undooffer", uiCopy[lang].pushUndoOffer(name, updated.room_code)));
  return publicGame(updated, color, lang);
}

async function respondUndo(body: Record<string, unknown>) {
  const { game, color } = await authenticated(body);
  if (game.status !== "active") throw new HttpError("Game is not active");
  if (Number(body.version) !== game.version) throw new HttpError("Game changed; refresh and try again", 409);
  const lang = normalizeLanguage(body.language);
  const offer = game.undo_offer_by;
  if (!offer || offer === color) throw new HttpError("There is no undo request to answer");
  const accept = body.accept === true || String(body.accept ?? "").toLowerCase() === "true";
  const copy = endGameCopy(lang);
  const name = color === "white" ? game.white_name : game.black_name ?? "Black";
  const offererName = offer === "white" ? game.white_name : game.black_name ?? "Black";
  if (!accept) {
    const coachText = copy.undoDeclined(name);
    const updated = await updateGame(game, {
      undo_offer_by: null,
      coach_text: coachText,
      coach_source: "quick",
      coach_history: historyPush(game, coachText, "quick"),
    });
    schedulePush(pushToColor(updated, offer, "undoanswer", uiCopy[lang].pushUndoAnswer(offererName, updated.room_code)));
    return publicGame(updated, color, lang);
  }
  const history = Array.isArray(game.move_history) ? [...game.move_history] : [];
  if (!history.length) throw new HttpError("Nothing to undo yet");
  history.pop();
  const fen = fenFromHistory(history);
  const chess = new Chess(fen);
  const last = history.length ? history[history.length - 1] : null;
  const coachText = copy.undoAccepted(name);
  const updated = await updateGame(game, {
    fen,
    status: "active",
    move_count: history.length,
    move_history: history,
    last_move: last
      ? {
        from: last.from,
        to: last.to,
        san: last.san,
        by: last.by,
        assisted: last.assisted ? "1" : "",
        precision: String(last.precision ?? ""),
        label: last.label ?? "",
        captured: "",
      }
      : null,
    coach_text: coachText,
    coach_source: "quick",
    coach_history: historyPush(game, coachText, "quick"),
    suggested_hint: null,
    quiz: null,
    review: null,
    undo_offer_by: null,
    draw_offer_by: null,
  });
  schedulePush(pushToColor(updated, offer, "undoanswer", uiCopy[lang].pushUndoAnswer(offererName, updated.room_code)));
  return publicGame(updated, color, lang);
}

async function listArchives(body: Record<string, unknown>) {
  const token = String(body.playerToken ?? body.token ?? "");
  if (!token) throw new HttpError("Missing player token", 401);
  const hash = await hashToken(token);
  const query = new URLSearchParams({
    select: "id,room_code,white_name,black_name,status,move_count,review,ended_at,move_history",
    or: `(white_token_hash.eq.${hash},black_token_hash.eq.${hash})`,
    order: "ended_at.desc",
    limit: "40",
  });
  const rows = await database(`match_archives?${query}`);
  return {
    archives: (rows ?? []).map((row: Record<string, unknown>) => ({
      id: row.id,
      roomCode: row.room_code,
      whiteName: row.white_name,
      blackName: row.black_name,
      status: row.status,
      moveCount: row.move_count,
      review: row.review,
      endedAt: row.ended_at,
      moveHistory: row.move_history,
      result: resultText(String(row.status), normalizeLanguage(body.language)),
    })),
  };
}

async function getArchive(body: Record<string, unknown>) {
  const token = String(body.playerToken ?? body.token ?? "");
  const id = String(body.archiveId ?? body.id ?? "");
  if (!token || !id) throw new HttpError("Missing archive id or token", 400);
  const hash = await hashToken(token);
  const query = new URLSearchParams({
    id: `eq.${id}`,
    or: `(white_token_hash.eq.${hash},black_token_hash.eq.${hash})`,
    select: "*",
    limit: "1",
  });
  const rows = await database(`match_archives?${query}`);
  const row = rows?.[0];
  if (!row) throw new HttpError("Archive not found", 404);
  const lang = normalizeLanguage(body.language);
  return {
    id: row.id,
    roomCode: row.room_code,
    whiteName: row.white_name,
    blackName: row.black_name,
    status: row.status,
    moveCount: row.move_count,
    review: row.review,
    endedAt: row.ended_at,
    moveHistory: row.move_history,
    result: resultText(String(row.status), lang),
  };
}

async function rematch(body: Record<string, unknown>) {
  const { game, color } = await authenticated(body);
  if (!["white_won", "black_won", "draw"].includes(game.status)) {
    throw new HttpError("Rematch is only available after a finished game");
  }
  if (Number(body.version) !== game.version) throw new HttpError("Game changed; refresh and try again", 409);
  if (!game.black_token_hash || !game.black_name) throw new HttpError("Need both players for a rematch");
  const lang = normalizeLanguage(body.language);
  const coachText = uiCopy[lang].rematchCoach;
  if (game.review) await archiveMatch(game);
  const updated = await updateGame(game, {
    fen: new Chess().fen(),
    status: "active",
    coach_text: coachText,
    coach_source: "quick",
    coach_history: historyPush(game, coachText, "quick"),
    last_move: null,
    suggested_hint: null,
    quiz: null,
    move_count: 0,
    move_history: [],
    review: null,
    draw_offer_by: null,
    undo_offer_by: null,
  });
  const opponentColor: "white" | "black" = color === "white" ? "black" : "white";
  const opponentName = color === "white" ? game.black_name ?? "Black" : game.white_name;
  schedulePush(pushToOpponent(updated, color, "rematch", uiCopy[lang].pushRematch(opponentName, updated.room_code)));
  return publicGame(updated, color, lang);
}

async function version() {
  return {
    apiVersion: APP_API_VERSION,
    minClientVersion: "2.0.0",
    models: {
      openRouter: Deno.env.get("OPENROUTER_MODEL") ?? "openai/gpt-5.6-luna",
      openAI: Deno.env.get("OPENAI_MODEL") ?? "gpt-5.4-mini",
    },
  };
}

const NUDGE_COOLDOWN_MS = 90_000;
const NUDGE_MAX_PER_GAME = 8;

type NudgeEvent = { id: string; fromColor: string; fromName: string; createdAt: string };

function nudgePushCopy(lang: AppLang, toName: string, fromName: string) {
  if (lang === "pt") {
    return { title: `${toName}, sua vez`, body: `${fromName} está esperando no Chess Duo` };
  }
  if (lang === "es") {
    return { title: `${toName}, te toca`, body: `${fromName} te espera en Chess Duo` };
  }
  return { title: `${toName}, your move`, body: `${fromName} is waiting in Chess Duo` };
}

function incomingNudge(game: Game, color: string): NudgeEvent | null {
  const event = game.last_nudge;
  if (!event?.id || event.fromColor === color) return null;
  return event;
}

function nudgeCount(game: Game, color: string) {
  return color === "white" ? Number(game.white_nudge_count ?? 0) : Number(game.black_nudge_count ?? 0);
}

function lastNudgeAt(game: Game, color: string) {
  return color === "white" ? game.white_last_nudge_at ?? null : game.black_last_nudge_at ?? null;
}

function cooldownRemainingSeconds(game: Game, color: string) {
  const raw = lastNudgeAt(game, color);
  if (!raw) return 0;
  const elapsed = Date.now() - Date.parse(raw);
  if (!Number.isFinite(elapsed)) return 0;
  return Math.max(0, Math.ceil((NUDGE_COOLDOWN_MS - elapsed) / 1000));
}

function opponentLastSeenSeconds(game: Game, color: string) {
  const raw = color === "white" ? game.black_last_seen : game.white_last_seen;
  if (!raw) return null;
  const elapsed = Date.now() - Date.parse(raw);
  if (!Number.isFinite(elapsed)) return null;
  return Math.max(0, Math.floor(elapsed / 1000));
}

function nudgePublicFields(game: Game, color: string) {
  return {
    nudge: incomingNudge(game, color),
    nudgeCooldownRemaining: cooldownRemainingSeconds(game, color),
    nudgeRemaining: Math.max(0, NUDGE_MAX_PER_GAME - nudgeCount(game, color)),
    opponentLastSeenSeconds: opponentLastSeenSeconds(game, color),
  };
}

async function touchPresence(game: Game, color: string) {
  if (color !== "white" && color !== "black") return;
  const field = color === "white" ? "white_last_seen" : "black_last_seen";
  try {
    const query = new URLSearchParams({ id: `eq.${game.id}` });
    await database(`games?${query}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ [field]: new Date().toISOString() }),
    });
  } catch (error) {
    console.error("touchPresence failed", error);
  }
}

async function tokensForColor(game: Game, color: "white" | "black") {
  const hash = color === "white" ? game.white_token_hash : game.black_token_hash;
  if (!hash) return [];
  const query = new URLSearchParams({
    player_token_hash: `eq.${hash}`,
    select: "apns_token",
  });
  try {
    const rows = await database(`push_tokens?${query}`);
    return (rows ?? []).map((row: { apns_token?: string }) => String(row.apns_token ?? "")).filter(Boolean);
  } catch (error) {
    console.error("tokensForColor failed", error);
    return [];
  }
}

async function sendNudgePush(game: Game, toColor: "white" | "black", title: string, body: string, nudgeId: string) {
  if (!pushConfigured) return;
  const tokens = await tokensForColor(game, toColor);
  for (const deviceToken of tokens) {
    await sendApns(
      deviceToken,
      {
        aps: {
          alert: { title, body },
          badge: 1,
          sound: "default",
          "thread-id": game.room_code,
          category: "NUDGE",
        },
        roomCode: game.room_code,
        kind: "nudge",
        nudgeId,
        url: `chessduo://room/${game.room_code}`,
      },
      `${game.room_code}-nudge`,
    );
  }
}

async function persistNudge(game: Game, color: "white" | "black", event: NudgeEvent, count: number) {
  const at = event.createdAt;
  const changes = color === "white"
    ? { last_nudge: event, white_last_nudge_at: at, white_nudge_count: count }
    : { last_nudge: event, black_last_nudge_at: at, black_nudge_count: count };
  const query = new URLSearchParams({ id: `eq.${game.id}`, select: "*" });
  const rows = await database(`games?${query}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json", Prefer: "return=representation" },
    body: JSON.stringify(changes),
  });
  return (rows?.[0] ?? { ...game, ...changes }) as Game;
}

async function nudge(body: Record<string, unknown>) {
  const { game, color } = await authenticated(body);
  if (color !== "white" && color !== "black") throw new HttpError("Spectators cannot nudge", 403);
  const lang = normalizeLanguage(body.language);
  const waiting = game.status === "waiting";
  const active = game.status === "active";
  if (!waiting && !active) throw new HttpError("Game is not active");
  if (active) {
    const turn = new Chess(game.fen).turn() === "w" ? "white" : "black";
    if (turn === color) throw new HttpError("It's your turn");
  }
  const used = nudgeCount(game, color);
  if (used >= NUDGE_MAX_PER_GAME) {
    throw new HttpError("That's enough nudges for this game", 429);
  }
  const wait = cooldownRemainingSeconds(game, color);
  if (wait > 0) throw new HttpError("Wait a bit before nudging again", 429);

  const fromName = color === "white" ? game.white_name : game.black_name ?? "Black";
  const toColor: "white" | "black" = color === "white" ? "black" : "white";
  const toName = toColor === "white" ? game.white_name : game.black_name ?? "your partner";
  const event: NudgeEvent = {
    id: crypto.randomUUID(),
    fromColor: color,
    fromName,
    createdAt: new Date().toISOString(),
  };
  const updated = await persistNudge(game, color, event, used + 1);
  const tokens = await tokensForColor(updated, toColor);
  let delivered: "apns" | "no_push" = "no_push";
  if (pushConfigured && tokens.length > 0) {
    const copy = nudgePushCopy(lang, toName, fromName);
    await sendNudgePush(updated, toColor, copy.title, copy.body, event.id);
    delivered = "apns";
  }
  return {
    ...publicGame(updated, color, lang),
    delivered,
    nudge: incomingNudge(updated, color),
    ...nudgePublicFields(updated, color),
  };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: jsonHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!supabaseUrl || !serviceKey) return json({ error: "Server configuration is incomplete" }, 500);

  try {
    const body = await request.json();
    const actions: Record<string, (value: Record<string, unknown>) => Promise<unknown>> = {
      create,
      join,
      spectate,
      rematch,
      version,
      registerPush,
      state: async (value) => {
        const { game, color } = await authenticated(value);
        touchPresence(game, color);
        const sinceVersion = Number(value.sinceVersion);
        if (Number.isFinite(sinceVersion) && sinceVersion > 0 && sinceVersion === game.version) {
          return { changed: false, version: game.version, ...nudgePublicFields(game, color) };
        }
        return publicGame(game, color, normalizeLanguage(value.language));
      },
      move,
      playForMe,
      hint,
      resign,
      offerDraw,
      respondDraw,
      offerUndo,
      respondUndo,
      listArchives,
      getArchive,
    };
    actions.nudge = nudge;
    const action = actions[String(body.action ?? "")];
    if (!action) throw new HttpError("Unknown action");
    return json(await action(body));
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    console.error("Game request failed", error);
    const message = error instanceof Error ? error.message : "Server request failed";
    return json({
      error: status >= 500 ? "Couldn't reach the game server. Check your connection and try again." : message,
      message: status >= 500 ? "Couldn't reach the game server. Check your connection and try again." : message,
    }, status);
  }
});
