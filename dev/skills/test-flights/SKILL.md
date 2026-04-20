---
name: test-flights
description: A/B test the /flights skill by comparing naive single-airport searches against skill-guided multi-airport + date-flex + bag-normalized searches. Proves the skill finds better deals. Use this skill when the user wants to test, validate, benchmark, verify, or check whether the flight search skill is working well and adding value.
---

# Flight Search Skill — A/B Value Test

You are a test runner. Your job is to prove whether the `/flights` skill actually finds better deals than naive MCP usage by running the same queries two ways and comparing results.

## Prerequisites

The `flight-search` MCP server must be running (tools: `mcp__flight-search__search_dates`, `mcp__flight-search__search_flights`).

Recommended env vars (set before launching Claude Code / Cyrus to avoid tool-result truncation and spurious MCP disconnects during broad scenarios):

```bash
export MAX_MCP_OUTPUT_TOKENS=150000
export MCP_TOOL_TIMEOUT=120000
```

If env vars are not set, expect Scenarios 4-5 to occasionally need retries.

## Test Method

For each scenario, run two searches:

### Baseline (naive usage)
How someone would use the MCP tools without the skill:
- Single most obvious airport pair
- Fixed date (middle of the flexible range)
- No bag parameters
- Sort by CHEAPEST only
- One `search_flights` call

### Skill-guided (following /flights strategy)
How the skill instructs searches:
- Multiple origin and destination airports in parallel, including **airport cluster** cities reachable by train/bus/short flight (e.g. for Madrid, also check Barcelona and Valencia as budget airline hubs)
- **Sub-agent execution**: When 2+ origin airports survive scouting, spawn one Agent per origin (lowered from previous "3+" threshold). Each agent independently runs `search_flights` and returns only top-ranked summaries — never raw JSON.
- **Sub-sub-agent fallback**: If any single `search_flights` call inside an Agent returns a tool-result-too-large error (response saved to disk), the Agent should spawn a sub-sub-Agent that uses Bash+jq to extract the top 5 cheapest itineraries from the saved file. This validates the recursive delegation pattern documented in the skill.
- `search_dates` first (with `sort_by_price: true`) to find cheapest date window, plus `search_dates` with `is_round_trip: false` in both directions for independent one-way date discovery
- `search_flights` on the best 1-2 dates with smart defaults applied:
  - `carry_on: true` (always — normalizes pricing, filters basic economy on US domestic)
  - `checked_bags: 1` (when scenario involves checked luggage)
  - `exclude_basic_economy: true` (for non-budget scenarios)
- Both CHEAPEST and BEST sorts

Then compare:
- **Price**: cheapest found (baseline vs skill-guided, bag-inclusive)
- **Airport**: did an alternate airport win?
- **Date**: did an alternate date win?
- **Smart defaults impact**: did carry_on/exclude_basic_economy change the price picture?
- **One-way combo**: for round-trips, was the combined one-way total cheaper than the round-trip bundled fare?
- **Options**: how many more options did the skill surface?

## Test Scenarios

Run all 6 scenarios. Use dates approximately 6-8 weeks from today to ensure availability. Record the exact dates used at the top of the output so results are reproducible.

**Scenario 6 (wave-scaling regression)** specifically validates the Resource Budgets contract from `/flights` SKILL.md — it's the only scenario where budget telemetry is the primary pass/fail signal. Scenarios 1-5 still record the telemetry columns (`waves`, `total_agents`, `max_concurrent`) so regressions are visible even when they're not the headline.

---

### Scenario 1: NYC → London, flexible month, 1 checked bag

**Baseline:**
- `search_flights`: origin=JFK, destination=LHR, departure_date=[15th of target month], sort_by=CHEAPEST
- Note the cheapest price. Add ~$70 as estimated checked bag fee for comparison.

**Skill-guided:**
- `search_dates`: Run in parallel for all pairs: JFK→LHR, JFK→LGW, EWR→LHR, EWR→LGW, LGA→LHR, LGA→LGW. Use the full target month as date range, sort_by_price=true.
- Find the cheapest date across all pairs.
- `search_flights`: On the best date, search the top 2-3 airport pairs. Use carry_on=true, checked_bags=1, exclude_basic_economy=true, sort_by=CHEAPEST. Also run sort_by=BEST on the winning pair.

