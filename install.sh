#!/bin/bash
# install.sh — Install / upgrade / uninstall auto-dev skills for Claude Code
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
RULES_FILE="$SCRIPT_DIR/auto-dev/rules/auto-dev-rules.md"
VERSION=$(cat "$SCRIPT_DIR/auto-dev/VERSION")
MARKER_BEGIN="<!-- auto-dev rules BEGIN v${VERSION} -->"
MARKER_END="<!-- auto-dev rules END -->"
MARKER_PATTERN="<!-- auto-dev rules BEGIN"

# ============================================================
# Uninstall
# ============================================================

if [[ "${1:-}" == "--uninstall" ]]; then
    echo "=== Uninstalling auto-dev skills ==="

    # Remove command symlinks
    for cmd in "$SCRIPT_DIR"/auto-dev/commands/*.md; do
        name=$(basename "$cmd")
        target="$COMMANDS_DIR/$name"
        if [ -L "$target" ]; then
            rm "$target"
            echo "  Removed: $name"
        fi
    done

    # Remove injected rules from CLAUDE.md
    if [ -f "$CLAUDE_MD" ] && grep -qF "$MARKER_PATTERN" "$CLAUDE_MD" 2>/dev/null; then
        # Remove everything between BEGIN and END markers (inclusive)
        sed -i.bak "/$MARKER_PATTERN/,/$MARKER_END/d" "$CLAUDE_MD"
        # Remove trailing blank lines
        sed -i.bak -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$CLAUDE_MD"
        rm -f "$CLAUDE_MD.bak"
        echo "  Removed rules from CLAUDE.md"
    fi

    echo ""
    echo "Uninstall complete."
    exit 0
fi

# ============================================================
# Install / Upgrade
# ============================================================

echo "=== Installing auto-dev skills (v${VERSION}) ==="

# 1. Create commands directory
mkdir -p "$COMMANDS_DIR"

# 2. Symlink skill command files
for cmd in "$SCRIPT_DIR"/auto-dev/commands/*.md; do
    name=$(basename "$cmd")
    target="$COMMANDS_DIR/$name"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -f "$target" ]; then
        echo "  Warning: $target is a regular file (not a symlink), backing up to ${target}.bak"
        mv "$target" "${target}.bak"
    fi
    ln -sf "$cmd" "$target"
    echo "  Linked: $name"
done

# 3. Inject or update rules in CLAUDE.md
if [ ! -f "$CLAUDE_MD" ]; then
    touch "$CLAUDE_MD"
fi

RULES_CONTENT=$(cat "$RULES_FILE")

if grep -qF "$MARKER_PATTERN" "$CLAUDE_MD" 2>/dev/null; then
    # Upgrade: replace existing rules block
    # Create temp file with updated content
    TEMP_FILE=$(mktemp)
    awk -v begin="$MARKER_PATTERN" -v end="$MARKER_END" -v new_begin="$MARKER_BEGIN" -v content="$RULES_CONTENT" -v new_end="$MARKER_END" '
        $0 ~ begin { skip=1; print new_begin; print content; print new_end; next }
        $0 ~ end { skip=0; next }
        !skip { print }
    ' "$CLAUDE_MD" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$CLAUDE_MD"
    echo "  Updated rules in CLAUDE.md (v${VERSION})"
else
    # Fresh install: append rules block
    {
        echo ""
        echo "$MARKER_BEGIN"
        cat "$RULES_FILE"
        echo "$MARKER_END"
    } >> "$CLAUDE_MD"
    echo "  Injected rules into CLAUDE.md (v${VERSION})"
fi

echo ""
echo "Done! Available skills:"
echo "  /auto-dev            Full development & verification workflow"
echo "  /auto-dev-init       Project environment detection"
echo "  /auto-dev-spec       Test spec generation"
echo "  /auto-dev-run        Auto coding & verification loop"
echo "  /auto-dev-report     Acceptance report"
echo "  /auto-dev-resume     Resume interrupted workflow"
echo "  /fix-bug             Bug fix workflow"
echo "  /add-feature         New feature workflow"
echo ""
echo "Usage:  Type /auto-dev in Claude Code to start"
