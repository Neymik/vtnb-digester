#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
. "$HERE/lib.sh"

setup_shims

# A fake .env so run.sh can load creds.
cat > "$TMPDIR_T/.env" <<EOF
TELEGRAM_BOT_TOKEN=TT
TELEGRAM_CHAT_ID=42
EOF

# Fake claude: record that it ran, echo its prompt arg, succeed.
cat > "$FAKEBIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "claude-ran DRY_RUN=${DRY_RUN:-0}" > "$CLAUDE_MARK"
exit 0
EOF
chmod +x "$FAKEBIN/claude"
export CLAUDE_MARK="$TMPDIR_T/claude_mark"

echo "test: --dry-run sets DRY_RUN=1 and does not require sending"
# CLAUDE_BIN pins the fake claude: run.sh prepends ~/.local/bin to PATH, so a
# PATH-only shim would be shadowed by the real claude. Never let tests hit it.
ENV_FILE="$TMPDIR_T/.env" LOG_DIR="$TMPDIR_T/logs" \
  LOCK_FILE="$TMPDIR_T/.run.lock" CLAUDE_BIN="$FAKEBIN/claude" \
  "$ROOT/bin/run.sh" --dry-run >/dev/null 2>&1
assert_eq 0 "$?" "dry-run exits 0"
assert_contains "$(cat "$CLAUDE_MARK")" "DRY_RUN=1" "passes DRY_RUN=1 to claude"

echo "test: a failing claude run triggers a Telegram failure alert"
cat > "$FAKEBIN/claude" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
chmod +x "$FAKEBIN/claude"
# Shim send_telegram.sh by intercepting via a fake on PATH is not possible
# (run.sh calls it by absolute path), so use ALERT_HOOK env the script honors.
: > "$TMPDIR_T/alert"
# RUN_NOW=1 bypasses the Mon-12-JST gate so this test is time-independent.
RUN_NOW=1 ENV_FILE="$TMPDIR_T/.env" LOG_DIR="$TMPDIR_T/logs" \
  LOCK_FILE="$TMPDIR_T/.run.lock" CLAUDE_BIN="$FAKEBIN/claude" \
  ALERT_FILE="$TMPDIR_T/alert" \
  "$ROOT/bin/run.sh" >/dev/null 2>&1
rc=$?
assert_eq 7 "$rc" "wrapper propagates claude's non-zero exit"
assert_contains "$(cat "$TMPDIR_T/alert")" "failed" "writes a failure alert"

teardown_shims
finish