**Compare:** Price with bags, which airport pair won, which date won, did excluding basic economy change the cheapest option.

---

### Scenario 2: LA → Tokyo, flexible month

**Baseline:**
- `search_flights`: origin=LAX, destination=NRT, departure_date=[15th of target month], sort_by=CHEAPEST

**Skill-guided:**
- `search_dates`: Run in parallel for: LAX→NRT, LAX→HND, BUR→NRT, BUR→HND, SNA→NRT, SNA→HND. Full target month, sort_by_price=true.
- Find cheapest date across all pairs.
- `search_flights`: On best date, search top pairs. Use carry_on=true, checked_bags=1, exclude_basic_economy=true.

**Compare:** Price, airport pair, date, smart defaults impact.

---

### Scenario 3: Chicago → Paris, flexible month, round-trip 7 days

**Baseline:**
- `search_flights`: origin=ORD, destination=CDG, departure_date=[15th of target month], return_date=[22nd], sort_by=CHEAPEST

**Skill-guided:**
- `search_dates`: Run in parallel for: ORD→CDG, ORD→ORY, MDW→CDG, MDW→ORY. Full target month, is_round_trip=true, trip_duration=7, sort_by_price=true.
- Find cheapest date across all pairs.
- `search_flights`: On best date, search top pairs with return_date set, carry_on=true, checked_bags=1, exclude_basic_economy=true.
- **One-way combination**: In parallel with the round-trip search, also run two one-way `search_flights` (outbound: best_origin→best_dest on departure_date, return: best_dest→best_origin on return_date) with same smart defaults. Compare combined one-way total vs round-trip bundled fare.
- **If round-trip returns empty:** Test the fallback — retry without bag filters, then try ±1 day shifts. (One-way results are already available from the parallel search.)

**Compare:** Price, airport pair, date, smart defaults impact, whether fallback was needed, whether one-way combination was cheaper than round-trip.

---

### Scenario 4: Madrid → Moscow, flexible month, round-trip 3 weeks, 1 checked bag

This scenario specifically tests the round-trip fallback strategy, multi-airport destinations, and variable trip duration handling.

**Baseline:**
- `search_flights`: origin=MAD, destination=SVO, departure_date=[15th of target month], return_date=[+21 days], sort_by=CHEAPEST

**Skill-guided:**
- `search_dates`: Run in parallel for: MAD→SVO, MAD→DME, MAD→VKO. Full target month, is_round_trip=true, trip_duration=21, sort_by_price=true. Also run trip_duration=14 and trip_duration=28 in parallel to test variable duration.
- Find cheapest date and duration across all pairs.
- `search_flights`: On best date, search top pairs with return_date set, carry_on=true, checked_bags=1.
- **One-way combination**: In parallel with the round-trip search, also run two one-way `search_flights` (outbound and return) with same smart defaults. Compare combined one-way total vs round-trip bundled fare.
- **If round-trip returns empty:** Execute the full fallback: strip bags → shift dates → present search_dates fare. (One-way results are already available from the parallel search.)

**Compare:** Price, airport pair, date, duration flexibility value, whether fallback was needed, whether one-way combination was cheaper than round-trip.

---

### Scenario 5: Madrid → Tivat, flexible month, round-trip 7-10 days

This scenario tests **airport cluster search**, **destination clustering**, **one-way combination strategy**, **open-jaw routing**, and the **sub-agent + sub-sub-agent depth** patterns. Verified findings (from VAN-112, April 2026):
- MAD → TIV direct is essentially dead in spring (only €952+ available)
- BCN → TIV exists at €29-38 via Vueling (Thu/Sat only) — outbound-only, no Vueling return
- TIV → BCN return is €104+ via Air Serbia with Belgrade overnight
- **Open-jaw winner**: BCN→TIV outbound (€29) + bus to Dubrovnik + DBV→MAD (€72 Iberia direct) = €101 flights, ~€151-171 door-to-door
- Bus Tivat ↔ Dubrovnik is ~2h + Croatia/Montenegro border crossing

