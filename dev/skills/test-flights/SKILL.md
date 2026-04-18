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

Run all 5 scenarios. Use dates approximately 6-8 weeks from today to ensure availability. Record the exact dates used at the top of the output so results are reproducible.

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
- **Sub-sub-agent execution (when needed)**: if any `search_flights` returns a token-limit-exceeded error, the Agent spawns a Bash+jq sub-sub-Agent to extract top-5 from the saved file. Test passes if at least one sub-sub-agent fires during this scenario (proves the recursive pattern works in practice — this scenario routinely produces oversized responses).
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
- **Sub-sub-agents used** (primary metric #6, NEW) — count of recursive jq-slice agents spawned (target ≥1)
- **Distinct origins/destinations searched** — count where at least one MCP call returned non-empty (primary metric #7)
- **Total savings including connection cost** vs baseline

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

- Confirm `MAX_MCP_OUTPUT_TOKENS` and `MCP_TOOL_TIMEOUT` are set in the host env (see Prerequisites). If not, the host is misconfigured — env-var guidance failed.
- If env vars ARE set and disconnects still appear, that's a skill regression — Agents are returning raw blobs to main instead of summarizing first. Fail the scenario as a SKILL DISCIPLINE issue rather than INCONCLUSIVE.
- If env vars are set AND Agents are summarizing properly AND disconnects still appear, that's an SDK/runtime issue — log the count and mark scenario PASS-WITH-WARNING.

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
```

After all scenarios, output the summary:

```text
=== TEST SUMMARY ===

| Scenario | Baseline | Skill-guided | Savings | Alt airport? | Alt date? | OW combo? | Open-jaw? | Cluster? | Sub-agents | Sub-sub-agents | Disconnects | Origins (base/skill) |
|----------|----------|--------------|---------|--------------|-----------|-----------|-----------|----------|------------|----------------|-------------|----------------------|
| 1. NYC→LON | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A | N/A | N/A | N | N | N | 1/N |
| 2. LA→TYO | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A | N/A | N/A | N | N | N | 1/N |
| 3. CHI→PAR | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | N/A | N/A | N | N | N | 1/N |
| 4. MAD→MOW | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | N/A | N/A | N | N | N | 1/N |
| 5. MAD→TIV | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | yes/no | yes/no | N | N | N | 1/N |

Skill found better price: X/5 scenarios
Alternate airport won: X/5 scenarios
Alternate date won: X/5 scenarios
One-way combo won: X/3 round-trip scenarios
Open-jaw won: X/1 cluster scenarios (Scenario 5 only)
Airport cluster won: X/1 cluster scenarios
Sub-agents used: X/5 scenarios (expected for any scenario with 2+ viable origins)
Sub-sub-agents used: X/5 scenarios (expected ≥1 in Scenario 5; pattern only fires on overflow)
MCP disconnects observed: X total (target = 0 with env vars set)
Total distinct origins searched (skill-guided, across all scenarios): N
Fallback strategy needed: X/5 scenarios
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
