#!/usr/bin/env bash
# claudepack installer — Unix/Mac
# Usage: curl -fsSL https://raw.githubusercontent.com/americanumberoneaokgoodtimes/claudepack/main/install.sh | bash

set -e

COMMANDS_DIR="${HOME}/.claude/commands"
BASE_URL="https://raw.githubusercontent.com/americanumberoneaokgoodtimes/claudepack/main/commands"

echo "Installing claudepack..."
mkdir -p "$COMMANDS_DIR"

curl -fsSL -o "${COMMANDS_DIR}/pack.md"   "${BASE_URL}/pack.md"
curl -fsSL -o "${COMMANDS_DIR}/unpack.md" "${BASE_URL}/unpack.md"

echo ""
echo "✅ Installed:"
echo "   ${COMMANDS_DIR}/pack.md"
echo "   ${COMMANDS_DIR}/unpack.md"
echo ""
echo "Restart Claude Code, then use /pack and /unpack."