The skill should:
1. Cluster origins (MAD + BCN at minimum, ideally also VLC) and destinations (TIV + DBV + TGD).
2. Discover that direct MAD→TIV is essentially unavailable.
3. Discover that the open-jaw BCN-in / DBV-out beats every same-airport-both-ways option.
4. Use sub-agents per origin to keep raw `search_flights` blobs out of main context.
5. Use the sub-sub-agent + Bash+jq fallback when any single `search_flights` response overflows the token ceiling.

**Baseline:**
- `search_flights`: origin=MAD, destination=TIV, departure_date=[15th of target month], return_date=[+10 days], sort_by=CHEAPEST

**Skill-guided:**
- **Origin cluster**: MAD (stated) + BCN (AVE ~2.5h, ~€30-50) + VLC (AVE ~1h40, ~€30).
- **Destination cluster**: TIV (primary) + DBV (Dubrovnik, Croatia, ~2h bus to Tivat with border crossing) + TGD (Podgorica, ~1.5h drive to Tivat).
- **Sub-agent execution (mandatory)**: spawn one Agent per origin (≥2 origins triggers agents). Each agent runs `search_dates` for its O×D matrix in parallel, then `search_flights` on the most promising scout dates, INCLUDING one-way combinations.
- **Sub-sub-agent execution (when needed)**: if any `search_flights` returns a token-limit-exceeded error, the Agent spawns a Bash+jq sub-sub-Agent to extract top-5 from the saved file. Record the count. Zero sub-sub-agents is a valid pass when no overflow occurs (e.g., `MAX_MCP_OUTPUT_TOKENS=150000` succeeds in fitting all responses); pass-with-overflow requires every overflow to be handled by recursive extraction.
- **Open-jaw evaluation**: each agent (or the main assistant during compile) must check whether mixing outbound origin/destination with return destination/origin from a different cluster member produces a cheaper trip than any same-airport pair.
- `search_dates`: Each agent runs in parallel for its O×D pairs. Full target month, `is_round_trip=true`, `trip_duration=7` and `trip_duration=10` in parallel, `sort_by_price=true`. Also `is_round_trip=false` in both directions.
- `search_flights`: On scout-best date, with carry_on=true. Run round-trip + one-way outbound + one-way return in parallel.
- **Compile**: Main assistant merges agent summaries (NOT raw blobs). Rank by true total cost (flights + ground transport). Compare MAD direct vs BCN+train vs open-jaw BCN/DBV.

