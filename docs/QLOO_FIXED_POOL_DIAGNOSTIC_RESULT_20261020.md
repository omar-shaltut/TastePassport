# Qloo Fixed-Pool Diagnostic Result — 2026-10-20

Status: FAIL_CURRENT_FIXED_POOL_STRATEGY_NOT_VALIDATED

## Provenance

- Diagnostic run: `20261020T231640Z`
- Harness commit: `fd87cfe`
- Protocol: `docs/QLOO_FIXED_POOL_DIAGNOSTIC.md`
- Evidence class: DIAGNOSTIC_NOT_CONFIRMATORY
- City: Istanbul
- Category: `urn:tag:category:place:art_gallery`
- Frozen diagnostic pool: 8 unique entities

## Test A — Personalized Per-Entity Scoring

Result: FAIL

Observed counts:

- Identity failures: 4
- Affinity failures: 4
- Ranking instability failures: 0

All four failures were the same entity:

- Entity ID: `9E594B45-1890-425D-922C-079541139CF8`
- Name: Zorlu Performing Arts Center

The entity returned zero results under:

- Profile E, repeat 1
- Profile E, repeat 2
- Profile F, repeat 1
- Profile F, repeat 2

For both E and F, the rankings derived from successfully returned affinity
values were identical across the two repeats.

Interpretation:

The personalized failure is deterministic entity omission, not observed
ranking instability.

## Test B — Unsignaled Baseline Fixed-Pool Ranking

Result: PASS

The complete frozen entity set was returned in both repeats and ordering was
stable.

Zorlu Performing Arts Center was present in the baseline fixed-pool response
at rank 2. No baseline affinity value was required by the diagnostic.

The same entity originally entered the frozen diagnostic pool from the
UNSIGNALED_QLOO_BASELINE retrieval at source rank 2.

## Decision

The current fixed-pool strategy based on `filter.results.entities` is not
technically validated for QMBT.

A frozen entity can be validly retrieved and ranked by the unsignaled
baseline while being omitted entirely when individually evaluated under
either personalized profile.

No missing entity may be assigned an invented zero affinity or synthetic
rank.

Therefore:

1. Do not rerun QMBT using the current fixed-pool strategy.
2. Do not count this diagnostic as evidence for or against the TastePassport
   product hypothesis.
3. Reconsider the retrieval/scoring comparison strategy before any further
   confirmatory testing.
