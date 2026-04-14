#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_SKILLS_DIR="$HOME/.claude/skills"
DIST_DIR="$REPO_DIR/dist"
SKILLS=("flights" "update-playbook" "test-flights")

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

# 2. Symlink skills to user-level (for Claude Code)
echo ""
echo "--- Claude Code skills ---"
mkdir -p "$USER_SKILLS_DIR"

for SKILL_NAME in "${SKILLS[@]}"; do
    SKILL_DIR="$REPO_DIR/.claude/skills/$SKILL_NAME"
    if [ -L "$USER_SKILLS_DIR/$SKILL_NAME" ]; then
        echo "[ok] $SKILL_NAME — symlink already exists"
    elif [ -d "$USER_SKILLS_DIR/$SKILL_NAME" ]; then
        echo "[!!] $SKILL_NAME — $USER_SKILLS_DIR/$SKILL_NAME already exists (not a symlink). Skipping."
        echo "     Remove it manually if you want to link to this repo instead."
    else
        ln -s "$SKILL_DIR" "$USER_SKILLS_DIR/$SKILL_NAME"
        echo "[ok] $SKILL_NAME — linked to $USER_SKILLS_DIR/$SKILL_NAME"
    fi
done

# 3. Build .skill packages (for Claude Desktop / Dispatch / Chat)
echo ""
echo "--- Claude Desktop / Dispatch / Chat skills ---"
mkdir -p "$DIST_DIR"

for SKILL_NAME in "${SKILLS[@]}"; do
    (cd "$REPO_DIR/.claude/skills/$SKILL_NAME" && zip -j "$DIST_DIR/$SKILL_NAME.skill" SKILL.md) > /dev/null 2>&1
    echo "[ok] $SKILL_NAME.skill — built in dist/"
done

echo ""
echo "  To use skills in Claude Desktop chat / Dispatch mode:"
echo "  1. Open Claude Desktop → Customize → Skills"
echo "  2. Upload .skill files from: $DIST_DIR/"
echo "     - flights.skill"
echo "     - test-flights.skill"
echo "     - update-playbook.skill"

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
echo "Claude Code (terminal):          /flights  /test-flights  /update-playbook"
echo "Claude Desktop (chat/dispatch):  Upload .skill files from dist/"