**Compare:**
- **Price** (primary metric #1) — best total cost found
- **Airport cluster won** (primary metric #2) — did an origin or destination outside the user's stated city win?
- **Open-jaw won** (primary metric #3, NEW) — did mixing outbound/return airports beat any same-airport pair?
- **One-way combination won** (primary metric #4) — did separate one-ways beat round-trip bundled?
- **Sub-agents used** (primary metric #5) — count of Agents spawned (must be ≥2 for this scenario)
- **Sub-sub-agents used** (primary metric #6, NEW) — count of recursive jq-slice agents spawned (expected >0 only when overflow is triggered; 0 is valid otherwise)
- **Distinct origins/destinations searched** — count where at least one MCP call returned non-empty (primary metric #7)
- **Total savings including connection cost** vs baseline

---

### Scenario 6: Wave-scaling regression — 8-hub European matrix, flexible month

This scenario exists to assert the **Resource Budgets** contract (see `/flights` SKILL.md `## Resource Budgets`). Its purpose is NOT price discovery — it's to prove that broad-matrix `/flights` invocations respect the per-wave and per-query caps and do not trigger MCP disconnect cascades.

**Setup:**
- Origin cluster (8 hubs): MAD, BCN, VLC, LIS, OPO, TLS, MRS, CDG.
- Destination cluster (6 airports): TIV, DBV, TGD, SJJ, SPU, ZAD.
- Full target month, round-trip, `trip_duration=[7, 10, 14]`.
- Invoke via `/flights` so the skill's sub-agent machinery engages end-to-end.

**Baseline:** (present for parity; not the focus)
- Single naive `search_flights`: MAD→TIV on the 15th of the target month. Record price only.

**Skill-guided:** run the full three-phase architecture. Because the matrix has 48 cells, the skill MUST engage Phase 1b (regional scouts). Expected wave shape under the budget:

- Phase 1a scout: main-thread `search_dates` fan-out (not Agents — no cap applies except the per-query `search_dates` total of 120).
- Phase 1b regional scout wave: ≤8 L2a Agents + optionally 1 L2b multi-modal Agent (in-flight ≤9).
- Phase 2 detail waves: ≤12 L3 Agents per wave, up to 3 waves. Between waves, ALL L3 Agents must return before the next wave starts.
- Phase 2 overflow handling: ≤4 L4 jq slicers in flight at any moment, only spawned from inside an L3 Agent when a `search_flights` blob overflows.

**Budget assertions (primary pass/fail):**
1. `max_concurrent_agents` (sum of in-flight Agents at any observed instant, across all waves) ≤ **12**.
2. `total_agents` (cumulative Agents spawned across the whole query) ≤ **50**.
3. No main-thread message spawned >12 Agents.
4. `waves` (distinct main-thread `Agent`-message rounds) ≤ **3** for L3, ≤ **1** for L2a/L2b.
5. `MCP disconnects observed` = **0**.
6. No L3 Agent spawned another L3 Agent (only L3 → L4 is permitted).
7. On any single `result exceeds maximum allowed tokens` observed in the session, the next L3 wave shrank to ≤6.

**Small-query regression (same scenario, second pass):**
Re-invoke `/flights` with a minimal query — `JFK → LHR, flexible month` — and confirm the skill takes the classic v1 path (Phase 1a → single L3 wave → Phase 3). Expected telemetry: `waves ≤ 1`, `total_agents ≤ 3`, Phase 1b **not** engaged. If the skill fires Phase 1b on a 1×1 query, that's a budget-discipline regression (preemptive-shrink condition ignored).

**Compare:**
- Price parity is informational only; scale safety is the headline.
- If any budget assertion fails, mark scenario **FAIL** even if the price is good.
- If all budget assertions pass AND the small-query regression passes, mark scenario **PASS — budget contract upheld**.

---

## Health Checks

Before comparing, verify each MCP response:
- Response is not an error
- At least 1 flight/date returned
- Prices are positive numbers (not $0, not null)
- Airline codes are real 2-letter IATA codes (not empty)
- Dates in response match the query

If a health check fails, mark that scenario as INCONCLUSIVE (MCP issue, not skill issue).

### MCP-disconnect resilience check (additional)

While running scenarios, watch for system messages saying "The following deferred tools are no longer available (their MCP server disconnected)". These indicate the tool-result truncation cascade fired. If they appear:

- Confirm `MAX_MCP_OUTPUT_TOKENS >= 150000` and `MCP_TOOL_TIMEOUT >= 120000` in the host env (see Prerequisites). Values below those thresholds — or unset — count as misconfigured (env-var guidance failed); a value like `MAX_MCP_OUTPUT_TOKENS=25000` is "set" but still useless.
- If the recommended env values ARE met and disconnects still appear, that's a skill regression — Agents are returning raw blobs to main instead of summarizing first. Fail the scenario as a SKILL DISCIPLINE issue rather than INCONCLUSIVE.
- If env values meet the thresholds AND Agents are summarizing properly AND disconnects still appear, that's an SDK/runtime issue — log the count and mark scenario PASS-WITH-WARNING.

## Output Format

For each scenario, output:

```text
=== Scenario N: [description] ===

BASELINE (naive single search):
  Route: [origin] → [dest] | Date: [date] | Cheapest: $XXX
  Origins searched: 1 | Bag-inclusive estimate: ~$XXX + $70 bag = ~$XXX

SKILL-GUIDED (multi-airport + date flex + bags):
  Best route: [origin] → [dest] | Best date: [date] | Cheapest: $XXX (bags included)
  Pairs searched: [list all pairs checked]
  Origins searched: N (count of origins where at least one call returned non-empty results)
  Dates scanned: [date range]

DELTA: Skill saved $XX (XX%) | Alt airport: [yes/no] | Alt date: [yes/no] | Smart defaults changed result: [yes/no] | One-way combo cheaper: [yes/no/N/A] | Airport cluster won: [yes/no/N/A] | Sub-agents used: [yes/no] | Origins searched (baseline/skill): 1/N

BUDGET TELEMETRY:
  waves: N | total_agents: N | max_concurrent: N | MCP disconnects: N
```

**Budget telemetry definitions:**
- `waves`: distinct main-thread messages that spawned ≥1 `Agent` tool call (L3 detail waves count; L2a/L2b counts once each).
- `total_agents`: cumulative Agents spawned across the whole query (L2a + L2b + L3 + L4).
- `max_concurrent`: peak in-flight Agent count at any observed instant.
- `MCP disconnects`: count of "deferred tools are no longer available" system messages during the scenario.

After all scenarios, output the summary:

```text
=== TEST SUMMARY ===

| Scenario | Baseline | Skill-guided | Savings | Alt airport? | Alt date? | OW combo? | Open-jaw? | Cluster? | Sub-agents | Sub-sub-agents | Disconnects | Origins (base/skill) | Waves | Total agents | Max concurrent |
|----------|----------|--------------|---------|--------------|-----------|-----------|-----------|----------|------------|----------------|-------------|----------------------|-------|--------------|----------------|
| 1. NYC→LON | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A | N/A | N/A | N | N | N | 1/N | N | N | N |
| 2. LA→TYO | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A | N/A | N/A | N | N | N | 1/N | N | N | N |
| 3. CHI→PAR | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | N/A | N/A | N | N | N | 1/N | N | N | N |
| 4. MAD→MOW | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | N/A | N/A | N | N | N | 1/N | N | N | N |
| 5. MAD→TIV | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | yes/no | yes/no | N | N | N | 1/N | N | N | N |
| 6. Budget regression | $XXX | $XXX | n/a | yes/no | yes/no | n/a | n/a | yes/no | N | N | N | 1/N | N | N | N |

Skill found better price: X/5 scenarios (Scenario 6 excluded — budget contract is its pass/fail signal)
Alternate airport won: X/5 scenarios
Alternate date won: X/5 scenarios
One-way combo won: X/3 round-trip scenarios
Open-jaw won: X/1 cluster scenarios (Scenario 5 only)
Airport cluster won: X/1 cluster scenarios
Sub-agents used: X/6 scenarios (expected for any scenario with 2+ viable origins)
Sub-sub-agents used: X/6 scenarios (expected 0 when no overflow occurs; expected >0 only when overflow is triggered and must be handled recursively)
MCP disconnects observed: X total (target = 0 with env vars set)
Total distinct origins searched (skill-guided, across all scenarios): N
Fallback strategy needed: X/5 scenarios
Average savings: $XX (XX%) across Scenarios 1-5

BUDGET CONTRACT (Scenario 6 + cross-scenario telemetry):
Max main-thread wave size across all scenarios: N (must be ≤12 — violation = FAIL)
Max per-query total agents across all scenarios: N (must be ≤50 — violation = FAIL)
Max concurrent agents observed across all scenarios: N (must be ≤12 — violation = FAIL)
Scenario 6 small-query regression: PASS / FAIL (classic v1 path on 1×1 query?)

VERDICT: [PASS — skill adds clear value + budget contract upheld / MIXED — skill helps sometimes / FAIL — skill doesn't improve results OR budget contract violated]
```

## Execution Guidelines

- Launch parallel MCP calls wherever possible — don't run 18 searches sequentially.
- For `search_dates`, only look at the top 3 cheapest dates from each pair.
- Use today's date + 6 weeks as the target month for all scenarios (ensures future dates with decent availability).
- If a specific airport pair returns no results (e.g. BUR→NRT doesn't exist), note it and skip — that's valid information (the skill would learn that too).
- Round all prices to whole dollars for clean comparison.
- Estimate bag fees at $70 round-trip for baseline comparisons when the skill-guided search uses `checked_bags=1`. This is a rough average — actual fees vary by airline ($30-$100+). Note this approximation in the output.

## When the Skill-Guided Search Does NOT Win

If the baseline matches or beats the skill-guided search in a scenario:
- Note it honestly — don't hide unfavorable results.
- Investigate why: Was it a route with only one viable airport pair? A date range where the 15th happened to be cheapest? A route where bag fees are already included? Did the one-way combination not help because the route is dominated by full-service carriers with round-trip pricing?
- The skill may not add value on every route — it's most valuable for multi-airport cities, flexible dates, and budget-airline-heavy routes where one-way combinations beat round-trip fares. Single-airport-to-single-airport routes with fixed dates and full-service carriers won't show improvement.
- If the skill loses on 2+ scenarios, flag this as a potential area for skill improvement and suggest what strategies might help.
