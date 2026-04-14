#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_SKILLS_DIR="$HOME/.claude/skills"
DIST_DIR="$REPO_DIR/dist"
DEV_MODE=false

if [ "$1" = "--dev" ]; then
    DEV_MODE=true
fi

echo "=== Google Flights Skills Installer ==="
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

# 2. Symlink /flights skill (for Claude Code)
echo ""
echo "--- Claude Code skills ---"
mkdir -p "$USER_SKILLS_DIR"

SKILL_DIR="$REPO_DIR/.claude/skills/flights"
if [ -L "$USER_SKILLS_DIR/flights" ]; then
    echo "[ok] flights — symlink already exists"
elif [ -d "$USER_SKILLS_DIR/flights" ]; then
    echo "[!!] flights — $USER_SKILLS_DIR/flights already exists (not a symlink). Skipping."
else
    ln -s "$SKILL_DIR" "$USER_SKILLS_DIR/flights"
    echo "[ok] flights — linked to $USER_SKILLS_DIR/flights"
fi

# 2b. Dev skills (only with --dev flag)
if [ "$DEV_MODE" = true ]; then
    echo ""
    echo "--- Dev skills (--dev) ---"
    for SKILL_NAME in test-flights update-playbook; do
        SKILL_DIR="$REPO_DIR/dev/skills/$SKILL_NAME"
        if [ -L "$USER_SKILLS_DIR/$SKILL_NAME" ]; then
            echo "[ok] $SKILL_NAME — symlink already exists"
        elif [ -d "$USER_SKILLS_DIR/$SKILL_NAME" ]; then
            echo "[!!] $SKILL_NAME — $USER_SKILLS_DIR/$SKILL_NAME already exists (not a symlink). Skipping."
        else
            ln -s "$SKILL_DIR" "$USER_SKILLS_DIR/$SKILL_NAME"
            echo "[ok] $SKILL_NAME — linked to $USER_SKILLS_DIR/$SKILL_NAME"
        fi
    done
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
