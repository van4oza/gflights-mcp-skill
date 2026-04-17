---
name: test-flights
description: A/B test the /flights skill by comparing naive single-airport searches against skill-guided multi-airport + date-flex + bag-normalized searches. Proves the skill finds better deals. Use this skill when the user wants to test, validate, benchmark, verify, or check whether the flight search skill is working well and adding value.
---

# Flight Search Skill — A/B Value Test

You are a test runner. Your job is to prove whether the `/flights` skill actually finds better deals than naive MCP usage by running the same queries two ways and comparing results.

## Prerequisites

The `flight-search` MCP server must be running (tools: `mcp__flight-search__search_dates`, `mcp__flight-search__search_flights`).

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
- **Sub-agent execution**: When 3+ origin airports are identified, use the Agent tool to spawn one agent per origin airport. Each agent independently runs its searches and returns top results. For 1-2 origins, use parallel tool calls directly.
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

### Scenario 5: Madrid → Tivat, flexible month, round-trip 10 days

This scenario tests both the **airport cluster search** and the **one-way combination strategy**. Madrid (MAD) has limited budget service to Tivat, but Barcelona (BCN) — reachable by ~3h AVE train — is a major Vueling hub with cheap Tivat flights. The skill should discover BCN as an alternative origin. Two separate one-way tickets are also expected to beat the round-trip bundled fare.

**Baseline:**
- `search_flights`: origin=MAD, destination=TIV, departure_date=[15th of target month], return_date=[+10 days], sort_by=CHEAPEST

**Skill-guided:**
- **Airport cluster**: Start with MAD→TIV, but also search nearby budget hubs reachable by train/bus: BCN→TIV, VLC→TIV. Also check nearby airports: GRO→TIV, REU→TIV.
- **Sub-agent execution**: With 3+ origin airports (MAD, BCN, VLC, plus optionally GRO/REU), spawn one Agent per origin. Each agent independently runs `search_dates` and `search_flights` for its origin, including one-way combinations. This tests that the sub-agent model actually produces broader results than a single-threaded search.
- `search_dates`: Each agent runs these in parallel for its pairs. Full target month, is_round_trip=true, trip_duration=10, sort_by_price=true. Also `search_dates` with `is_round_trip=false` in both directions.
- Find cheapest date across all agents' results.
- `search_flights`: Each agent searches its best date with return_date set, carry_on=true.
- **One-way combination**: Each agent also runs one-way outbound + return searches on independently optimal dates.
- **Compile**: Main assistant merges all agent results. Compare MAD direct fare vs BCN fare (+ ~€30 train), round-trip bundled vs combined one-way total.

**Compare:** Price, **whether airport cluster search found a cheaper origin** (primary metric #1), **whether one-way combination beat the round-trip fare** (primary metric #2), **count of distinct origin airports actually searched** — the concrete validation that the sub-agent model didn't silently drop airports; count origins where at least one `search_dates` or `search_flights` call returned non-empty results (primary metric #3), total savings including connection cost.

---

## Health Checks

Before comparing, verify each MCP response:
- Response is not an error
- At least 1 flight/date returned
- Prices are positive numbers (not $0, not null)
- Airline codes are real 2-letter IATA codes (not empty)
- Dates in response match the query

If a health check fails, mark that scenario as INCONCLUSIVE (MCP issue, not skill issue).

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

| Scenario | Baseline | Skill-guided | Savings | Alt airport? | Alt date? | OW combo? | Cluster? | Sub-agents? | Origins (base/skill) |
|----------|----------|--------------|---------|--------------|-----------|-----------|----------|-------------|----------------------|
| 1. NYC→LON | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A | N/A | yes/no | 1/N |
| 2. LA→TYO | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A | N/A | yes/no | 1/N |
| 3. CHI→PAR | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | N/A | yes/no | 1/N |
| 4. MAD→MOW | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | N/A | yes/no | 1/N |
| 5. MAD→TIV | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no | yes/no | yes | 1/N |

Skill found better price: X/5 scenarios
Alternate airport won: X/5 scenarios
Alternate date won: X/5 scenarios
One-way combo won: X/3 round-trip scenarios
Airport cluster won: X/1 cluster scenarios
Sub-agents used: X/5 scenarios (expected for scenarios with 3+ origins)
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
