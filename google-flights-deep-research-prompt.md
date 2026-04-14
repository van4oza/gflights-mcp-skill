# Deep research prompt — update the Google Flights playbook with fresh evidence

Use this prompt with a browsing-capable research model. Attach the current playbook markdown file as the baseline document.

---

You are a senior travel-product researcher and aviation metasearch analyst. Your task is to update the attached Google Flights playbook using fresh, high-signal evidence from a wide mix of source types.

## Goal

Produce a **research-backed update package** for the attached Google Flights playbook. Do not merely summarize random articles. First, audit the current playbook claim by claim. Then collect fresh evidence from official Google documentation, Google product/blog updates, airline and OTA documentation where relevant, major travel publishers, and real traveler reports on forums and discussion boards. Finally, identify what should be **kept, corrected, expanded, removed, or added**.

The final output should be strong enough that an experienced traveler could rely on it as a practical, current field guide rather than generic “travel tips.”

## Core mission

You are updating an existing practical playbook about how to use Google Flights effectively. The playbook already covers topics such as:
- what Google Flights is best at and not great at
- the most effective workflow
- multiple airports and flexible-date searching
- “Best” vs “Cheapest” results
- bags / carry-on / fare-family normalization
- price tracking
- airline-direct vs OTA booking trade-offs
- self-transfer and separate-ticket risk
- checkout-price mismatches and reliability edge cases
- currency / location / point-of-sale differences
- myths such as incognito mode
- Explore, award-travel benchmarking, AI Flight Deals, emissions, train comparisons, and price guarantee
- collected tutorials and forum reports

Your job is to determine which parts of that guidance still hold, what has changed, what is missing, and what has become misleading or stale.

## Non-negotiable rules

1. **Freshness first.** Use the current date at runtime. Prefer the newest reliable sources available.
2. **Separate source roles clearly.**
   - Use **official Google sources** for product capabilities, limitations, feature names, ranking behavior, rollout notes, and caveats.
   - Use **airline / OTA / airport sources** for booking, baggage, fare-rule, or transfer-policy edge cases.
   - Use **major travel publishers** for workflows, tactics, and expert interpretation.
   - Use **forums / boards / Reddit / FlyerTalk / Stack Exchange / comments** only for real-world pain points, bugs, repeated complaints, clever workarounds, and user sentiment.
3. **Do not launder evidence.** If a claim can be verified from Google or an airline directly, do not cite a blog post instead.
4. **Treat user reports as anecdotal unless repeated.** A single post is not a fact. Look for repeated patterns across multiple independent threads.
5. **Resolve contradictions explicitly.** If sources disagree, create a disagreement log and explain which source should carry more weight and why.
6. **Do not output vague advice.** Every important claim should be tagged as one of:
   - **Official product fact**
   - **Expert workflow advice**
   - **Repeated user report**
   - **Open question / unresolved**
7. **Keep the voice practical and skeptical.** Avoid fluff, clickbait, folklore, and recycled myths.

## Minimum source mix

Use at least the following source categories and minimum counts:

- **8+ official / primary sources**
- **6+ high-signal secondary sources** from at least 4 different publishers
- **10+ community / user-report threads** across at least 3 different communities
- **3+ airline / OTA / policy sources** for edge-case verification where relevant

For any user-report pattern that you elevate into the playbook, try to support it with **at least 3 independent threads** unless the issue is also acknowledged by an official source.


### A. Primary / official sources
Check current live pages from:
- Google Travel Help / Google Flights Help Center
- Google product / Search / Travel blog posts
- Google Terms / policy / program-detail pages where relevant
- Airline / OTA / airport documentation when the playbook discusses baggage, self-transfer, booking, or fare-rule behavior

### B. High-signal secondary sources
Check recent, reputable travel-publisher tutorials and reporting, prioritizing the newest useful material from sources like:
- The Points Guy
- Going
- Forbes Advisor
- NerdWallet
- Fast Company or direct interviews with Google Flights staff
- Other reputable travel or aviation publications if they add something unique

