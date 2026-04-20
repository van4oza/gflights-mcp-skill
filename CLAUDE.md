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

Once Desktop has extracted the zip (under `~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/*/*/skills/flights/`), re-running `install.sh` replaces the extracted folder with a symlink to `.claude/skills/flights` so repo edits are live without re-uploading. Prior extractions are backed up under `~/.cache/gflights-mcp-skill/`. Desktop may re-extract on launch — if `/flights` reverts to stale content, re-run `install.sh`.

## Sub-agent execution model

The `/flights` skill uses a three-phase scout → detail → compile architecture for broad searches:

1. **Scout phase**: main assistant runs `search_dates` across all origin×destination pairs in parallel to build a price map and eliminate dead-end routes.
2. **Detail phase**: when 2+ viable origins remain, one Agent is spawned per origin. Each agent gets scout intelligence (best dates, price levels) and searches `search_flights` with full details. For a single origin, direct parallel tool calls are used only when responses are expected to be modest; otherwise still wrap in one Agent to keep raw blobs out of the main thread.
3. **Compile phase**: main assistant deduplicates results, adds connection costs, tags confidence levels, and ranks by true total cost.

Both origin AND destination airports are clustered (nearby budget hubs, secondary airports, regional alternatives). The scout phase makes this matrix search cheap.

## Known fli MCP quirks

- `search_flights` with `return_date` sometimes returns empty for dates that `search_dates` confirmed. The flights skill has a 4-step fallback (strip bags → shift dates → one-way legs → present search_dates fare).
- Bag filters (`carry_on`, `checked_bags`) can silently kill round-trip results. Retry without them if empty.

## Required env vars (Cyrus / Claude Code hosts)

`search_flights` returns 50-150 KB JSON blobs for broad queries. The Claude Agent SDK's default tool-result ceiling (~25 K tokens) truncates these and intermittently flips MCP servers into a "disconnected" state until the next refresh. Set these before launching Cyrus:

```bash
export MAX_MCP_OUTPUT_TOKENS=150000   # ~600 KB ceiling, headroom for broad search_flights blobs
export MCP_TOOL_TIMEOUT=120000        # 2 min — Google Flights throttles slow responses
```

Add to `~/.zshrc` (or wherever you launch Cyrus from). Without these, parallel `search_flights` fan-out from the `/flights` skill will trigger spurious disconnect notices.

**Why 150 K (not the 25 K default, not 200 K):** observed `search_flights` blobs peaked around 30-35 K tokens (~125 K characters) for the broadest matrix queries. 150 K leaves comfortable headroom (~5×) without inviting runaway responses to dominate the 1 M context. The skill itself routes large fan-outs through sub-agents and sub-sub-agents that filter/rank before returning, so the main thread rarely sees raw blobs even when the ceiling is high.

## Scale-related work must cite the Resource Budgets

Any change that widens the O×D matrix, adds a new wave (regional scouts, multi-modal WebFetch, open-jaw routing), or raises recursion depth MUST reference the **`## Resource Budgets`** section in `.claude/skills/flights/SKILL.md` and stay within its per-wave (≤12 L3 Agents), per-query (≤50 total Agents), and instantaneous-concurrency (≤12 in-flight) limits. The budget exists because Tier 4 caps ~20 concurrent 100 K-context agents, sessions crash at 24 parallel sub-agents (anthropics/claude-code #25714), and MCP disconnects cascade at ≥6 simultaneous oversized `search_flights` responses. PRs that add spawn-sites without citing the budget will be bounced in review.

## Update workflow

`/update-playbook` researches the web and updates the playbook, flights skill, AND test-flights scenarios together — keep all three in sync when making changes manually too.

## After merging to main

Whenever `main` is updated (e.g., after a PR merge), re-run `./install.sh` from the canonical repo (`~/.cyrus/repos/gflights-mcp-skill/`) to:

1. Rebuild `dist/flights.skill` (the Desktop upload zip) from the fresh `main` content.
2. Repoint/verify the Claude Code symlink (`~/.claude/skills/flights`) and the Claude Desktop symlink (under `skills-plugin/*/*/skills/flights/`) so both surfaces serve the updated skill.

The script is idempotent — safe to run every time. Verify with `shasum` that the three `SKILL.md` copies (repo, `~/.claude/skills/flights/`, Desktop extraction path) all match.
