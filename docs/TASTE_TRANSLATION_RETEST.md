# Taste Translation Retest Protocol

Status: PRE-REGISTRATION IN PROGRESS

This document defines the next validation gate for TastePassport.

It exists to prevent architecture, UI, or agent-loop work from expanding before the central product promise has enough empirical support.

## Current evidence

The first validation stage established:

- Qloo responds to cross-domain taste seeds.
- Some seeds materially affect unconstrained retrieval.
- Profiles A/B showed weak discrimination under controlled and fixed-pool comparisons.
- More strongly separated Profiles C/D showed materially different rankings on the same candidate pools.
- The C/D separation replicated on an independently constructed fixed mixed-category pool.
- Blind semantic evaluation of C/D was weak: 1 of 2 evaluators matched the correct profile assignment and both reported low confidence.
- The current evidence supports personalization capability.
- The current evidence does not yet validate meaningful cross-domain taste translation.

Current decision gate:

`INCONCLUSIVE_RETEST`

## Primary research question

Can cross-domain taste profiles produce local-place recommendations that are:

1. measurably different from contrasting profiles;
2. meaningfully aligned with the intended taste profile;
3. distinguishable from generic popularity/category behavior;
4. reproducible across multiple profile pairs and more than one destination city?

## What this retest must NOT test

This retest does not test:

- agent planning;
- iterative REFINE behavior;
- LLM-generated explanations;
- UI quality;
- map presentation;
- compliance or religious-verification logic;
- itinerary generation.

Those remain downstream concerns.

## Validation layers

The retest separates four different claims.

### Layer 1 — Seed resolution

Every seed must resolve uniquely to:

- the exact expected name;
- the exact expected entity type.

No first-result fallback is allowed.

Ambiguous or unresolved seeds must be replaced before downstream retrieval.

Any replacement must be documented before recommendation results are inspected.

### Layer 2 — Ranking personalization

For identical candidate pools, compare contrasting profiles using:

- Top-10 overlap;
- Spearman rank correlation;
- Pearson affinity correlation;
- affinity-delta mean;
- affinity-delta standard deviation.

The purpose is to determine whether the profile changes item-level ranking rather than merely adding a near-constant score offset.

### Layer 3 — Semantic taste fit

Numerical separation alone is insufficient.

Blind evaluators must judge recommendations using:

- profile seeds;
- anonymized recommendation lists;
- no affinity scores;
- no Qloo labels;
- no generated explanation;
- no answer key.

Evaluators must report:

1. profile-to-list assignment;
2. confidence: low / medium / high;
3. taste-fit rationale;
4. whether the distinction is meaningfully taste-related or mainly generic/category-driven.

### Layer 4 — Baseline advantage

TastePassport must eventually demonstrate value beyond a generic destination/category ranking.

A baseline must be included only after its Qloo/API semantics are explicitly verified.

The retest must not fabricate a popularity baseline by removing signals or changing unrelated parameters without evidence that this represents generic popularity behavior.

Baseline semantics status:

`UNRESOLVED — VERIFY BEFORE EXECUTION`

## Profile pairs

Use multiple strongly separated profile pairs.

Each profile must contain exactly three seeds:

- one movie;
- one brand;
- one book.

### Pair 1 — Existing stress-test pair

Profile C:
- Mad Max: Fury Road — movie
- Harley-Davidson — brand
- Neuromancer — book

Profile D:
- Amélie — movie
- Anthropologie — brand
- The Little Prince — book

Status:

`RESOLVED AND PILOTED`

### Pair 2

Profile E:
- Blade Runner 2049 — movie
- Tesla — brand
- Snow Crash — book

Profile F:
- The Grand Budapest Hotel — movie
- Gucci — brand
- The Great Gatsby — book

Status:

`PRE-REGISTERED — STRICT RESOLUTION PENDING`

### Pair 3

Profile G:
- Into the Wild — movie
- Patagonia — brand
- Walden — book

Profile H:
- Lost in Translation — movie
- Aesop — brand
- Norwegian Wood — book

Status:

`PRE-REGISTERED — STRICT RESOLUTION PENDING`

No Pair 2 or Pair 3 recommendation results may be inspected before all six seeds in that pair pass strict resolution.

## Destination cities

### City 1

Istanbul

Status:

`PILOTED`

### City 2

`TO BE PRE-REGISTERED BEFORE RUN`

The second city should have sufficient Qloo coverage across multiple cultural/local-place categories.

City selection must be fixed before profile-specific recommendation results are inspected.

## Controlled place categories

Initial controlled categories:

- Museum
- Art gallery
- Book store

These are retained because they were already used in the pilot and support comparison with prior results.

Additional categories may be added only before execution and must be documented here.

Do not construct large blacklist-style exclusion systems to force diversity.

## Candidate-pool procedure

For each profile pair and city:

1. run controlled retrieval for the predefined categories;
2. collect a fixed number of top candidates per category from both profiles;
3. union and deduplicate candidate IDs;
4. freeze the resulting candidate pool;
5. score the exact same fixed pool with both profiles;
6. compute ranking metrics;
7. construct blind semantic packets from the resulting rankings.

Candidate pools must be independent for each profile-pair/city test.