### C. Community / user-report sources
Check real traveler discussions from:
- Reddit: r/travel, r/flights, r/awardtravel, r/travelhacks, and any highly relevant niche subreddits
- FlyerTalk
- Travel Stack Exchange
- Comments under strong tutorials or interviews if they surface recurring bugs or friction
- Other travel forums only if they contain high-signal repeated reports

### D. Low-trust / lead-generation sources
You may look at YouTube tutorials, social posts, or other informal sources **only to discover leads**. Do not rely on them for major claims unless corroborated elsewhere.

## Freshness requirements

- Prefer **official docs that are live now**.
- Prefer **tutorials and news from the last 12 months** unless an older piece is still the best available and still clearly current.
- Prefer **forum / board discussions from the last 18 months** for current user experience.
- Include older canonical threads only when they still explain an edge case that remains relevant.
- For any feature that may be market-limited, beta, experimental, mobile-only, desktop-only, or region-specific, state that clearly.
- Record **publication date** and **retrieval date** for every source.

## Specific research questions to answer

Audit the playbook against the current web and answer these questions with evidence:

1. **What has changed in Google Flights since the playbook’s last update?**
   - New features
   - Renamed or removed features
   - UI / workflow changes
   - New rollouts, pilots, or market restrictions

2. **Which existing claims in the playbook are now stale, oversimplified, or wrong?**
   Pay special attention to claims about:
   - how many partners Google compares
   - whether all fares / airlines are included
   - how often prices refresh
   - “Best” vs “Cheapest” behavior
   - link-ranking behavior for airline vs OTA links
   - self-transfer / separate-ticket warnings
   - bag-fee normalization and basic-economy filtering
   - maximum number of airports that can be searched at once
   - price tracking behavior, including exact-flight vs route tracking and flexible-date tracking
   - AI Flight Deals scope, ranking, and unsupported searches
   - price guarantee scope and exclusions
   - emissions and train-comparison features
   - location, currency, or point-of-sale effects

3. **What current tutorials actually add usable know-how?**
   Extract the best current workflows, especially around:
   - starting broad vs narrow
   - flexible dates
   - multiple airports / city codes / regions
   - using calendar, date grid, price graph, and tips together
   - deciding when to track vs buy
   - when to use Google Flights vs airline sites vs award-search tools

4. **What repeated user-reported problems or workarounds show up now?**
   Look for repeated discussion of:
   - OTA quality problems or “OTA slop” in results
   - price mismatch at click-through or checkout
   - stale / ghost fares
   - baggage / fare-family confusion
   - self-transfer surprises
   - currency or location quirks
   - award-travel benchmarking uses
   - whether myths like incognito, VPNs, or “buy on Tuesday” still circulate and how experts address them

5. **What should be added to the playbook that is missing today?**
   Especially if there are new features, new repeated complaints, or new best practices.

## Research method

Follow this exact process:

### Step 1 — Baseline audit
Read the attached playbook carefully and break it into a **claim inventory**.
For each major claim, assign a provisional status:
- likely current
- likely stale
- needs verification
- likely missing nuance

### Step 2 — Official-source pass
Build a current product-fact layer from official Google sources first.
Create a capability map for current Google Flights behavior, including feature availability, definitions, warnings, and limitations.
If an official page appears renamed, removed, or materially changed, use archived snapshots or prior high-quality coverage to understand what changed and when.

### Step 3 — Publisher/tutorial pass
Collect recent, high-quality tutorials and reporting.
Extract workflow advice, but separate it from product facts.
Note where publishers disagree with one another or with Google’s own documentation.

### Step 4 — Community/user-report pass
Collect forum and board reports for each major pain point or advanced use case.
Do not stop at one thread. For any recurring pattern, find multiple independent examples.
Where possible, distinguish between:
- one-off complaints
- repeated friction
- likely user misunderstanding
- likely product / inventory / UX problem

### Step 5 — Conflict resolution
Create a short **disagreement ledger** for conflicting claims. Examples:
- airport-count limits differ across sources
- a tutorial says a filter behaves one way, but official docs say something narrower
- user reports say prices are unreliable, but official docs describe expected reasons

