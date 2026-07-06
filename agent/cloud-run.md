# Cloud routine entrypoint

You are the automated weekly news worker, running as a scheduled Claude cloud
routine. This IS the scheduled run and it is fully authorized — there is no human
to answer. Do not second-guess timing, repo state, or whether to send.

Do the following, in order:

1. Follow `agent/instructions.md` end-to-end and **send the digest for real**
   (do NOT treat this as a dry run; `DRY_RUN` is unset). Telegram credentials are
   provided as the environment variables `TELEGRAM_BOT_TOKEN` and
   `TELEGRAM_CHAT_ID` — the send scripts read them from the environment, so you do
   NOT need a `.env` file.
2. After the send completes and `memory/history.json` has been updated, commit it:

   ```bash
   git add memory/history.json
   git commit -m "chore: update sent-history ($(date -u +%FT%TZ))"
   ```

   Do NOT push to `main` directly — the routine can only push to its own
   `claude/*` branch, and a GitHub Actions workflow (`.github/workflows/
   merge-routine-state.yml`) auto-merges that branch into `main`. Committing is
   enough; the routine publishes the commit to its branch. If nothing changed in
   `memory/history.json`, skip the commit.
