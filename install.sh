#!/bin/bash
# install.sh — Install / upgrade / uninstall auto-dev skills for Claude Code
#
# One-liner install:
#   curl -fsSL https://raw.githubusercontent.com/carey569/my-skills/master/install.sh | bash
#
# Local install (after git clone):
#   bash install.sh
#
# Uninstall:
#   bash install.sh --uninstall
#   curl -fsSL https://raw.githubusercontent.com/carey569/my-skills/master/install.sh | bash -s -- --uninstall
#
set -euo pipefail

REPO_NAME="my-skills"
INSTALL_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/autodev-skills}"
REPO_URL="git@github.com:carey569/my-skills.git"
COMMANDS_DIR="$HOME/.claude/commands"

# ============================================================
# Helpers
# ============================================================

info()  { echo "  $*"; }
step()  { echo "=== $* ==="; }

# Determine the source directory (repo root with auto-dev/ inside).
# If running from within the repo, use that. Otherwise use INSTALL_DIR.
detect_source_dir() {
    # Check if this script is inside the repo (local run / already cloned)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || true

    if [[ -n "$script_dir" && -d "$script_dir/auto-dev/commands" ]]; then
        echo "$script_dir"
    elif [[ -d "$INSTALL_DIR/auto-dev/commands" ]]; then
        echo "$INSTALL_DIR"
    else
        echo ""
    fi
}

# ============================================================
# Uninstall
# ============================================================

if [[ "${1:-}" == "--uninstall" ]]; then
    step "Uninstalling auto-dev skills"

    SOURCE_DIR="$(detect_source_dir)"

    # Remove command symlinks
    if [[ -d "$COMMANDS_DIR" ]]; then
        for target in "$COMMANDS_DIR"/auto-dev*.md "$COMMANDS_DIR"/fix-bug.md "$COMMANDS_DIR"/add-feature.md; do
            [[ -e "$target" || -L "$target" ]] || continue
            rm -f "$target"
            info "Removed: $(basename "$target")"
        done
    fi

    # Clean up legacy CLAUDE.md injection (from v0.1.0 / v0.2.0)
    CLAUDE_MD="$HOME/.claude/CLAUDE.md"
    if [[ -f "$CLAUDE_MD" ]] && grep -qF "<!-- auto-dev rules BEGIN" "$CLAUDE_MD" 2>/dev/null; then
        sed -i.bak '/<!-- auto-dev rules BEGIN/,/<!-- auto-dev rules END -->/d' "$CLAUDE_MD"
        rm -f "$CLAUDE_MD.bak"
        info "Cleaned legacy rules from CLAUDE.md"
    fi

    echo ""
    echo "Uninstall complete. Repo at $INSTALL_DIR was not removed."
    echo "To fully remove: rm -rf $INSTALL_DIR"
    exit 0
fi

# ============================================================
# Install / Upgrade
# ============================================================

SOURCE_DIR="$(detect_source_dir)"

# If no local source found, clone the repo
if [[ -z "$SOURCE_DIR" ]]; then
    if ! command -v git &>/dev/null; then
        echo "Error: git is required. Install git and try again."
        exit 1
    fi

    if [[ -d "$INSTALL_DIR/.git" ]]; then
        # Directory exists and is a git repo, but not ours — could be a different repo
        step "Pulling into existing repo at $INSTALL_DIR"
        git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null || info "Pull skipped"
    elif [[ -d "$INSTALL_DIR" ]]; then
        # Directory exists but is not a git repo (or is something else)
        # Clone into a temp dir and move contents in
        step "Cloning my-skills (merging into existing $INSTALL_DIR)"
        TMPDIR=$(mktemp -d)
        git clone "$REPO_URL" "$TMPDIR/$REPO_NAME"
        # Move .git and repo files into the existing directory
        cp -a "$TMPDIR/$REPO_NAME/." "$INSTALL_DIR/"
        rm -rf "$TMPDIR"
    else
        step "Cloning my-skills"
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
    SOURCE_DIR="$INSTALL_DIR"
else
    # If running from INSTALL_DIR, pull latest
    if [[ "$SOURCE_DIR" == "$INSTALL_DIR" ]] && [[ -d "$INSTALL_DIR/.git" ]]; then
        step "Updating my-skills"
        git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null || info "Pull skipped (not on a tracking branch or offline)"
    fi
fi

VERSION=$(cat "$SOURCE_DIR/auto-dev/VERSION" 2>/dev/null || echo "unknown")
step "Installing auto-dev skills (v${VERSION})"

# 1. Create commands directory
mkdir -p "$COMMANDS_DIR"

# 2. Symlink skill command files
for cmd in "$SOURCE_DIR"/auto-dev/commands/*.md; do
    name=$(basename "$cmd")
    target="$COMMANDS_DIR/$name"

    # Clean up existing (symlink or regular file)
    if [[ -L "$target" ]]; then
        rm "$target"
    elif [[ -f "$target" ]]; then
        info "Warning: $target is a regular file, backing up to ${target}.bak"
        mv "$target" "${target}.bak"
    fi

    ln -sf "$cmd" "$target"
    info "Linked: $name"
done

# 3. Clean up legacy CLAUDE.md injection (from v0.1.0 / v0.2.0)
#    v0.3.0+ no longer injects into CLAUDE.md — commands are self-contained
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [[ -f "$CLAUDE_MD" ]] && grep -qF "<!-- auto-dev rules BEGIN" "$CLAUDE_MD" 2>/dev/null; then
    sed -i.bak '/<!-- auto-dev rules BEGIN/,/<!-- auto-dev rules END -->/d' "$CLAUDE_MD"
    rm -f "$CLAUDE_MD.bak"
    info "Cleaned legacy rules from CLAUDE.md (no longer needed)"
fi

# 4. Done
echo ""
echo "Done! Available commands:"
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
