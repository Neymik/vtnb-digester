#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
. "$HERE/lib.sh"

setup_shims
# Fake curl: record args, emit a Telegram-style OK JSON, exit 0.
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$CURL_ARGS_FILE"
echo '{"ok":true,"result":{"message_id":1}}'
exit 0
EOF
chmod +x "$FAKEBIN/curl"

export CURL_ARGS_FILE="$TMPDIR_T/args"
export TELEGRAM_BOT_TOKEN="TESTTOKEN"
export TELEGRAM_CHAT_ID="42"

echo "test: sends a basic message"
"$ROOT/bin/send_telegram.sh" "hello <b>world</b>"
rc=$?
assert_eq 0 "$rc" "exit code 0 on success"
args="$(cat "$CURL_ARGS_FILE")"
assert_contains "$args" "https://api.telegram.org/botTESTTOKEN/sendMessage" "calls sendMessage with token"
assert_contains "$args" "chat_id=42" "includes chat_id"
assert_contains "$args" "parse_mode=HTML" "uses HTML parse mode"

echo "test: returns non-zero on API error"
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
echo '{"ok":false,"description":"bad"}'
exit 0
EOF
chmod +x "$FAKEBIN/curl"
"$ROOT/bin/send_telegram.sh" "boom" 2>/dev/null
assert_eq 1 "$?" "exit 1 when Telegram returns ok:false"

echo "test: splits messages longer than 4096 chars into multiple sends"
: > "$TMPDIR_T/callcount"
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
echo x >> "$CALLCOUNT_FILE"
echo '{"ok":true,"result":{"message_id":1}}'
exit 0
EOF
chmod +x "$FAKEBIN/curl"
export CALLCOUNT_FILE="$TMPDIR_T/callcount"
long="$(head -c 9000 /dev/zero | tr '\0' 'a')"
"$ROOT/bin/send_telegram.sh" "$long"
calls="$(wc -l < "$CALLCOUNT_FILE" | tr -d ' ')"
# 9000 chars / 4096 => 3 chunks
assert_eq 3 "$calls" "sends 3 chunks for a 9000-char message"

echo "test: previews are off by default, on with --preview"
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$CURL_ARGS_FILE"
echo '{"ok":true,"result":{"message_id":1}}'
exit 0
EOF
chmod +x "$FAKEBIN/curl"
"$ROOT/bin/send_telegram.sh" "plain"
assert_contains "$(cat "$CURL_ARGS_FILE")" "disable_web_page_preview=true" "default disables preview"
"$ROOT/bin/send_telegram.sh" --preview "withlink"
assert_contains "$(cat "$CURL_ARGS_FILE")" "disable_web_page_preview=false" "--preview enables preview"

echo "test: literal backslash-n is converted to a real newline"
"$ROOT/bin/send_telegram.sh" 'line1\nline2'
assert_not_contains "$(cat "$CURL_ARGS_FILE")" '\n' "no literal backslash-n in payload"

teardown_shims
finish
