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
- Multiple origin and destination airports in parallel
- `search_dates` first (with `sort_by_price: true`) to find cheapest date window
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

### Scenario 5: Barcelona → Tivat, flexible month, round-trip 10 days

This scenario specifically tests the one-way combination strategy on a budget-airline-heavy intra-European route where two separate one-way tickets are expected to beat the round-trip bundled fare.

**Baseline:**
- `search_flights`: origin=BCN, destination=TIV, departure_date=[15th of target month], return_date=[+10 days], sort_by=CHEAPEST

**Skill-guided:**
- `search_dates`: Run in parallel for: BCN→TIV. Also check nearby airports: GRO→TIV, REU→TIV. Full target month, is_round_trip=true, trip_duration=10, sort_by_price=true.
- Find cheapest date across all pairs.
- `search_flights`: On best date, search top pairs with return_date set, carry_on=true.
- **One-way combination** (the key test): In parallel, run two one-way `search_flights`:
  - Outbound: best_origin→TIV on departure_date, carry_on=true, sort_by=CHEAPEST
  - Return: TIV→best_origin on return_date, carry_on=true, sort_by=CHEAPEST
- Compare: round-trip bundled fare vs combined one-way total. On budget-heavy routes like this, one-way combos frequently save 50%+.

**Compare:** Price, airport pair, date, **whether one-way combination beat the round-trip fare** (this is the primary metric for this scenario), savings percentage.

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

```
=== Scenario N: [description] ===

BASELINE (naive single search):
  Route: [origin] → [dest] | Date: [date] | Cheapest: $XXX
  Bag-inclusive estimate: ~$XXX + $70 bag = ~$XXX

SKILL-GUIDED (multi-airport + date flex + bags):
  Best route: [origin] → [dest] | Best date: [date] | Cheapest: $XXX (bags included)
  Pairs searched: [list all pairs checked]
  Dates scanned: [date range]

DELTA: Skill saved $XX (XX%) | Alt airport: [yes/no] | Alt date: [yes/no] | Smart defaults changed result: [yes/no] | One-way combo cheaper: [yes/no/N/A]
```

After all scenarios, output the summary:

```
=== TEST SUMMARY ===

| Scenario | Baseline | Skill-guided | Savings | Alt airport? | Alt date? | OW combo? |
|----------|----------|--------------|---------|--------------|-----------|-----------|
| 1. NYC→LON | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A |
| 2. LA→TYO | $XXX | $XXX | $XX (X%) | yes/no | yes/no | N/A |
| 3. CHI→PAR | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no |
| 4. MAD→MOW | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no |
| 5. BCN→TIV | $XXX | $XXX | $XX (X%) | yes/no | yes/no | yes/no |

Skill found better price: X/5 scenarios
Alternate airport won: X/5 scenarios
Alternate date won: X/5 scenarios
One-way combo won: X/3 round-trip scenarios
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
