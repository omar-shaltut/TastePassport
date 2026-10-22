# QMBT-2R Direct-Location Development Mechanism V1

Status: PRE-REGISTERED DEVELOPMENT MECHANISM / LIVE EXECUTION REQUIRES EXPLICIT HUMAN AUTHORIZATION

Issue: #12

Protocol identifier: `QMBT-2R-DIRECT-LOCATION-DEVELOPMENT-V1`

Source architecture: `QMBT-2R-LOC-DIRECT-QUERY-V1`

Evidence class: `DEVELOPMENT_DIAGNOSTIC_ONLY`

## Purpose

Validate whether the frozen QMBT-2R retrieval design can structurally fill its six category quotas when city geography is supplied through Qloo `filter.location.query` with `filter.location.radius=0`.

This is a mechanism/feasibility check only. It does not test the TastePassport product hypothesis, semantic taste fit, baseline advantage, evaluator agreement, UI quality, compliance logic, or confirmatory holdouts.

## Development material

Only already-exposed development material is permitted:

- Pair2: profiles E and F;
- Pair3: profiles G and H;
- Istanbul; and
- London.

No new city, profile, seed, holdout, venue pool, or replacement may be introduced in this pass.

The exact frozen development location queries are:

| City | `filter.location.query` |
| --- | --- |
| Istanbul | `Istanbul` |
| London | `London` |

Every request sets `filter.location.radius=0`.

## Registered request shape

For each of the four profile-pair × city cases, run exactly three independent conditions:

1. first profile in the pair;
2. second profile in the pair; and
3. `UNSIGNALED_QLOO_BASELINE`, which omits `signal.interests.entities`.

Each condition independently requests the six frozen categories in the frozen QMBT-2R priority order with `take=18`:

1. `urn:tag:category:place:art_gallery`
2. `urn:tag:category:place:book_store`
3. `urn:tag:category:place:museum`
4. `urn:tag:category:place:park`
5. `urn:tag:category:place:restaurant`
6. `urn:tag:category:place:shopping_mall`

The registered pass therefore contains exactly:

`2 pairs × 2 cities × 3 conditions × 6 categories = 72 category requests`.

Every GET request uses only the following experiment parameters:

- `filter.type=urn:entity:place`;
- personalized conditions: `signal.interests.entities=<the three frozen profile seed entity IDs>`;
- baseline condition: omit `signal.interests.entities` entirely;
- `filter.tags=<one frozen category tag>`;
- `filter.location.query=<Istanbul or London exactly as frozen>`;
- `filter.location.radius=0`; and
- `take=18`.

Request parameter values and semantics must not change between attempts.

## Deterministic quota assembly

A completed condition is assembled only after all six category requests have completed successfully.

Traverse categories in the frozen order. Within each category, traverse entities in Qloo return order and select the first three entity IDs not already selected by an earlier category. Duplicate IDs are skipped. No affinity magnitude, LLM judgment, generated explanation, synthetic score, zero-imputation, intersection-only selection, substitution, or venue reordering may affect selection.

A condition passes the structural gate only when it produces exactly three selected entities in every category and exactly 18 unique entities overall.

All 12 conditions must pass for the registered result to be `DEVELOPMENT_K_FEASIBLE`.

A completed valid response with zero entities, fewer than 18 entities, duplicates, sparse coverage, weak-looking results, or an eventual quota shortfall is a completed retrieval outcome. It must not be retried because of its content. If deterministic assembly cannot fill all quotas, the registered result is `DEVELOPMENT_K_NOT_FEASIBLE`.

## Transport retry and stop policy

Use `EXACT_REQUEST_BOUNDED_RETRY_V1` exactly as frozen in `docs/QMBT_2R_PROTOCOL.md`:

- maximum three attempts per category request;
- retry only network/timeout, HTTP 408, HTTP 429, HTTP 5xx, or malformed/truncated 2xx lacking the required results/entity container;
- fallback waits of 2 seconds before attempt 2 and 8 seconds before attempt 3;
- honor valid `Retry-After` for HTTP 429 only when it is at most 120 seconds;
- non-408/429 HTTP 4xx and unhandled 3xx are nonretryable;
- accept the first parseable valid 2xx response and never resample it for content; and
- abort the entire registered pass as `INCOMPLETE_EXECUTION_API_OR_TRANSPORT` when a nonretryable outcome occurs or the retry budget is exhausted.

Previously completed successful category requests are not repeated within the same registered pass.

## Geography prohibitions

This pass must not use or introduce:

- Qloo locality UUIDs in `filter.location`;
- WKT point/polygon geography;
- latitude/longitude operational filters;
- geohash geography;
- `signal.location` or `signal.location.query`;
- alternate/fuzzy query text after observing output;
- city replacement;
- radius mutation;
- recommendation preflight;
- content-based retry; or
- post-output tuning followed by treatment as the same registered pass.

If `Istanbul` or `London` cannot complete under the frozen request and transport policy, stop. Do not repair the query inside this registered pass.

## Artifacts

A live authorized run writes only under:

`artifacts/qmbt-2r-direct-location-development/<timestamp>/`

Preserve:

- a copy of the frozen development manifest;
- raw HTTP response bodies by request/attempt;
- request metadata without authentication headers or API keys;
- attempt outcomes;
- returned entity IDs in Qloo order;
- duplicate skips and selected IDs per category; and
- a deterministic summary/result.

Never persist API credentials, authentication headers, or other secrets.

## Stop gate

This document, its manifest, the harness, and passing CI do **not** authorize a live Qloo request.

Before the first live development request, all of the following are required:

1. the exact harness/manifest commit is present on GitHub;
2. Repository Validation succeeds for that exact repository tree; and
3. the human operator grants a new explicit authorization for this development-only pass.

After one authorized pass completes or aborts, stop for human review. No automatic rerun, Seed Commit, holdout ranking, profile-seed resolution, confirmatory execution, UI work, or agent-loop expansion is authorized.