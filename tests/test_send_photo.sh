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

echo "test: sends a photo with caption"
"$ROOT/bin/send_photo.sh" "https://img.example/x.jpg" "<b>Title</b> — why — <a href=\"https://e/x\">link</a>"
rc=$?
assert_eq 0 "$rc" "exit code 0 on success"
args="$(cat "$CURL_ARGS_FILE")"
assert_contains "$args" "https://api.telegram.org/botTESTTOKEN/sendPhoto" "calls sendPhoto with token"
assert_contains "$args" "chat_id=42" "includes chat_id"
assert_contains "$args" "photo=https://img.example/x.jpg" "includes photo url"
assert_contains "$args" "parse_mode=HTML" "uses HTML parse mode"
assert_contains "$args" "caption=" "includes a caption"

echo "test: returns non-zero on API error"
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
echo '{"ok":false,"description":"bad"}'
exit 0
EOF
chmod +x "$FAKEBIN/curl"
"$ROOT/bin/send_photo.sh" "https://img.example/x.jpg" "cap" 2>/dev/null
assert_eq 1 "$?" "exit 1 when Telegram returns ok:false"

echo "test: empty image url is rejected"
"$ROOT/bin/send_photo.sh" "" "cap" 2>/dev/null
assert_eq 2 "$?" "exit 2 on empty image url"

echo "test: caption longer than 1024 chars is truncated"
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$CURL_ARGS_FILE"
echo '{"ok":true,"result":{"message_id":1}}'
exit 0
EOF
chmod +x "$FAKEBIN/curl"
longcap="$(head -c 2000 /dev/zero | tr '\0' 'a')"
"$ROOT/bin/send_photo.sh" "https://img.example/x.jpg" "$longcap"
args="$(cat "$CURL_ARGS_FILE")"
assert_contains "$args" "..." "truncated caption ends with ellipsis"

echo "test: literal backslash-n is converted to a real newline in caption"
"$ROOT/bin/send_photo.sh" "https://img.example/x.jpg" 'cap1\ncap2'
assert_not_contains "$(cat "$CURL_ARGS_FILE")" '\n' "no literal backslash-n in caption"

teardown_shims
finish
