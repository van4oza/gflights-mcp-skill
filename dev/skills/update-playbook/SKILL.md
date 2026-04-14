---
name: update-playbook
description: Research the web for fresh Google Flights evidence and update the playbook and flights skill with current best practices. Use this skill when the user wants to check if the playbook is current, refresh flight search strategies, audit playbook claims, investigate recent Google Flights changes, or keep the skill's advice up to date.
user_invocable: true
command: update-playbook
---

# Update Google Flights Playbook

You are a senior travel-product researcher. Your job is to update the Google Flights playbook (`google-flights-playbook-2026.md`) and the flights skill (`.claude/skills/flights/SKILL.md`) with fresh, verified evidence.

## Important

- **Working directory**: This skill requires the repo root as your working directory (where `google-flights-playbook-2026.md` lives). If invoked from a different directory, tell the user to `cd` into the repo first.
- **Time warning**: This is a thorough research process involving 20+ web searches across official docs, publishers, and forums. It will take significant time. Let the user know upfront.

## Before you start

1. Read the current playbook (`google-flights-playbook-2026.md`) to understand what's already covered.
2. Read the current skill (`.claude/skills/flights/SKILL.md`) to understand what search strategies it encodes.
3. Refer to `google-flights-deep-research-prompt.md` during research for the detailed methodology, source requirements, and quality bar. You don't need to load it all upfront — consult it as needed during each step.

## Research Process

Follow the 6-step process from the research prompt. Use **WebSearch** extensively.

### Step 1 — Baseline audit

Read the playbook and build a claim inventory. For each major claim, assign a status:
- likely current
- likely stale
- needs verification
- likely missing nuance

### Step 1.5 — MCP tool audit

Before researching the web, check if the fli MCP server has been updated with new tools or parameters that we're not using yet:

1. Check the fli repo for changes: search for `site:github.com/punitarani/fli` and look at recent commits, releases, or changelog.
2. Check PyPI for the `flights` package version: search for `site:pypi.org/project/flights`.
3. Compare the current MCP tool schemas (`search_dates` and `search_flights` parameters) listed in the flights skill against what fli currently offers.
4. Look for new tools beyond `search_dates` and `search_flights` (e.g., destination discovery, price tracking, fare alerts).
5. If new parameters or tools exist, note them for Step 6 — they should be added to the skill's parameter reference and potentially integrated into the search strategy and smart defaults.

### Step 2 — Official-source pass

Search and verify against official Google sources first. Use queries like:
- `site:support.google.com/travel Google Flights [topic]`
- `site:blog.google Google Flights [topic]`
- `"Google Flights" [feature] 2025 OR 2026`

Check at minimum:
- Current help-center pages for Google Flights
- Whether "Best" vs "Cheapest" framing is still the same
- Partner coverage and missing-fare wording
- Bag-fee filter behavior
- AI Flight Deals status (beta? expanded?)
- Price guarantee scope
- Market/region limitations

### Step 3 — Publisher/tutorial pass

Search recent tutorials from reputable publishers:
- `site:thepointsguy.com "Google Flights" 2025 OR 2026`
- `site:going.com "Google Flights" 2025 OR 2026`
- `site:forbes.com "Google Flights" 2025 OR 2026`
- `site:nerdwallet.com "Google Flights" 2025 OR 2026`

Extract workflow advice. Note disagreements with official docs.

### Step 4 — Community/user-report pass

Search forums for real-world pain points and workarounds:
- `site:reddit.com/r/travel "Google Flights" [issue]`
- `site:reddit.com/r/flights "Google Flights" [issue]`
- `site:reddit.com/r/awardtravel "Google Flights"`
- `site:flyertalk.com "Google Flights" [issue]`

For any pattern you elevate, find **3+ independent threads** unless an official source also acknowledges it.

### Step 5 — Conflict resolution

Create a disagreement ledger for conflicting claims. For each, explain which source wins and why.

### Step 6 — Update

Apply changes to both files:

**Playbook (`google-flights-playbook-2026.md`):**
- Update the "Last updated" date
- Add a changelog entry at the top
- Keep the practical, skeptical tone
- Separate official facts from anecdotal observations
- Fix broken or outdated links
- Add new sections for newly discovered features or patterns
- Remove or correct stale claims
- Include inline citations for all claims

**Skill (`.claude/skills/flights/SKILL.md`):**
- Update airport lists if new major airports or city codes are relevant
- **If the fli MCP added new tools or parameters (from Step 1.5), add them to the parameter reference and integrate them into the search workflow and smart defaults**
- Update search parameter references if the MCP tools have changed
- Update advice logic if playbook findings change best practices
- Update smart defaults (carry_on, exclude_basic_economy, departure_window, emissions) if playbook findings change recommendations
- Add new strategies discovered during research

**Test skill (`dev/skills/test-flights/SKILL.md`):**
- If airport mappings changed in the flight skill, update the test scenarios' airport pairs to match
- If new search strategies were added, add a matching A/B test scenario that validates the strategy
- If MCP tool parameters changed, update both baseline and skill-guided search specs
- If bag fee estimates changed, update the baseline bag-fee assumption ($70 default)
- If smart default recommendations changed (carry_on, exclude_basic_economy, emissions), update the skill-guided search specs to match
- Keep the test scenarios realistic — use routes where the multi-airport strategy is likely to show value

## Source Requirements (minimums from the research prompt)

- **8+ official/primary sources**
- **6+ high-signal secondary sources** from at least 4 publishers
- **10+ community/user-report threads** across at least 3 communities
- **3+ airline/OTA/policy sources** for edge-case verification

## Quality Rules

- **Freshness first** — prefer sources from the last 12 months
- **Don't launder evidence** — cite official sources for product facts, not blog rewrites
- **User reports are anecdotal unless repeated** across multiple threads
- **Resolve contradictions explicitly** — don't just pick the more convenient claim
- **No vague advice** — every claim should be tagged as: official product fact, expert workflow advice, repeated user report, or open question
- **No folklore** — incognito myths, "buy on Tuesday", etc. should be debunked, not repeated

## Output

Present your findings to the user before making changes:

1. **Executive delta summary** — what changed, what stayed true, what needs correction
2. **Key claim audit results** — major updates needed, with sources
3. **Proposed changes** — what you plan to update in the playbook and skill

Wait for user approval, then apply the changes to both files.
