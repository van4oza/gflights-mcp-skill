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

### Scenario 6: Europe → SE Asia, flexible 3-week trip (wave-scaling regression check)

This scenario validates **Phase 1b Regional Scout Wave** engagement for broad cross-regional searches. The matrix (5 European hubs × 4 SE-Asian destinations = 20 O×D pairs, spanning 3 European regions × 1 Asian region) far exceeds the ≤6-pair threshold, so Phase 1b **must** engage.

**Baseline:**
- `search_flights`: origin=LHR, destination=SIN, departure_date=[15th of target month], return_date=[+21 days], sort_by=CHEAPEST

**Skill-guided:**
- **Origin cluster (cross-regional)**: MAD, BCN (Iberia) + FRA, AMS (Central-Europe) + LGW (British-Isles) — 5 European hubs spanning 3 regions.
- **Destination cluster**: SIN, BKK, KUL, CGK (4 SE-Asian hubs). 5×4 = 20 pairs → triggers Phase 1b via the "2+ regions on origin side" gate.
- **Phase 1b engagement (mandatory)**: main assistant detects the matrix exceeds 6 pairs and spawns **≥2 Regional Scout Agents** in parallel — one per European region containing an origin (Iberia scout, Central-Europe scout, British-Isles scout = 3 scouts in this example).
- Each Regional Scout runs `search_dates` for its region's airport list × the 4 SE-Asian destinations, with `is_round_trip=true`, `is_round_trip=false` in both directions, and trip_duration sweeps of [14, 21, 28]. Returns a compact markdown table ranking its top 3-5 O×D pairs plus a one-line summary — NEVER raw JSON.
- Main assistant aggregates scout returns, picks the **global top-8 O×D pairs by price**, and advances to Phase 2 (one detail Agent per surviving origin) with carry_on=true.
- **Concurrency telemetry (mandatory)**: record `regional_scouts_spawned` (≥2 expected), `max_concurrent_agents` across Phase 1b + Phase 2 (≤12 expected), and `total_spawned` end-to-end for the query (≤50 expected).
- **Small-query regression signal**: none of the Phase 1b gates fire for Scenarios 1-5 (Scenarios 1-2 have 6-pair matrices, Scenarios 3-4 are 3-4 pairs, and Scenario 5's 9-pair Iberia→Balkans matrix is single-origin-region × single-destination-region so the "2+ regions on one side" gate doesn't trigger either). Report `phase_1b_engaged: no` for Scenarios 1-5 and `yes` for Scenario 6. This doubles as the acceptance check for `/flights JFK → LHR, flexible month`-style narrow queries — Scenario 1 is the structural equivalent (3 NYC origins × 2 London destinations = 6 pairs, all within NA-East and British-Isles single-region clusters).

**Compare (primary metrics):**
- **Price** — best total cost found vs baseline (must beat single-airport baseline on price)
- **phase_1b_engaged** — must be `yes` for this scenario, `no` for Scenarios 1-5
- **regional_scouts_spawned** — count of Regional Scout Agents spawned in parallel; must be ≥2
- **max_concurrent_agents** — highest simultaneous Agent count across Phase 1b + Phase 2; must be ≤12
- **total_spawned** — total Agents spawned end-to-end for the query; must be ≤50
- **Winning origin region** — which European region did the cheapest O×D pair come from? (information, not pass/fail)
- **Airport cluster won** — did a non-stated origin or destination win?

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

DELTA: Skill saved $XX (XX%) | Alt airport: [yes/no] | Alt date: [yes/no] | Smart defaults changed result: [yes/no] | One-way combo cheaper: [yes/no/N/A] | Airport cluster won: [yes/no/N/A] | Sub-agents used: [yes/no] | Phase 1b engaged: [yes/no] | Regional scouts: N | Max concurrent agents: N | Total spawned: N | Origins searched (baseline/skill): 1/N
```

After all scenarios, output the summary:

```text
=== TEST SUMMARY ===

| Scenario | Baseline | Skill-guided | Savings | Alt airport? | Alt date? | OW combo? | Open-jaw? | Cluster? | Sub-agents | Sub-sub-agents | Phase 1b? | Regional scouts | Max concurrent | Total spawned | Disconnects | Origins (base/skill) |
|----------|----------|--------------|---------|--------------|-----------|-----------|-----------|----------|------------|----------------|-----------|-----------------|----------------|---------------|-------------|----------------------|
| 1. NYC→LON | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A | N/A | N/A | N | N | no | 0 | N | N | N | 1/N |
| 2. LA→TYO | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A | N/A | N/A | N | N | no | 0 | N | N | N | 1/N |
| 3. CHI→PAR | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | N/A | N/A | N | N | no | 0 | N | N | N | 1/N |
| 4. MAD→MOW | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | N/A | N/A | N | N | no | 0 | N | N | N | 1/N |
| 5. MAD→TIV | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | yes/no | yes/no | N | N | no | 0 | N | N | N | 1/N |
| 6. EUR→SEA | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | N/A | yes/no | N | N | yes | N (≥2) | N (≤12) | N (≤50) | N | 1/N |

Skill found better price: X/6 scenarios
Alternate airport won: X/6 scenarios
Alternate date won: X/6 scenarios
One-way combo won: X/4 round-trip scenarios
Open-jaw won: X/1 cluster scenarios (Scenario 5 only)
Airport cluster won: X/2 cluster scenarios (Scenarios 5 and 6)
Sub-agents used: X/6 scenarios (expected for any scenario with 2+ viable origins)
Sub-sub-agents used: X/6 scenarios (expected 0 when no overflow occurs; expected >0 only when overflow is triggered and must be handled recursively)
Phase 1b engaged: X/1 scenarios (Scenario 6 only — expected yes; Scenarios 1-5 must all be no as the small-query regression check)
Regional scouts spawned (Scenario 6): N (target ≥2)
Max concurrent agents (Scenario 6): N (target ≤12)
Total Agents spawned (Scenario 6): N (target ≤50)
MCP disconnects observed: X total (target = 0 with env vars set)
Total distinct origins searched (skill-guided, across all scenarios): N
Fallback strategy needed: X/6 scenarios
Average savings: $XX (XX%)

VERDICT: [PASS — skill adds clear value / MIXED — skill helps sometimes / FAIL — skill doesn't improve results]
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