Do not reuse a pool built specifically from another profile pair as the only evidence.

## Blind evaluation procedure

For each profile-pair/city case:

1. randomize List X / List Y assignment;
2. save a separate answer key;
3. send the blind packet to multiple independent evaluators;
4. collect evaluations before opening the answer key;
5. record evaluator identity/type only at a coarse level, such as:
   - human;
   - model A;
   - model B;
6. record assignment, confidence, and rationale verbatim or in a preserved artifact.

Minimum evaluator count:

`UNRESOLVED — SET BEFORE FINAL RETEST RUN`

The pilot used two model evaluators and was not sufficient for a strong semantic conclusion.

## Metrics to record

For every profile-pair/city case:

### Retrieval metrics

- candidate count;
- shared candidates;
- union size;
- Jaccard overlap;
- Top-10 overlap.

### Fixed-pool ranking metrics

- pool size;
- Top-10 overlap;
- Spearman rank correlation;
- Pearson affinity correlation;
- affinity-delta mean;
- affinity-delta standard deviation.

### Semantic metrics

- evaluator assignment correctness;
- evaluator confidence;
- semantic-fit rationale;
- generic/category-driven flag;
- profile-side asymmetry, if one profile has recognizable taste fit and the other does not.

### Baseline metrics

Once baseline semantics are verified:

- overlap with baseline;
- profile-vs-baseline ranking differences;
- blind preference or fit versus baseline;
- category-composition comparison.

## Invalid evidence

Do not use the following as proof of taste translation:

- affinity score changes alone;
- different result counts alone;
- category shifts alone;
- seed sensitivity alone;
- a single correct blind assignment;
- LLM-generated explanations of why a recommendation "fits";
- the invalidated all-tags `FoodSignalShare` heuristic;
- manually selected showcase venues.

## Interpretation rules

### Evidence supporting personalization capability

Supported when identical fixed candidate pools show reproducible item-level ranking differences across strongly separated profiles.

This capability was already observed in the C/D pilot.

### Evidence supporting meaningful taste translation

Requires more than ranking separation.

Evidence should show that:

- differing recommendations have plausible profile-specific semantic fit;
- independent blind evaluators can distinguish profiles with more than low-confidence guessing;
- the effect is visible across multiple pre-registered profile pairs;
- the effect replicates across more than one destination city;
- results provide value beyond a verified generic/popularity/category baseline.

### Evidence against the current formulation

Concern increases if:

- strongly separated profiles repeatedly produce nearly identical rankings;
- blind evaluators repeatedly fail to distinguish lists;
- differences are explainable mainly by broad category shifts;
- recommendations remain dominated by the same generic regional candidate pool;
- results do not improve meaningfully over the verified baseline.

## Numerical thresholds

No new hard numerical success threshold is declared in this document yet.

Reason:

The available pilot sample is too small to justify treating a specific Jaccard, Spearman, Pearson, or blind-accuracy cutoff as scientifically established.

Threshold status:

`UNRESOLVED — DEFINE ONLY IF JUSTIFIED BEFORE FINAL EXECUTION`

The final decision must consider consistency across profile pairs, cities, baseline comparisons, and blind semantic evaluation rather than a single metric.

## Stop conditions

Stop the retest and do not interpret downstream results if:

- a seed fails strict resolution;
- a candidate pool differs between the two profiles during fixed-pool scoring;
- API semantics for a required parameter are uncertain;
- an answer key is exposed before blind evaluation;
- a result is manually curated after seeing profile-specific rankings.

## Required artifacts

For every run, save:

- resolved seed records;
- request URLs without secrets;
- raw candidate IDs and names;
- affinities;
- category metadata used for analysis;
- fixed candidate-pool IDs;
- calculated metrics;
- blind packets;
- answer keys;
- evaluator responses;
- final interpretation.

Artifacts remain local unless deliberately selected for repository documentation.

Secrets must never be written to artifacts.

## Final decision outcomes

After the pre-registered retest, record exactly one:

- `SUPPORTED_FOR_NEXT_STAGE`
- `INCONCLUSIVE_RETEST`
- `QLOO_STRATEGY_NEEDS_REVISION`
- `PRODUCT_THESIS_NOT_SUPPORTED`

### SUPPORTED_FOR_NEXT_STAGE

Use only if evidence supports both:

1. reproducible personalization;
2. meaningful cross-domain taste translation beyond a generic baseline.

### INCONCLUSIVE_RETEST

Use if personalization is measurable but semantic value or generalization remains uncertain.

### QLOO_STRATEGY_NEEDS_REVISION

Use if Qloo signal exists but the current retrieval/scoring formulation does not reliably produce the product promise.

### PRODUCT_THESIS_NOT_SUPPORTED

Use if repeated controlled testing fails to show that cross-domain taste can produce meaningfully differentiated local recommendations.

## Architecture freeze rule

Until this retest reaches `SUPPORTED_FOR_NEXT_STAGE`:

- do not justify a larger agent loop using the taste-translation thesis;
- do not freeze the final recommendation architecture;
- do not invest heavily in UI polish;
- do not present Qloo affinity differences as proof of meaningful taste translation.

The experiment result, not implementation momentum, determines the next stage.
