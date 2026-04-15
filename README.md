# Google Flights Skill for Claude Code

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that turns Claude into an expert flight search assistant. Uses the [fli](https://github.com/punitarani/fli) MCP server for Google Flights data and applies proven search strategies from a curated best-practices playbook.

## `/flights` — Search for flights

Type `/flights` in Claude Code and describe your trip. The skill will:

- **Search broadly** across multiple airports for your city (e.g. JFK + EWR + LGA for "New York") in parallel
- **Find the cheapest dates** when you're flexible, then drill into the best options
- **Normalize fares** by including bag costs, flagging basic economy traps, and warning about self-transfers
- **Compare "Best" vs "Cheapest"** so you see the quality-price tradeoff
- **Advise on booking** — book direct with the airline, verify checkout prices, watch for OTA pitfalls

### Example

```
> /flights

I need a round-trip from San Francisco to Tokyo, sometime in June,
flexible on dates. Economy, 1 checked bag. Budget around $800.
```

Claude will search SFO/OAK/SJC to NRT/HND across June, find the cheapest date windows, pull detailed flight options, and present a comparison table with actionable advice.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI, desktop app, or IDE extension)
- [fli](https://github.com/punitarani/fli) — the Google Flights MCP server
- Python 3.10+ and [pipx](https://pipx.pypa.io/) (recommended for installing fli)

## Quick Install

```bash
git clone https://github.com/van4oza/gflights-mcp-skil.git
cd gflights-mcp-skil
./install.sh
```

The install script will:
1. Install the `fli` MCP server via pipx (if not already installed)
2. Symlink the `/flights` skill to `~/.claude/skills/` so it's available in all your Claude Code sessions
3. Build `dist/flights.skill` for Claude Desktop uploads
4. Show you how to configure the MCP server globally

To uninstall: `./install.sh --uninstall` (removes symlinks and `dist/`; does not touch the fli pipx package).

## Manual Install

### 1. Install the MCP server

```bash
pipx install flights
```

Verify it works:

```bash
fli-mcp  # should start the MCP server on STDIO
```

### 2. Install the skill

**Option A — Symlink (recommended, stays up to date):**

```bash
git clone https://github.com/van4oza/gflights-mcp-skil.git
ln -s "$(pwd)/gflights-mcp-skil/.claude/skills/flights" ~/.claude/skills/flights
```

**Option B — Copy:**

```bash
git clone https://github.com/van4oza/gflights-mcp-skil.git
cp -r gflights-mcp-skil/.claude/skills/flights ~/.claude/skills/flights
```

### 3. Configure the MCP server

The repo includes an `.mcp.json` that auto-configures the server when you run Claude Code from this directory. To make it available **globally** (any directory), add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "flight-search": {
      "command": "fli-mcp",
      "args": []
    }
  }
}
```

If you use **Claude Desktop**, add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "flight-search": {
      "command": "fli-mcp",
      "args": []
    }
  }
}
```

### 4. Install skills for Claude Desktop / Dispatch / Chat (optional)

Skills in `.claude/skills/` only work in Claude Code's terminal mode. To use them in **Claude Desktop chat** or **Dispatch mode**, upload the `.skill` packages:

```bash
./install.sh  # builds .skill files in dist/
```

Then in Claude Desktop:
1. Open **Customize > Skills**
2. Upload `dist/flights.skill`

Note: `/flights` requires the fli MCP server to be configured in Claude Desktop too (see step 3 above).

## Usage

Once installed, start Claude Code and type:

```
/flights
```

Then describe your trip. You can be as vague or specific as you want:

| Prompt | What happens |
|--------|-------------|
| "Cheap flights from NYC to anywhere in Europe in May" | Searches JFK/EWR/LGA to multiple European hubs, finds cheapest dates |
| "SFO to LHR on June 15, business class" | Direct search with specific parameters |
| "Round trip Boston to Tokyo, flexible dates in September, 2 checked bags" | Date range search with bag-inclusive pricing |
| "One-way LAX to Barcelona, nonstop only, under $400" | Filtered search with budget constraint |

## How it works

The skill combines two things:

1. **[fli](https://github.com/punitarani/fli) MCP server** — provides `search_dates` (find cheapest dates in a range) and `search_flights` (get detailed flight options for a specific date) tools that query Google Flights data.

2. **Best-practices playbook** (`google-flights-playbook-2026.md`) — a curated field guide based on official Google documentation, travel publisher tutorials, and real traveler reports. The skill's search strategy, fare normalization logic, and booking advice all come from this playbook.

## Repo Structure

```
.
├── README.md                              # This file
├── install.sh                             # One-command installer
├── .mcp.json                              # MCP server config (project-level)
├── google-flights-playbook-2026.md        # Best practices reference
├── google-flights-deep-research-prompt.md # Research methodology for updates
├── .claude/
│   └── skills/
│       └── flights/
│           └── SKILL.md                   # /flights skill (public)
└── dev/
    └── skills/
        ├── test-flights/
        │   └── SKILL.md                   # /test-flights — A/B value test
        └── update-playbook/
            └── SKILL.md                   # /update-playbook — playbook research
```

## Key search strategies (from the playbook)

- **Search multiple airports**: The biggest savings lever. A $900 difference was reported just by checking alternate airports for the same city.
- **Use date flexibility before filtering**: Find the cheapest date window first, then apply airline/time/stop filters.
- **Normalize with bags**: A "cheap" fare with no bags often costs more than a "pricier" fare that includes them. The skill uses bag-inclusive pricing.
- **Compare Best vs Cheapest**: If the gap is small, pick the cleaner itinerary. If large, inspect what you're giving up (self-transfer, overnight layover, OTA booking).
- **Book direct with the airline**: Unless OTA savings are meaningful and the OTA is reputable. The skill always recommends this.
- **Verify at checkout**: Google Flights prices can differ from the airline's final price. Always confirm fare family, bags, and cancellation rules before paying.

## Development

The repo includes two internal dev skills for maintaining and testing the `/flights` skill. These are **not installed by default** — they're for contributors and maintainers.

### Install dev skills

```bash
./install.sh --dev
```

This symlinks two additional skills:

- **`/test-flights`** — A/B compares naive searches vs skill-guided searches to prove the skill finds better deals. Outputs a pass/fail report with savings per scenario.
- **`/update-playbook`** — Researches the web for fresh Google Flights evidence (official docs, travel publishers, forums) and updates the playbook, flight skill, and test skill.

## License

MIT
