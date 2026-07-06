# CLAUDE.md — News Worker

This repo is an automated weekly news agent. Most of the time, "you" are an
instance of Claude launched headlessly (`bin/run.sh` → `claude -p`) to
produce and send a Telegram news digest. This file is your standing orientation;
the specific task you run each week is in `agent/instructions.md`.

## What this repo does
On each scheduled run, search the themes in `config/themes.yaml`, drop
anything already sent (tracked in `memory/history.json`), and send the owner one
Telegram message per item, grouped under a header per theme — each item carrying
a picture (its link's own preview, or an attached photo).

## Map
| Path | What it is |
|------|------------|
| `agent/instructions.md` | The exact weekly task. Follow it step by step. |
| `config/themes.yaml` | What to watch: themes (news + events modes), goals, sources. |
| `memory/history.json` | The ONLY state between runs. See `MEMORY.md`. |
| `bin/run.sh` | Local entrypoint / safety wrapper (lock, env, logging, alerts). |
| `agent/cloud-run.md` | Entrypoint prompt for running as a Claude cloud routine. |
| `bin/send_telegram.sh` | Sends a text message (`--preview` enables link preview). |
| `bin/send_photo.sh` | Sends a photo + HTML caption (for items lacking a preview). |
| `MEMORY.md` | The persistence + dedup model, in detail. |
| `logs/` | Per-run logs (gitignored). |

> Runs either locally (`bin/run.sh` via cron/launchd) or as a Claude cloud
> routine (`agent/cloud-run.md`). See `README.md`.

## Conventions (important when running headless)
- You are non-interactive. NEVER ask questions or wait for input — decide and act.
- Telegram messages use `parse_mode=HTML`. Use `<b>`, `<a href>`; do NOT use
  Markdown. Escape stray `<`, `>`, `&` in item text.
- Digest language is English.
- One message per item, grouped under a `<b>{theme.name}</b>` header. Every item
  gets a picture: if its link has a preview image, send with `--preview`;
  otherwise attach one via `bin/send_photo.sh`. See `agent/instructions.md` §4–5.
- `mode: events` themes are forward-looking (upcoming events in a window), not
  "new since last run". Dedup events by name+date+venue so they don't repeat
  weekly until they pass.
- A theme with no genuinely-new/relevant items is omitted entirely. If ALL
  themes are empty, send the one-line heartbeat (see `agent/instructions.md` §5).
- Mutate `memory/history.json` ONLY after a confirmed successful send. If the
  send fails, leave history untouched so the next run retries.
- Secrets live in `.env` (gitignored). Never print, log, or commit them.
- Dedup is content-based, never URL-based for `living` sources. Re-read
  `MEMORY.md` before changing dedup behavior.

## Running locally
- Tests: `bash tests/run_all.sh`
- Dry run (compose + print, no send, no history change): `bin/run.sh --dry-run`
