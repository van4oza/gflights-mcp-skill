#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_SKILLS_DIR="$HOME/.claude/skills"
DIST_DIR="$REPO_DIR/dist"
DEV_MODE=false
UNINSTALL=false

for arg in "$@"; do
    case "$arg" in
        --dev) DEV_MODE=true ;;
        --uninstall) UNINSTALL=true ;;
        -h|--help)
            echo "Usage: ./install.sh [--dev] [--uninstall]"
            echo "  --dev        Also install test-flights and update-playbook dev skills"
            echo "  --uninstall  Remove symlinks and dist/ (does not uninstall fli-mcp)"
            exit 0
            ;;
    esac
done

# Uninstall path
if [ "$UNINSTALL" = true ]; then
    echo "=== Google Flights Skill Uninstaller ==="
    echo ""
    for name in flights test-flights update-playbook; do
        if [ -L "$USER_SKILLS_DIR/$name" ]; then
            rm "$USER_SKILLS_DIR/$name"
            echo "[ok] removed symlink $USER_SKILLS_DIR/$name"
        fi
    done
    if [ -d "$DIST_DIR" ]; then
        rm -rf "$DIST_DIR"
        echo "[ok] removed $DIST_DIR"
    fi
    echo ""
    echo "Note: fli-mcp (pipx package) was not touched. Run 'pipx uninstall flights' to remove it."
    exit 0
fi

echo "=== Google Flights Skill Installer ==="
echo ""

# 1. Install the fli MCP server
if command -v fli-mcp &> /dev/null; then
    echo "[ok] fli-mcp is already installed"
else
    echo "[..] Installing fli MCP server (flights)..."
    if command -v pipx &> /dev/null; then
        pipx install flights
    elif command -v pip &> /dev/null; then
        pip install flights
    else
        echo "[!!] Neither pipx nor pip found. Please install Python and pipx first:"
        echo "     brew install pipx && pipx ensurepath"
        exit 1
    fi
    echo "[ok] fli-mcp installed"
fi

# Helper: symlink a skill, report if already present
link_skill() {
    local name="$1"
    local src="$2"
    if [ -L "$USER_SKILLS_DIR/$name" ]; then
        echo "[ok] $name — symlink already exists"
    elif [ -d "$USER_SKILLS_DIR/$name" ]; then
        echo "[!!] $name — $USER_SKILLS_DIR/$name already exists (not a symlink). Skipping."
    else
        ln -s "$src" "$USER_SKILLS_DIR/$name"
        echo "[ok] $name — linked to $USER_SKILLS_DIR/$name"
    fi
}

# 2. Symlink /flights skill (for Claude Code)
echo ""
echo "--- Claude Code skills ---"
mkdir -p "$USER_SKILLS_DIR"
link_skill "flights" "$REPO_DIR/.claude/skills/flights"

# 2b. Dev skills (only with --dev flag)
if [ "$DEV_MODE" = true ]; then
    echo ""
    echo "--- Dev skills (--dev) ---"
    link_skill "test-flights" "$REPO_DIR/dev/skills/test-flights"
    link_skill "update-playbook" "$REPO_DIR/dev/skills/update-playbook"
fi

# 3. Build .skill package (for Claude Desktop / Dispatch / Chat)
echo ""
echo "--- Claude Desktop / Dispatch / Chat ---"
mkdir -p "$DIST_DIR"

(cd "$REPO_DIR/.claude/skills/flights" && zip -j "$DIST_DIR/flights.skill" SKILL.md) > /dev/null 2>&1
echo "[ok] flights.skill — built in dist/"

echo ""
echo "  To use in Claude Desktop chat / Dispatch mode:"
echo "  1. Open Claude Desktop → Customize → Skills"
echo "  2. Upload: $DIST_DIR/flights.skill"

# 4. Check MCP config
echo ""
echo "--- MCP server config ---"
CLAUDE_JSON="$HOME/.claude.json"
if [ -f "$CLAUDE_JSON" ] && grep -q "fli-mcp" "$CLAUDE_JSON" 2>/dev/null; then
    echo "[ok] fli-mcp already configured in ~/.claude.json"
else
    echo "[!!] To make the MCP server available globally, add this to $CLAUDE_JSON:"
    echo ""
    echo '  {'
    echo '    "mcpServers": {'
    echo '      "flight-search": {'
    echo '        "command": "fli-mcp",'
    echo '        "args": []'
    echo '      }'
    echo '    }'
    echo '  }'
    echo ""
    echo "  Or just use this repo as your working directory — the .mcp.json here"
    echo "  will configure it automatically for any Claude Code session in this folder."
fi

echo ""
echo "=== Done! ==="
echo ""
echo "Claude Code:    /flights"
echo "Claude Desktop: Upload flights.skill from dist/"
if [ "$DEV_MODE" = true ]; then
    echo "Dev skills:     /test-flights  /update-playbook"
fi
echo ""
echo "Verify install: Start Claude Code in this directory and type '/flights' — the skill should appear in the list."
echo "Uninstall:      ./install.sh --uninstall"
