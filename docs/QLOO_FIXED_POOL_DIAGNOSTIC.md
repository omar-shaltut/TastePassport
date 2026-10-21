# Qloo Fixed-Pool API Semantics Diagnostic

Status: PRE-REGISTERED DIAGNOSTIC — NOT CONFIRMATORY EVIDENCE

## Context

QMBT-1 run `20261020T224345Z` stopped as:

`INVALID_EXECUTION_API_SEMANTICS`

because a personalized request using `filter.results.entities` did not return the exact frozen entity set supplied by the harness.

This diagnostic does not test the TastePassport product hypothesis and must not be counted as QMBT evidence.

## Question

Can Qloo reproducibly score a known place entity under a profile when that entity is supplied individually through:

`filter.results.entities=<ONE_ENTITY_ID>`

without omitting that entity?

## Diagnostic method

Use a small place sample obtained independently from a normal place retrieval.

For each sampled place entity:

1. call Qloo with exactly one entity ID in `filter.results.entities`;
2. score it under Profile E;
3. score it under Profile F;
4. score it under `UNSIGNALED_QLOO_BASELINE`;
5. repeat the same calls once to test reproducibility.

Record for every request:

- requested entity ID;
- whether the entity was returned;
- returned entity ID;
- affinity if present;
- condition;
- request parameters excluding authentication secrets.

## Pass criteria

The single-entity method is considered technically viable for fixed-pool scoring only if:

1. every requested place entity is returned in every condition;
2. returned ID exactly matches requested ID;
3. personalized calls provide usable affinity values;
4. repeated calls do not change entity presence semantics.

## Failure criteria

The method is rejected if any requested entity is omitted under any required condition or if entity identity is inconsistent.

No missing entity may be assigned an invented affinity such as zero.

## Decision consequence

PASS:
A protocol amendment may be designed using deterministic per-entity scoring, followed by a new preregistered confirmatory run.

FAIL:
Do not attempt another fixed-pool QMBT formulation based on `filter.results.entities`; reconsider the retrieval/scoring strategy before further confirmatory testing.

## Pre-execution Amendment 1 — Complete Fixed-Pool Ranking Viability

Status: EFFECTIVE BEFORE ANY DIAGNOSTIC API CALL

### Rationale

The original diagnostic could produce a PASS after proving single-entity
presence and personalized affinity without proving that the
UNSIGNALED_QLOO_BASELINE can rank the same frozen entity pool.

QMBT requires complete rankings for Profile E, Profile F, and the
unsignaled baseline over the same entity IDs. Therefore, entity presence
alone is insufficient.

### Effective diagnostic sample

Use Istanbul / `urn:tag:category:place:art_gallery`.

Retrieve Top 3 normally for:

1. Profile E
2. Profile F
3. UNSIGNALED_QLOO_BASELINE

The diagnostic sample is the full de-duplicated union of all returned
entity IDs, preserving source order:

1. E ranking order
2. F ranking order
3. baseline ranking order

Do not reduce the union to one entity per source condition.

### Test A — Personalized per-entity scoring

For every entity in the frozen diagnostic sample:

- request that entity individually under Profile E;
- request that entity individually under Profile F;
- repeat every request once.

PASS requirements:

1. exactly one entity is returned;
2. returned ID exactly equals requested ID;
3. numeric affinity is present;
4. the complete entity set is scoreable under both profiles;
5. ranking derived from affinity is reproducible across the two repeats,
   using EntityId ascending only as a deterministic tie-breaker.

### Test B — Unsignaled baseline fixed-pool ranking

Submit the complete frozen diagnostic sample in one
`filter.results.entities` request with no taste signal.

Repeat the request once.

PASS requirements:

1. every frozen entity is returned;
2. no extra entity is returned;
3. returned IDs exactly equal the frozen sample set;
4. result ordering is identical across both repeats.

No missing entity may be assigned an invented zero score or synthetic rank.

### Revised diagnostic PASS

The diagnostic passes only if both Test A and Test B pass.

A PASS establishes technical viability for a separately pre-registered
QMBT protocol amendment. It is not confirmatory product evidence.

Any failure means the current fixed-pool strategy based on
`filter.results.entities` is not technically validated and QMBT must not
be rerun using that strategy.
