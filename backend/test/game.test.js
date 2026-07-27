import test from "node:test";
import assert from "node:assert/strict";
import { Chess } from "chess.js";
import {
  applyMove,
  colorForToken,
  createPlayerToken,
  createRoomCode,
  hashPlayerToken,
  legalMovesForFen,
  normalizeRoomCode,
  publicGame,
} from "../lib/game.js";

test("room codes are readable and within required length", () => {
  const code = createRoomCode();
  assert.match(code, /^[A-HJ-NP-Z2-9]{6}$/);
  assert.equal(createRoomCode(4).length, 4);
  assert.throws(() => createRoomCode(3), RangeError);
  assert.equal(normalizeRoomCode(" ab2x "), "AB2X");
});

test("player tokens are random and matched by hash", () => {
  const whiteToken = createPlayerToken();
  const blackToken = createPlayerToken();
  assert.notEqual(whiteToken, blackToken);
  assert.equal(
    colorForToken(
      {
        white_token_hash: hashPlayerToken(whiteToken),
        black_token_hash: hashPlayerToken(blackToken),
      },
      blackToken,
    ),
    "black",
  );
  assert.equal(colorForToken({ white_token_hash: "x", black_token_hash: "y" }, "bad"), null);
});

test("legal move output is client friendly", () => {
  const moves = legalMovesForFen(new Chess().fen());
  assert.equal(moves.length, 20);
  assert.deepEqual(moves.find((move) => move.san === "e4"), {
    from: "e2",
    to: "e4",
    san: "e4",
  });
});

test("moves enforce color, legality, and update FEN", () => {
  const initial = new Chess().fen();
  const result = applyMove(initial, "white", { from: "e2", to: "e4" });
  assert.equal(result.move.san, "e4");
  assert.equal(new Chess(result.fen).turn(), "b");
  assert.equal(result.status, "active");
  assert.throws(() => applyMove(initial, "black", { from: "e7", to: "e5" }), /not your turn/);
  assert.throws(() => applyMove(initial, "white", { from: "e2", to: "e5" }), /Illegal move/);
});

test("checkmate sets the winner and removes legal moves", () => {
  const chess = new Chess();
  chess.move("f3");
  chess.move("e5");
  chess.move("g4");
  const result = applyMove(chess.fen(), "black", { from: "d8", to: "h4" });
  assert.equal(result.status, "black_won");
  assert.deepEqual(result.legalMoves, []);
});

test("public game response does not expose token hashes", () => {
  const game = {
    room_code: "ABCD23",
    fen: new Chess().fen(),
    white_name: "Ada",
    black_name: "Grace",
    white_token_hash: "secret",
    black_token_hash: "secret",
    status: "active",
    coach_text: "Control the center.",
    version: 2,
  };
  const value = publicGame(game, "white");
  assert.equal(value.playerColor, "white");
  assert.deepEqual(value.names, { white: "Ada", black: "Grace" });
  assert.equal(JSON.stringify(value).includes("secret"), false);
});
