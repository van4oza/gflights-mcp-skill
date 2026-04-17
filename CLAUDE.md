# Google Flights Skill Repo

Three Claude Code skills powered by the [fli](https://github.com/punitarani/fli) MCP server.

## Skill layout

- `.claude/skills/flights/` — public `/flights` skill (shipped to users)
- `dev/skills/test-flights/` — internal A/B value test (dev only)
- `dev/skills/update-playbook/` — internal playbook research tool (dev only)

**Skill folder name IS the slash command.** `command:` in frontmatter is ignored — Claude Code uses the directory name. Renaming the folder renames the command.

## Install

- `./install.sh` — user install (flights only, symlinks to `~/.claude/skills/`, builds `dist/flights.skill`)
- `./install.sh --dev` — dev install (also links test-flights and update-playbook)
- `./install.sh --uninstall` — remove symlinks and `dist/` (does not uninstall fli-mcp)

**Verify install:** Start Claude Code in this directory, type `/flights`, confirm the skill appears. Also confirm the fli MCP tools load by checking that `mcp__flight-search__search_flights` shows up in available tools.

Dev skills live in `dev/skills/` (not `.claude/skills/`) so users who clone the repo don't see them in their skill list.

## Naming gotchas

- The fli MCP server is named `flight-search` (from fli's code) — don't rename this in `.mcp.json`.
- Our public skill folder is `flights/` — invoked as `/flights`.
- MCP tool names follow `mcp__flight-search__search_dates` / `mcp__flight-search__search_flights`.

## Claude Desktop distribution

Skills in `.claude/skills/` only work in Claude Code. For Desktop chat / Dispatch mode, `install.sh` packages `dist/flights.skill` (a ZIP) for upload via Customize → Skills. Desktop also needs fli-mcp configured in `claude_desktop_config.json`.

## Sub-agent execution model

The `/flights` skill uses a two-phase scout→detail architecture for broad searches:

1. **Scout phase**: main assistant runs `search_dates` across all origin×destination pairs in parallel to build a price map and eliminate dead-end routes.
2. **Detail phase**: when 3+ viable origins remain, one Agent is spawned per origin. Each agent gets scout intelligence (best dates, price levels) and searches `search_flights` with full details. For 1-2 origins, parallel tool calls are used directly without agents.
3. **Compile phase**: main assistant deduplicates results, adds connection costs, tags confidence levels, and ranks by true total cost.

Both origin AND destination airports are clustered (nearby budget hubs, secondary airports, regional alternatives). The scout phase makes this matrix search cheap.

## Known fli MCP quirks

- `search_flights` with `return_date` sometimes returns empty for dates that `search_dates` confirmed. The flights skill has a 4-step fallback (strip bags → shift dates → one-way legs → present search_dates fare).
- Bag filters (`carry_on`, `checked_bags`) can silently kill round-trip results. Retry without them if empty.

## Update workflow

`/update-playbook` researches the web and updates the playbook, flights skill, AND test-flights scenarios together — keep all three in sync when making changes manually too.