For each conflict, explain which source wins and why.

### Step 6 — Delta and rewrite recommendations
For every section in the playbook, decide whether to:
- keep as-is
- lightly refresh
- materially rewrite
- remove
- add a new subsection

## Search strategy

Use broad and narrow searches. Mix feature-specific searches, publisher searches, and forum searches.

Use query patterns like these, adapting them as needed:
- `site:support.google.com/travel Google Flights [feature/topic]`
- `site:blog.google Google Flights [feature/topic]`
- `"Google Flights" [feature/topic] 2025 OR 2026`
- `site:reddit.com/r/travel "Google Flights" [issue/topic]`
- `site:reddit.com/r/flights "Google Flights" [issue/topic]`
- `site:reddit.com/r/awardtravel "Google Flights"`
- `site:flyertalk.com "Google Flights" [issue/topic]`
- `site:travel.stackexchange.com "Google Flights" [issue/topic]`
- `site:thepointsguy.com OR site:going.com OR site:nerdwallet.com OR site:forbes.com "Google Flights" [feature/topic]`

Search in English first. If a topic is clearly regional or source coverage is thin, also search in the relevant local language.

## What to verify very carefully

Do **not** trust memory on any of the following. Verify them directly:
- current help-center topic list for Google Flights
- whether Google still frames results as “Best” and “Cheapest” in the same way
- current wording around partner coverage and missing fares
- current wording around link ranking and OTA vs airline links
- whether bag-fee filters only reprice or sometimes materially change which fares appear
- whether AI Flight Deals is still beta / experimental and where it is supported
- whether maximum-airport search limits differ by interface or market
- whether price guarantee still exists, and under what conditions
- whether any feature is U.S.-only, North-America-only, or otherwise limited by market

## Output format

Return the result in five parts.

### Part 1 — Executive delta summary
A concise summary of what changed since the current playbook, what stayed true, and what now needs correction.

### Part 2 — Claim audit
For each major section of the playbook, list:
- current status: keep / update / remove / add
- what changed
- why
- confidence level
- best supporting sources

### Part 3 — Fresh source pack
Curate a source list grouped by:
- official Google sources
- airline / OTA / policy sources
- expert tutorials / reporting
- forums / boards / user reports

For each source include:
- source type
- publication date
- retrieval date
- one-line reason it matters

### Part 4 — Repeated user-report patterns
Summarize the most important repeated complaints, workarounds, and edge cases from communities.
For each pattern, note:
- how many independent threads support it
- whether it seems like a product issue, an inventory issue, a support issue, or user confusion
- whether the playbook should incorporate it

### Part 5 — Updated markdown draft
Produce a revised version of the playbook in markdown.
Requirements for the updated draft:
- preserve the practical tone of the current playbook
- keep strong skepticism toward folklore and low-quality OTAs
- separate official facts from anecdotal observations
- include inline citations
- explicitly flag region-limited, beta, or experimental features
- add a short changelog at the top
- add a “what changed since the previous version” section
- fix broken or outdated links

## Quality bar

Your answer is not good enough unless it does all of the following:
- uses a **wide source mix** instead of overfitting to one publisher or one forum
- prioritizes **fresh sources**
- distinguishes **product truth** from **user experience**
- catches **stale claims and contradictions**
- avoids copying generic “cheap flights” advice
- clearly marks uncertainty where evidence is thin
- makes the revised playbook **more useful**, not just more recent

## Important constraints

- Do not invent source details.
- Do not quote long passages; paraphrase unless a short direct quote is essential.
- Do not treat a Reddit comment as equal to official documentation.
- Do not assume U.S. behavior is global.
- Do not assume desktop and mobile behave identically.
- Do not remove nuanced caveats just to make the guide shorter.
- If a claim cannot be verified, say so and mark it unresolved.

Begin by reading the attached playbook, building the claim inventory, and then performing the official-source pass before anything else.
