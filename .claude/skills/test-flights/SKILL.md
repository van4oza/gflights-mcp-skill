---
name: test-flights
description: A/B test the /flights skill by comparing naive single-airport searches against skill-guided multi-airport + date-flex + bag-normalized searches. Proves the skill finds better deals.
user_invocable: true
command: test-flights
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
- `search_flights` on the best 1-2 dates with `checked_bags` or `carry_on` set
- Both CHEAPEST and BEST sorts

Then compare:
- **Price**: cheapest found (baseline vs skill-guided, bag-inclusive)
- **Airport**: did an alternate airport win?
- **Date**: did an alternate date win?
- **Options**: how many more options did the skill surface?

## Test Scenarios

Run all 3 scenarios. Use dates approximately 6-8 weeks from today to ensure availability.

---

### Scenario 1: NYC → London, flexible month, 1 checked bag

**Baseline:**
- `search_flights`: origin=JFK, destination=LHR, departure_date=[15th of target month], sort_by=CHEAPEST
- Note the cheapest price. Add ~$70 as estimated checked bag fee for comparison.

**Skill-guided:**
- `search_dates`: Run in parallel for all pairs: JFK→LHR, JFK→LGW, EWR→LHR, EWR→LGW, LGA→LHR, LGA→LGW. Use the full target month as date range, sort_by_price=true.
- Find the cheapest date across all pairs.
- `search_flights`: On the best date, search the top 2-3 airport pairs. Use checked_bags=1, sort_by=CHEAPEST. Also run sort_by=BEST on the winning pair.

**Compare:** Price with bags, which airport pair won, which date won.

---

### Scenario 2: LA → Tokyo, flexible month

**Baseline:**
- `search_flights`: origin=LAX, destination=NRT, departure_date=[15th of target month], sort_by=CHEAPEST

**Skill-guided:**
- `search_dates`: Run in parallel for: LAX→NRT, LAX→HND, BUR→NRT, BUR→HND, SNA→NRT, SNA→HND. Full target month, sort_by_price=true.
- Find cheapest date across all pairs.
- `search_flights`: On best date, search top pairs. Use checked_bags=1.

**Compare:** Price, airport pair, date.

---

### Scenario 3: Chicago → Paris, flexible month, round-trip 7 days

**Baseline:**
- `search_flights`: origin=ORD, destination=CDG, departure_date=[15th of target month], return_date=[22nd], sort_by=CHEAPEST

**Skill-guided:**
- `search_dates`: Run in parallel for: ORD→CDG, ORD→ORY, MDW→CDG, MDW→ORY. Full target month, is_round_trip=true, trip_duration=7, sort_by_price=true.
- Find cheapest date across all pairs.
- `search_flights`: On best date, search top pairs with return_date set, checked_bags=1.

**Compare:** Price, airport pair, date.

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

DELTA: Skill saved $XX (XX%) | Alternate airport: [yes/no] | Alternate date: [yes/no]
```

After all scenarios, output the summary:

```
=== TEST SUMMARY ===

| Scenario | Baseline | Skill-guided | Savings | Alt airport? | Alt date? |
|----------|----------|--------------|---------|--------------|-----------|
| 1. NYC→LON | $XXX | $XXX | $XX (X%) | yes/no | yes/no |
| 2. LA→TYO | $XXX | $XXX | $XX (X%) | yes/no | yes/no |
| 3. CHI→PAR | $XXX | $XXX | $XX (X%) | yes/no | yes/no |

Skill found better price: X/3 scenarios
Alternate airport won: X/3 scenarios
Alternate date won: X/3 scenarios
Average savings: $XX (XX%)

VERDICT: [PASS — skill adds clear value / MIXED — skill helps sometimes / FAIL — skill doesn't improve results]
```

## Execution Guidelines

- Launch parallel MCP calls wherever possible — don't run 18 searches sequentially.
- For `search_dates`, only look at the top 3 cheapest dates from each pair.
- Use today's date + 6 weeks as the target month for all scenarios (ensures future dates with decent availability).
- If a specific airport pair returns no results (e.g. BUR→NRT doesn't exist), note it and skip — that's valid information (the skill would learn that too).
- Round all prices to whole dollars for clean comparison.
- Estimate bag fees at $70 round-trip for baseline comparisons when the skill-guided search uses `checked_bags=1`.
