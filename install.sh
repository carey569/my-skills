#!/bin/bash
# install.sh — Install auto-dev skills into Claude Code
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
MARKER="## auto-dev rules"

echo "=== Installing auto-dev skills ==="

# 1. Create commands directory
mkdir -p "$COMMANDS_DIR"

# 2. Symlink skill command files
for cmd in "$SCRIPT_DIR"/auto-dev/commands/*.md; do
    name=$(basename "$cmd")
    target="$COMMANDS_DIR/$name"
    if [ -L "$target" ]; then
        rm "$target"
    fi
    ln -sf "$cmd" "$target"
    echo "  Linked: $name"
done

# 3. Auto-inject rules into CLAUDE.md
if [ ! -f "$CLAUDE_MD" ]; then
    touch "$CLAUDE_MD"
fi

if grep -qF "$MARKER" "$CLAUDE_MD" 2>/dev/null; then
    echo "  Rules already in CLAUDE.md (skipped)"
else
    echo "" >> "$CLAUDE_MD"
    cat "$SCRIPT_DIR/auto-dev/rules/auto-dev-rules.md" >> "$CLAUDE_MD"
    echo "  Injected rules into CLAUDE.md"
fi

echo ""
echo "Done! Available skills:"
echo "  /auto-dev        Full development & verification workflow"
echo "  /fix-bug          Bug fix workflow"
echo "  /add-feature      New feature workflow"
echo ""
echo "Usage:  Type /auto-dev in Claude Code to start"
