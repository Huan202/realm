#!/bin/bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

MARKER_FILE="$TEST_DIR/command-was-executed"
RULE_FILE="$TEST_DIR/rule-1.conf"

cat > "$RULE_FILE" <<'EOF'
RULE_ID=1
RULE_NAME="安全测试"
RULE_ROLE="1"
LISTEN_PORT="12345"
REMOTE_HOST="example.com"
REMOTE_PORT="443"
RULE_NOTE="$(touch SHOULD_NOT_EXIST)"
ENABLED="true"
EOF

source "$REPO_ROOT/lib/core.sh"
source "$REPO_ROOT/lib/rules.sh"

sed -i "s|SHOULD_NOT_EXIST|$MARKER_FILE|" "$RULE_FILE"

read_rule_file "$RULE_FILE"

if [ -e "$MARKER_FILE" ]; then
    echo "unsafe rule parser executed command substitution" >&2
    exit 1
fi

expected_note="\$(touch $MARKER_FILE)"
if [ "$RULE_NOTE" != "$expected_note" ]; then
    echo "rule note was not parsed as literal text" >&2
    exit 1
fi

echo "security smoke test passed"
