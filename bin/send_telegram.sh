#!/usr/bin/env bash
# Send a message to Telegram. Usage: send_telegram.sh [--preview] "<message text>"
# By default link previews are OFF (compact digests). Pass --preview to let
# Telegram show the preview image of the (first) link in the text.
# Requires TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in the environment.
set -euo pipefail

# disable_web_page_preview=true means previews are OFF. Default: OFF.
DISABLE_PREVIEW="true"
if [ "${1:-}" = "--preview" ]; then
  DISABLE_PREVIEW="false"
  shift
fi

MSG="${1:-}"
if [ -z "$MSG" ]; then
  echo "send_telegram.sh: empty message" >&2
  exit 2
fi
# Accept literal "\n" (two chars) as a line break, so callers can pass newlines
# inline without shell-quoting gymnastics.
MSG="${MSG//\\n/$'\n'}"
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

send_one() {
  local text="$1"
  local resp
  resp="$(curl -sS -X POST "$API" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "parse_mode=HTML" \
    --data-urlencode "disable_web_page_preview=${DISABLE_PREVIEW}" \
    --data-urlencode "text=${text}")"
  if ! printf '%s' "$resp" | grep -q '"ok":true'; then
    echo "send_telegram.sh: Telegram API error: $resp" >&2
    return 1
  fi
}

# Telegram hard limit is 4096 chars per message. Split on that boundary,
# preferring to break at a newline within the last 512 chars of a chunk.
MAX=4096
remaining="$MSG"
while [ -n "$remaining" ]; do
  if [ "${#remaining}" -le "$MAX" ]; then
    send_one "$remaining"
    break
  fi
  chunk="${remaining:0:$MAX}"
  # Try to break at the last newline to avoid splitting mid-line.
  last_nl="${chunk%$'\n'*}"
  if [ "$last_nl" != "$chunk" ] && [ "${#last_nl}" -gt $((MAX-512)) ]; then
    chunk="$last_nl"
  fi
  send_one "$chunk"
  remaining="${remaining:${#chunk}}"
done
