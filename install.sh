#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_SKILLS_DIR="$HOME/.claude/skills"
DIST_DIR="$REPO_DIR/dist"
DESKTOP_SKILLS_ROOT="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin"
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
    if [ -d "$DESKTOP_SKILLS_ROOT" ]; then
        # Remove any Desktop flights symlinks that point into this repo
        while IFS= read -r -d '' link; do
            target="$(readlink "$link")"
            if [ "$target" = "$REPO_DIR/.claude/skills/flights" ]; then
                rm "$link"
                echo "[ok] removed Claude Desktop symlink $link"
            fi
        done < <(find "$DESKTOP_SKILLS_ROOT" -mindepth 4 -maxdepth 4 -name flights -type l -print0 2>/dev/null)
    fi
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

# Helper: symlink a skill. Repoints stale symlinks to the current repo.
link_skill() {
    local name="$1"
    local src="$2"
    local dest="$USER_SKILLS_DIR/$name"
    if [ -L "$dest" ]; then
        local existing
        existing="$(readlink "$dest")"
        if [ "$existing" = "$src" ]; then
            echo "[ok] $name — symlink already points to $src"
            return
        fi
        rm "$dest"
        ln -s "$src" "$dest"
        echo "[ok] $name — repointed symlink ($existing → $src)"
    elif [ -d "$dest" ]; then
        echo "[!!] $name — $dest already exists (not a symlink). Skipping."
    else
        ln -s "$src" "$dest"
        echo "[ok] $name — linked to $dest"
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

# 3. Build .skill package (for first-time Claude Desktop upload)
echo ""
echo "--- Claude Desktop / Dispatch / Chat ---"
mkdir -p "$DIST_DIR"

(cd "$REPO_DIR/.claude/skills/flights" && zip -j "$DIST_DIR/flights.skill" SKILL.md) > /dev/null 2>&1
echo "[ok] flights.skill — built in dist/"

# 3b. If the user has already uploaded a flights skill to Claude Desktop,
# replace the extracted folder with a symlink to this repo so edits are live.
DESKTOP_LINK_COUNT=0
if [ -d "$DESKTOP_SKILLS_ROOT" ]; then
    while IFS= read -r -d '' extracted; do
        target="$REPO_DIR/.claude/skills/flights"
        if [ -L "$extracted" ]; then
            if [ "$(readlink "$extracted")" = "$target" ]; then
                echo "[ok] Claude Desktop flights — symlink already points to repo ($extracted)"
                DESKTOP_LINK_COUNT=$((DESKTOP_LINK_COUNT + 1))
                continue
            fi
            rm "$extracted"
        else
            backup="$HOME/.cache/gflights-mcp-skill/desktop-backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup"
            mv "$extracted" "$backup/"
            echo "[ok] Backed up prior extraction to $backup"
        fi
        ln -s "$target" "$extracted"
        echo "[ok] Claude Desktop flights — linked $extracted → $target"
        DESKTOP_LINK_COUNT=$((DESKTOP_LINK_COUNT + 1))
    done < <(find "$DESKTOP_SKILLS_ROOT" -mindepth 4 -maxdepth 4 -name flights -print0 2>/dev/null)
fi

echo ""
if [ "$DESKTOP_LINK_COUNT" -gt 0 ]; then
    echo "  Claude Desktop will now read the skill directly from this repo."
    echo "  Note: if Claude Desktop re-extracts the .skill zip on app launch, the"
    echo "  symlink may be overwritten — re-run ./install.sh to restore it."
else
    echo "  No existing Claude Desktop upload detected."
    echo "  To use in Claude Desktop chat / Dispatch mode:"
    echo "  1. Open Claude Desktop → Customize → Skills"
    echo "  2. Upload: $DIST_DIR/flights.skill"
    echo "  3. Re-run ./install.sh to replace the extracted copy with a symlink."
fi

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

# 5. Env-var nudge — strongly recommended for broad /flights searches
echo ""
echo "--- Env vars (strongly recommended) ---"
ENV_MISSING=false
if [ -z "$MAX_MCP_OUTPUT_TOKENS" ]; then ENV_MISSING=true; fi
if [ -z "$MCP_TOOL_TIMEOUT" ]; then ENV_MISSING=true; fi

if [ "$ENV_MISSING" = true ]; then
    echo "[!!] Broad /flights searches return 50-150 KB JSON per call. The Claude Agent SDK's"
    echo "     default per-tool-result ceiling (~25 K tokens) truncates these and intermittently"
    echo "     flips MCP servers into a 'disconnected' state. Add to your ~/.zshrc (or shell rc):"
    echo ""
    echo '       export MAX_MCP_OUTPUT_TOKENS=150000   # ~600 KB ceiling'
    echo '       export MCP_TOOL_TIMEOUT=120000        # 2 min'
    echo ""
    echo "     Then restart your Claude Code / Cyrus session."
else
    echo "[ok] MAX_MCP_OUTPUT_TOKENS and MCP_TOOL_TIMEOUT are set"
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
