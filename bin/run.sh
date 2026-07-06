#!/usr/bin/env bash
# Weekly news worker wrapper. Handles locking, env, logging, and failure alerts,
# then runs Claude headless against agent/instructions.md.
#
# Usage:
#   bin/run.sh            # real run (schedule-gated to Mon 09:xx JST; see below)
#   bin/run.sh --dry-run  # compose + print, no send, no history change
#   RUN_NOW=1 bin/run.sh  # force a real run now, ignoring the JST gate
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
LOG_DIR="${LOG_DIR:-$ROOT/logs}"
LOCK_FILE="${LOCK_FILE:-$ROOT/.run.lock}"
INSTRUCTIONS="$ROOT/agent/instructions.md"

# Ensure user-local and Homebrew bins are reachable under launchd's minimal PATH
# (the claude CLI lives in ~/.local/bin; git/jq live in Homebrew's /opt/homebrew/bin).
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || echo "$HOME/.local/bin/claude")}"

# The agent's instructions assume the repo root is the working directory, but
# launchd starts the job outside it, so make the cwd explicit.
cd "$ROOT" || { echo "cannot cd to repo root $ROOT" >&2; exit 1; }

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
export DRY_RUN

# Tokyo-time gate. The launchd agent fires hourly on (local) Mondays and we proceed
# only on the 09:xx JST tick. Tokyo has no DST, so this stays correct year-round
# regardless of the host's timezone/DST. Dry-runs and RUN_NOW=1 runs bypass the gate.
if [ "$DRY_RUN" -eq 0 ] && [ "${RUN_NOW:-0}" != "1" ]; then
  if [ "$(TZ=Asia/Tokyo date +%u%H)" != "109" ]; then
    exit 0
  fi
fi

mkdir -p "$LOG_DIR"
# Date in JST for the log filename, matching the schedule's mental model.
LOG_FILE="$LOG_DIR/run-$(TZ=Asia/Tokyo date +%F).log"

log() { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG_FILE"; }

# Load env (TELEGRAM_*). Not required for dry-run, but harmless to load.
if [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
fi

# Failure alert helper. Honors ALERT_FILE in tests (write instead of send).
alert_failure() {
  local detail="$1"
  local text=$'<b>News worker FAILED</b>\n'"The weekly run failed: ${detail}"
  if [ -n "${ALERT_FILE:-}" ]; then
    printf '%s\n' "failed: $detail" >> "$ALERT_FILE"
    return 0
  fi
  "$ROOT/bin/send_telegram.sh" "$text" >>"$LOG_FILE" 2>&1 || \
    log "ALERT: could not send failure alert"
}

# Single-instance lock. macOS has no flock(1), so use an atomic mkdir lock dir.
# We record our PID inside it so a crashed run's stale lock can be reclaimed.
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
  if [ -f "$LOCK_FILE/pid" ] && kill -0 "$(cat "$LOCK_FILE/pid" 2>/dev/null)" 2>/dev/null; then
    log "another run holds the lock (pid $(cat "$LOCK_FILE/pid")); exiting"
    exit 0
  fi
  log "reclaiming stale lock $LOCK_FILE"
  rm -rf "$LOCK_FILE"
  mkdir "$LOCK_FILE" 2>/dev/null || { log "could not acquire lock $LOCK_FILE"; exit 1; }
fi
echo "$$" > "$LOCK_FILE/pid"
trap 'rm -rf "$LOCK_FILE"' EXIT

log "starting run (dry_run=$DRY_RUN)"
"$CLAUDE_BIN" -p --dangerously-skip-permissions "$(cat "$INSTRUCTIONS")" \
  </dev/null >>"$LOG_FILE" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
  log "claude exited with code $rc"
  alert_failure "claude exited $rc (see $LOG_FILE)"
  exit "$rc"
fi
log "run completed successfully"
