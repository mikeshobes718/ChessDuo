# Chess Duo

Native iOS chess for two beginners, with cloud multiplayer, coaching assists, and optional Play-for-me.

**Repo:** https://github.com/mikeshobes718/ChessDuo  
**Collab (Mac ↔ Windows):** see [COLLAB.md](./COLLAB.md)

## Stack

- SwiftUI iOS 16+ app (`ios/`)
- Supabase Postgres + Edge Function (`supabase/functions/game`)
- Legal moves via `chess.js`
- Play-for-me engine (Easy / Medium / Hard) + opening book
- AI coaching via OpenRouter, fallback OpenAI (keys only on Supabase)

## API actions

`create`, `join`, `spectate`, `state`, `move`, `playForMe`, `hint`, `resign`, `rematch`, `offerDraw`, `respondDraw`, `offerUndo`, `respondUndo`, `listArchives`, `getArchive`, `version`

## Client features

- Room codes: create / join / spectate / share
- Randomized White/Black on join
- Draw offer, mutual undo, resign, rematch
- Move Guide, private hints, quizzes, piece guide
- Play for me (Easy / Medium / Hard) with fail-safe fallback
- Match review + Past games scorecards
- EN / PT / ES localization
- Board themes, haptics/sounds, drama banners

## iOS build (Mac only)

```bash
cd ios
xcodegen generate
# then open ChessCoach.xcodeproj or xcodebuild / install via devicectl
```

## Secrets

Set on the Supabase project (never in the iOS app or this git repo):

- `OPENROUTER_API_KEY`
- `OPENAI_API_KEY`
- `OPENROUTER_MODEL` (optional)
- `OPENAI_MODEL` (optional)

Personal local secrets live in `~/Documents/Keys/.env` on the Mac — **not** in this repository.
