import { createHash, randomBytes } from "node:crypto";
import { Chess } from "chess.js";

const ROOM_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export function createPlayerToken() {
  return randomBytes(32).toString("base64url");
}

export function hashPlayerToken(token) {
  return createHash("sha256").update(token).digest("hex");
}

export function createRoomCode(length = 6) {
  if (!Number.isInteger(length) || length < 4 || length > 6) {
    throw new RangeError("Room code length must be between 4 and 6");
  }

  const bytes = randomBytes(length);
  return Array.from(bytes, (byte) => ROOM_ALPHABET[byte % ROOM_ALPHABET.length]).join("");
}

export function normalizeRoomCode(value) {
  return String(value ?? "").trim().toUpperCase();
}

export function colorForToken(game, token) {
  const hash = hashPlayerToken(String(token ?? ""));
  if (game.white_token_hash === hash) return "white";
  if (game.black_token_hash === hash) return "black";
  return null;
}

export function legalMovesForFen(fen) {
  const chess = new Chess(fen);
  return chess.moves({ verbose: true }).map(({ from, to, promotion, san }) => ({
    from,
    to,
    ...(promotion ? { promotion } : {}),
    san,
  }));
}

export function applyMove(fen, color, move) {
  const chess = new Chess(fen);
  const expectedColor = chess.turn() === "w" ? "white" : "black";
  if (color !== expectedColor) {
    throw new Error("It is not your turn");
  }

  let result;
  try {
    result = chess.move({
      from: String(move?.from ?? "").toLowerCase(),
      to: String(move?.to ?? "").toLowerCase(),
      promotion: String(move?.promotion ?? "q").toLowerCase(),
    });
  } catch {
    result = null;
  }
  if (!result) throw new Error("Illegal move");

  return {
    fen: chess.fen(),
    move: {
      from: result.from,
      to: result.to,
      ...(result.promotion ? { promotion: result.promotion } : {}),
      san: result.san,
    },
    status: statusFromPosition(chess, color),
    legalMoves: chess.isGameOver() ? [] : legalMovesForFen(chess.fen()),
  };
}

export function statusFromPosition(chess, movingColor) {
  if (chess.isCheckmate()) return movingColor === "white" ? "white_won" : "black_won";
  if (chess.isDraw()) return "draw";
  return "active";
}

export function publicGame(game, playerColor) {
  const gameOver = !["waiting", "active"].includes(game.status);
  return {
    roomCode: game.room_code,
    fen: game.fen,
    legalMoves: game.status === "active" ? legalMovesForFen(game.fen) : [],
    playerColor,
    names: {
      white: game.white_name,
      black: game.black_name,
    },
    status: game.status,
    coachText: game.coach_text ?? "",
    version: game.version,
    gameOver,
  };
}
