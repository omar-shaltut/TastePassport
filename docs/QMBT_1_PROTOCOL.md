# QMBT-1 — Quota-Matched Broad-Taxonomy Retest

Status: PRE-REGISTERED — DO NOT RUN PROFILE-CONDITIONED RETRIEVAL BEFORE COMMIT

## Historical result

The completed formal taste-translation retest remains:

`QLOO_STRATEGY_NEEDS_REVISION`

QMBT-1 does not alter, reinterpret, or rescore that result.

## Research question

When candidate expressibility is broadened and final category composition is held constant, can Qloo produce profile-specific local-place recommendations that show meaningful taste-related advantage over the UNSIGNALED_QLOO_BASELINE?

## Primary hypothesis

The previous formulation was materially limited by:

1. an overly narrow cultural-place taxonomy; and
2. category-composition confounding.

If these limitations are addressed, profile-conditioned Qloo selection should show meaningful entity-level taste differentiation beyond the unsignaled condition.

## Confirmatory cases

The same four confirmatory cases are retained:

- Pair 2 × Istanbul
- Pair 2 × London
- Pair 3 × Istanbul
- Pair 3 × London

No new confirmatory profile pair or city is introduced.

## Frozen profiles

Pair 2:

Profile E:
- Blade Runner 2049
- Tesla
- Snow Crash

Profile F:
- The Grand Budapest Hotel
- Gucci
- The Great Gatsby

Pair 3:

Profile G:
- Into the Wild
- Patagonia
- Walden (1854, Henry David Thoreau)

Profile H:
- Lost in Translation
- Aesop
- Norwegian Wood (1987, Haruki Murakami)

Existing resolved Qloo entity IDs remain unchanged.

## Frozen place categories

Six exact Qloo category tags are used:

1. Museum
   `urn:tag:category:place:museum`

2. Art gallery
   `urn:tag:category:place:art_gallery`

3. Book store
   `urn:tag:category:place:book_store`

4. Park
   `urn:tag:category:place:park`

5. Restaurant
   `urn:tag:category:place:restaurant`

6. Shopping mall
   `urn:tag:category:place:shopping_mall`

The three new tags were selected before any QMBT-1 profile-conditioned retrieval.

Unsignaled coverage checks returned at least 50 candidates for Park, Restaurant, and Shopping mall in both Istanbul and London.

No category may be added, removed, or replaced after profile-conditioned retrieval begins.

## Category quota

Final recommendation lists use exactly:

`TOP 3 UNIQUE ENTITIES PER CATEGORY`

Therefore each complete list contains:

`18 UNIQUE ENTITIES`

subject to the deterministic deduplication rule below.

## Candidate-pool construction

For each profile-pair × city × category:

1. Retrieve TOP 3 using Profile A signals.
2. Retrieve TOP 3 using Profile B signals.
3. Retrieve TOP 3 using no `signal.interests.entities`.
4. Union and deduplicate all returned entity IDs.
5. Freeze that category-specific candidate pool.

The maximum raw contribution is 9 entities per category before deduplication.

Candidate pools are independent by:

- profile pair;
- city;
- category.

The unsignaled retrieval is included in pool construction so that the UNSIGNALED_QLOO_BASELINE is not evaluated only on a pool admitted exclusively by personalized signals.

## Fixed-pool scoring

For every frozen category-specific pool, score the exact same entity IDs under:

1. Profile A;
2. Profile B;
3. UNSIGNALED_QLOO_BASELINE.

The baseline omits `signal.interests.entities`.

It must not be called a popularity baseline.

## Final list construction

For each condition:

1. rank candidates within each category-specific frozen pool;
2. select the highest-ranked 3 unique entities for that category;
3. assemble the six category quotas into one 18-entity list.

Cross-category score magnitudes are not used to determine how many entries each category receives.

This prevents broad category composition from being the primary reason one list differs from another.

## Cross-category duplicate rule

An entity may appear only once in a final list.

If an entity qualifies in more than one category, assignment priority is fixed alphabetically by category ID:

1. art_gallery
2. book_store
3. museum
4. park
5. restaurant
6. shopping_mall

After an entity is assigned to the first eligible category, later categories must backfill from their next-ranked candidate.

Final list display order is also frozen to the same category-ID priority:

1. art_gallery
2. book_store
3. museum
4. park
5. restaurant
6. shopping_mall

Within each category block, entities retain their condition-specific Qloo ranking order.

Blind semantic and baseline packets include all 18 final-list entities; they must not truncate the quota-matched lists to Top 10.
If a category cannot provide 3 unique entities after deterministic backfilling, the case is invalid and execution stops before blind evaluation.

## Retrieval formulation

Category retrieval uses:

- `filter.type=urn:entity:place`
- exact `filter.tags`
- `filter.location.query`
- `filter.location.radius=0`
- `take=3`

Personalized retrieval additionally uses:

- `signal.interests.entities`

Unsignaled retrieval omits that parameter.

## Blind semantic evaluation

For each profile-pair × city case:

- compare the two quota-matched personalized lists;
- randomize X/Y;
- show profile seeds;
- show venue names;
- show no Qloo affinity values;
- show no generated explanations;
- show no answer key.

Four independent model evaluators are required.

A semantic case is operationally positive only when at least 3 of 4 evaluators:

1. assign both lists to the correct profiles; and
2. judge the distinction meaningfully taste-related rather than mainly generic/category-driven.

## Baseline evaluation

For each profile side:

- compare that profile's quota-matched personalized list against the quota-matched UNSIGNALED_QLOO_BASELINE;
- randomize X/Y;
- use the same blind restrictions.

Baseline advantage for a profile side is operationally positive only when at least 3 of 4 evaluators:

1. identify the personalized list as the better fit; and
2. judge that advantage meaningfully taste-related rather than mainly generic/category-driven.

A profile-pair × city case has positive baseline advantage only when both profile sides pass.

## Aggregate success rule

The success threshold is unchanged from the prior formal retest.

`SUPPORTED_FOR_NEXT_STAGE` requires at least 3 of the 4 confirmatory cases to have both:

1. positive semantic evidence; and
2. positive baseline advantage.

Those positive cases must collectively include:

- both cities; and
- both profile pairs.

No lower 2-of-4 threshold is permitted.

## Descriptive metrics

Record:

- category candidate counts;
- shared candidates;
- union size;
- Jaccard overlap;
- Top-3 retrieval overlap;
- fixed-pool ranking metrics;
- affinity distributions;
- category duplicate/backfill counts.

No single ranking or affinity metric is independently sufficient for success.

## Invalid evidence

Do not use as proof:

- ranking separation alone;
- affinity differences alone;
- category composition shifts;
- one successful profile side;
- evaluator assignment without meaningful taste-related judgment;
- manually curated venues;
- LLM-generated explanations.

## Stop conditions

Stop and do not interpret downstream results if:

- a seed fails strict resolution;
- a category tag or required API semantic becomes uncertain;
- a fixed candidate pool differs between conditions;
- a category cannot produce 3 unique final entities;
- an answer key is exposed before all evaluator responses are collected;
- a venue is manually added or removed after profile-specific results are inspected;
- any frozen category, quota, profile, city, or success rule is changed after profile-conditioned retrieval begins.

## Architecture consequence

Architecture remains frozen during QMBT-1.

If QMBT-1 succeeds under the aggregate rule, TastePassport may proceed to narrowly scoped MVP validation.

If a valid QMBT-1 run fails the aggregate rule, no third post-hoc Qloo retrieval/scoring formulation cycle will be started on these same confirmatory cases. The broad taste-translation thesis should then be treated as strongly unsupported and reconsidered before further product investment.