# Chess Duo — Mac ↔ Windows collab

Private workflow between Mike’s Mac (this machine builds/ships) and the Pfizer Windows laptop (Cursor Ultra / Opus edits code).

## Repo

- GitHub: `https://github.com/mikeshobes718/ChessDuo`
- Local Mac path: `/Users/mike/Documents/ChessCoach`
- Do **not** put this under Pfizer script trees or mix with work repos.

## Who does what

| Mac (ship) | Windows Opus (edit) |
|------------|---------------------|
| `git pull` | `git pull` |
| iOS build + install on phones | Edit Swift / Edge Function / schema |
| Supabase function deploy | Open PRs or push feature branches |
| Anything with secrets / Keys | No secrets, no production deploys |

## Windows first-time setup

```bash
git clone https://github.com/mikeshobes718/ChessDuo.git
cd ChessDuo
```

Work on a branch:

```bash
git checkout -b feat/your-change
# ... Opus edits ...
git add -A
git commit -m "feat: short description"
git push -u origin HEAD
```

## Mac after Opus pushes

```bash
cd /Users/mike/Documents/ChessCoach
git pull
# build / deploy / install as needed
```

## Never commit

- `/Users/mike/Documents/Keys/.env` or any API keys
- Pfizer secrets / GPG files / work credentials
- `backend/node_modules`, Xcode DerivedData / `.build-device`

## Pfizer laptop boundaries

- Personal GitHub only for this app (not company GitHub)
- No phone installs, no Apple signing, no Supabase prod deploys from work
- If VPN blocks GitHub, use a network that can reach github.com
