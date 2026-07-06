# vtnb-digester

A weekly, self-hosted **news digest bot** powered by Claude. Each run searches the
sources/queries in `config/themes.yaml`, dedups against `memory/history.json`, and
sends a grouped digest to Telegram — one message per item, grouped by theme. Themes
with no new items are omitted. State lives entirely in the repo (`memory/history.json`);
there is no server or external database.

This is a **template**. Click **Use this template** to create your own instance.

## What's here

| Path | What it is |
|------|------------|
| `agent/instructions.md` | The weekly task the agent follows step by step. |
| `agent/cloud-run.md` | Entrypoint prompt for running as a Claude cloud routine. |
| `config/themes.yaml` | What to watch. Ships with one example theme (AI & Dev Tools). |
| `memory/history.json` | The ONLY state between runs (dedup). See `MEMORY.md`. |
| `bin/run.sh` | Local entrypoint (lock, env, logging, alerts) → `claude -p`. |
| `bin/send_telegram.sh` / `bin/send_photo.sh` | Telegram senders. |
| `.github/workflows/merge-routine-state.yml` | Auto-merges the routine's `claude/*` state branch into `main`. |
| `tests/` | `bash tests/run_all.sh`. |

## Quick start (local test)

1. `cp .env.example .env` and fill `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`.
   - Token: create a bot via [@BotFather](https://t.me/BotFather).
   - Chat ID: DM your bot once, then
     `curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates"` and read
     `result[].message.chat.id`.
2. Edit `config/themes.yaml` with your themes.
3. Smoke-test delivery:
   ```bash
   set -a; . ./.env; set +a
   bin/send_telegram.sh "news worker test ✅"
   ```
4. Dry-run the agent (composes + prints, sends nothing):
   ```bash
   bin/run.sh --dry-run
   ```

## Run it in the cloud (Claude routine — no server, no API key)

Runs on Anthropic's cloud under your Claude subscription, on a weekly schedule.

1. **Use this template** → create your own repo (private recommended).
2. Create a routine at [claude.ai/code/routines](https://claude.ai/code/routines)
   (or `/schedule` in Claude Code) and connect it to your repo.
3. **Environment variables:** set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`.
   Note: there is no secrets store yet — these sit in the routine's env config,
   visible to anyone who can edit the routine.
4. **Network access:** allowlist `api.telegram.org` (GitHub is already trusted).
5. **State merge:** ensure **GitHub Actions is enabled** for your repo. The
   included `.github/workflows/merge-routine-state.yml` auto-merges the routine's
   `claude/*` state branch into `main`. (The routine can only push to `claude/*`
   branches — the "unrestricted branch pushes" toggle does **not** grant direct
   `main` pushes, so this workflow does the landing.)
6. **Schedule:** cron in your local timezone, e.g. `30 9 * * 1` = Monday 09:30.
7. **Prompt:** point the routine at `agent/cloud-run.md` (send for real, then
   commit `memory/history.json` — the workflow lands it on `main`).

## How dedup survives daily-updating sources

- `permalink` / `permalink_feed` sources: deduped by URL, kept ~60 days.
- `living` sources (timelines, homepages): the URL never changes while content
  does, so items are deduped by a **content fingerprint + date**, never by URL.

## Logs

Local per-run logs land in `logs/` (gitignored), named by date.
