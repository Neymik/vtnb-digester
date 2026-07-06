#!/usr/bin/env bash
# Send a photo to Telegram with an HTML caption.
# Usage: send_photo.sh "<image_url>" "<caption_html>"
# Used for items whose source link has no preview image of its own.
# Requires TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in the environment.
set -euo pipefail

IMG="${1:-}"
CAPTION="${2:-}"
if [ -z "$IMG" ]; then
  echo "send_photo.sh: empty image url" >&2
  exit 2
fi
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto"

# Accept literal "\n" (two chars) as a line break in the caption.
CAPTION="${CAPTION//\\n/$'\n'}"

# Telegram caption hard limit is 1024 chars. Truncate defensively.
if [ "${#CAPTION}" -gt 1024 ]; then
  CAPTION="${CAPTION:0:1021}..."
fi

resp="$(curl -sS -X POST "$API" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "photo=${IMG}" \
  --data-urlencode "parse_mode=HTML" \
  --data-urlencode "caption=${CAPTION}")"

if ! printf '%s' "$resp" | grep -q '"ok":true'; then
  echo "send_photo.sh: Telegram API error: $resp" >&2
  exit 1
fi
