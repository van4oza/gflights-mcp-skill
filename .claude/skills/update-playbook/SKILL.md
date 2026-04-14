---
name: update-playbook
description: Research the web for fresh Google Flights evidence and update the playbook and flight-search skill with current best practices.
user_invocable: true
command: update-playbook
---

# Update Google Flights Playbook

You are a senior travel-product researcher. Your job is to update the Google Flights playbook (`google-flights-playbook-2026.md`) and the flight-search skill (`.claude/skills/flight-search/SKILL.md`) with fresh, verified evidence.

## Before you start

1. Read the full research methodology from `google-flights-deep-research-prompt.md` — it defines the rules, source requirements, and quality bar.
2. Read the current playbook (`google-flights-playbook-2026.md`) to understand what's already covered.
3. Read the current skill (`.claude/skills/flight-search/SKILL.md`) to understand what search strategies it encodes.

## Research Process

Follow the 6-step process from the research prompt. Use **WebSearch** extensively.

### Step 1 — Baseline audit

Read the playbook and build a claim inventory. For each major claim, assign a status:
- likely current
- likely stale
- needs verification
- likely missing nuance

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

**Skill (`.claude/skills/flight-search/SKILL.md`):**
- Update airport lists if new major airports or city codes are relevant
- Update search parameter references if the MCP tools have changed
- Update advice logic if playbook findings change best practices
- Add new strategies discovered during research

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
