# QMBT-2R — Direct Location Query Operationalization V1

Status: FROZEN ARCHITECTURAL DECISION / NO LIVE EXECUTION AUTHORIZED

Issue: #8

Decision identifier: `QMBT-2R-LOC-DIRECT-QUERY-V1`

## Human decision

After the failed V1 and V2 pre-Seed locality-resolution passes, the human explicitly approved `QMBT-2R-LOC-DIRECT-QUERY-V1` as the successor city operationalization for QMBT-2R.

This document freezes the architectural direction only. It does **not** authorize a development live check, Seed Commit, holdout ranking, profile-seed resolution, confirmatory Insights retrieval, or any other live Qloo call.

## Diagnostic basis

The prior locality-ID strategy remains preserved as audit history:

- V1 reached Qloo Search and stopped on New York City with `LOCALITY_AMBIGUOUS`.
- V2 resolved New York City and then stopped on Tokyo with `LOCALITY_UNRESOLVED` on a completed HTTP 200 Search response.
- Neither result is evidence for or against the TastePassport product hypothesis.
- Neither result may be used to tune and rerun the same preregistered locality-ID test.

The architectural bottleneck is therefore the QMBT-2R requirement that each city resolve to a unique Qloo `urn:entity:locality` ID before the Seed Commit, not a transport failure in the V2 harness.

## Qloo API evidence

Qloo's official public documentation supports location-scoped Insights directly without first resolving a locality UUID:

- The official recipes demonstrate `filter.location.query=New York` for place Insights: https://github.com/qloo/docs-public/blob/d4a0eb978518f7fb404993d1509d11b21239ada6/recipes/recipes.md
- The official parameter reference documents `filter.location.query` for natural-language location filtering and documents `filter.location.radius`: https://github.com/qloo/docs-public/blob/d4a0eb978518f7fb404993d1509d11b21239ada6/reference/parameters.md
- The official reference states that when `filter.location.radius` is omitted, Qloo applies default tuning that slightly expands the locality boundary; setting `filter.location.radius=0` disables that expansion and strictly limits results to the defined locality boundary.

This means a unique pre-resolved `urn:entity:locality` ID is not an API prerequisite for location-scoped QMBT-2R place retrieval. The previous locality-ID prerequisite was a repository protocol choice.

## Frozen architectural decision

`QMBT-2R-LOC-DIRECT-QUERY-V1` supersedes the pre-Seed locality-ID-resolution prerequisite for QMBT-2R city operationalization.

For QMBT-2R place retrieval:

1. Each candidate city is represented directly by one preregistered `filter.location.query` string.
2. Every request uses `filter.location.radius=0`.
3. No Qloo locality UUID is required before the Seed Commit.
4. No pre-Seed Entity Search pass is required for city identity.
5. Researcher latitude/longitude remains immutable audit metadata only and is not sent as an operational geography filter.
6. `filter.location`, WKT points/polygons, geohashes, and locality UUIDs are not fallback geography mechanisms under this decision.
7. A failed or sparse completed response must not cause query mutation, coordinate fallback, city replacement, or a content-based retry.

## Frozen city query values

The eight candidates remain unchanged. No city is replaced because of V1 or V2 output.

The direct-query strings are derived mechanically from the city label and country lookup name already committed before the V2 live pass. Admin1 text is removed; no observed Search result is used to select these strings.

| Canonical ID | Frozen `filter.location.query` |
| --- | --- |
| `city:us:new-york-city` | `New York City, United States of America` |
| `city:jp:tokyo` | `Tokyo, Japan` |
| `city:fr:paris` | `Paris, France` |
| `city:mx:mexico-city` | `Mexico City, Mexico` |
| `city:br:sao-paulo` | `São Paulo, Brazil` |
| `city:sg:singapore` | `Singapore, Singapore` |
| `city:au:sydney` | `Sydney, Australia` |
| `city:za:cape-town` | `Cape Town, South Africa` |

These exact strings are frozen by this architectural decision. A later change requires a separately reviewed protocol amendment and must not be justified by inspecting confirmatory holdout output.

## What does not change

This decision does not alter the rest of the reviewed QMBT-2R architecture:

- Qloo remains the recommendation decision source for venue selection and within-category ordering.
- The estimand remains retrieval-native profile-conditioned retrieval versus `UNSIGNALED_QLOO_BASELINE`.
- The six structural category quotas and their priority order remain unchanged.
- `retrieval_depth_K = 18` remains frozen.
- No fixed-pool rescoring, intersection-only selection, synthetic affinity, zero-imputation, LLM venue invention, substitution, or reordering is introduced.
- The single-shot remote Seed Commit anti-grinding principle remains unchanged.
- Existing development/confirmatory separation remains unchanged.
- Restaurant retrieval remains validation infrastructure only and is not a halal endorsement; production compliance filtering remains mandatory.
- Existing transport-only retry rules remain conceptually applicable, but any harness that uses this city operationalization must be separately preregistered and validated before live use.

## Required repository work before any live use

The architecture is accepted, but operational execution remains blocked until a successor implementation phase completes all of the following:

1. Amend `docs/QMBT_2R_PROTOCOL.md` so the old `QMBT-2R-LOC-v1` locality-ID prerequisite is explicitly superseded rather than silently ignored.
2. Freeze the eight direct-query values in machine-readable configuration.
3. Add static/mutation validation proving the exact eight values, `filter.location.radius=0`, and the absence of locality-ID/WKT/geohash fallback paths.
4. Pre-register a development-only direct-location validation using only already-exposed Istanbul/London material.
5. Pass repository validation for the exact implementation commit.
6. Obtain a new explicit human authorization before any live development request.
7. Stop for human review after the development result; no holdout Seed Commit or confirmatory retrieval is automatically authorized.

## Stop gate

The Architectural Validation Gate is satisfied by the human approval and this committed decision record.

The next phase is **protocol amendment + offline implementation validation** for `QMBT-2R-LOC-DIRECT-QUERY-V1`.

No live Qloo call is authorized by this document.