# QMBT-2R — Pre-Seed Locality Resolution V2

Status: FROZEN DESIGN / LIVE LOOKUP REQUIRES REPOSITORY VALIDATION + EXPLICIT HUMAN AUTHORIZATION

Issue: #6

V2 is an additive successor to the V1 pre-Seed locality pass. V1 is preserved unchanged as audit history. Its authorized live execution reached Qloo Search successfully and stopped on the first candidate, `city:us:new-york-city`, with `LOCALITY_AMBIGUOUS` because the V1 rule could not distinguish a city-level locality from a broader same-name locality.

V2 does not choose either V1-observed entity ID and does not whitelist any entity ID. It changes only the preregistered identity rule and lookup text used for a future Search-only pass.

## Evidence basis

- Qloo's public Entity Search reference documents `query`, `types`, `page`, `take`, and `sort_by`; Search supports `take=100` and `sort_by=match`.
- Qloo's public API overview identifies Entity Search as a lookup API used to discover and validate entity IDs.
- The Search reference does not document a city-vs-region response field or guarantee a winner when same-name localities are returned.
- `QMBT-2R-LOC-v1` requires all eight city candidates to resolve before the Seed Commit using Qloo Lookup/Entity Search only; coordinates remain audit metadata and are not operational geography.

The V2 response classifier therefore uses only preregistered identity text and locality type. It does not use Search order or recommendation behavior.

## Frozen candidates and administrative identity

V2 consumes `config/qmbt-2r/preseed-localities-v2.json` exactly. The candidate set remains the same eight cities and the researcher coordinates are unchanged.

For each non-city-state candidate, the manifest preregisters:

- accepted locality-name aliases;
- a first-level administrative-area label and aliases (`admin1`);
- country aliases; and
- an exact lookup query containing city + admin1 + country.

The preregistered admin1 labels are:

1. New York City → New York
2. Tokyo → Tokyo
3. Paris → Île-de-France
4. Mexico City → Mexico City
5. São Paulo → São Paulo
6. Singapore → sovereign city-state exception
7. Sydney → New South Wales
8. Cape Town → Western Cape

Singapore is handled by a frozen sovereign-city-state rule rather than inventing an admin1 level.

No V1-observed Qloo ID appears in the V2 manifest, protocol contract, or classifier fixtures.

## Exact request

For each candidate in manifest order:

`GET https://hackathon.api.qloo.com/search?query=<urlencoded lookup_query>&types=urn%3Aentity%3Alocality&page=1&take=100&sort_by=match`

Headers:

- `Accept: application/json`
- `X-Api-Key: <process environment QLOO_API_KEY>`

No request may add coordinates, radius, location filters, recommendation signals, another endpoint, or a mutated query.

## Deterministic normalization

Identity strings are normalized per segment:

1. Unicode FormD decomposition;
2. remove `NonSpacingMark` characters;
3. normalize back to FormC;
4. lowercase invariant;
5. replace non-`[a-z0-9]` runs with one ASCII space;
6. trim.

`disambiguation` is split on literal commas **before** normalization. Empty normalized segments are discarded.

## ADMIN1_SEGMENT_IDENTITY_V2

Only these response fields may affect eligibility:

- `entity_id`;
- `name`;
- locality type from `types` and/or `subtype`;
- `disambiguation` or `properties.disambiguation`.

A row qualifies only if all applicable conditions hold:

1. `entity_id` is present.
2. Locality type includes exact `urn:entity:locality`.
3. Normalized row `name` equals a preregistered accepted name.
4. Disambiguation has at least two normalized comma-delimited segments.
5. First disambiguation segment equals a preregistered accepted name.
6. Final disambiguation segment equals a preregistered country alias.
7. For a non-city-state candidate:
   - disambiguation has at least three segments; and
   - at least one interior segment exactly equals a preregistered `admin1_alias`.
8. For the Singapore sovereign-city-state candidate:
   - disambiguation must contain exactly two segments (locality, country);
   - first segment must match the accepted name and final segment the country alias.

The classifier does not select the most specific-looking row, longest path, first result, highest-ranked result, or any other heuristic. If multiple distinct IDs satisfy the frozen identity path, the result remains ambiguous.

Rows with the same `entity_id` collapse.

Classification:

- exactly one unique qualifying ID → `LOCALITY_RESOLVED`;
- zero → `LOCALITY_UNRESOLVED`;
- more than one → `LOCALITY_AMBIGUOUS`.

## Retry and stop policy

Transport behavior reuses `PRESEED_LOCALITY_EXACT_REQUEST_BOUNDED_RETRY_V1`:

- maximum 3 total attempts per city;
- retry only network/timeout, 408, 429, 5xx, or malformed/truncated/missing-results-container 2xx;
- fallback backoff 2s then 8s;
- honor valid `Retry-After <= 120s`; abort above 120s;
- 404 is completed `LOCALITY_UNRESOLVED`, no retry;
- other 4xx and unhandled 3xx abort;
- parseable 2xx content is never retried because the identity outcome is unfavorable.

Stop the entire V2 pass on the first unresolved, ambiguous, or API/transport failure. Do not alter names, admin aliases, query text, city candidates, coordinates, endpoint, or classifier during the pass.

## Artifacts

A future authorized manual execution writes under:

`artifacts/qmbt-2r-preseed-locality-v2/<timestamp>/`

with:

- raw response bodies;
- the exact V2 manifest copy;
- deterministic `summary.json` containing request URI, attempt statuses, classifier ID, and identity outcome.

Secrets and request headers are never persisted.

## Validation and authorization gate

CI is offline. It validates syntax, the exact V2 contract/manifest, the pure classifier/URI unit tests, mutation rejection, and that workflows do not invoke the live harness or reference `QLOO_API_KEY`.

Passing CI does **not** itself authorize a live V2 lookup. After CI succeeds for the exact commit, a new explicit human authorization is required before one deliberate manual V2 invocation.

No Seed Commit, holdout ranking, profile-seed resolution, Insights retrieval, recommendation retrieval, or confirmatory execution is authorized by V2.

Even if all eight cities resolve, stop for explicit human review before any Seed Commit or ranking.

## Static contract

```json
{
  "protocol": "QMBT-2R-PRESEED-LOCALITY-V2",
  "status": "FROZEN_DESIGN_LIVE_REQUIRES_CI_AND_EXPLICIT_HUMAN_AUTHORIZATION",
  "parent_protocol": "QMBT-2R-LOC-v1",
  "predecessor": "QMBT-2R-PRESEED-LOCALITY",
  "issue": 6,
  "candidate_count": 8,
  "endpoint": "https://hackathon.api.qloo.com/search",
  "http_method": "GET",
  "query_source": "COMMITTED_CITY_ADMIN1_COUNTRY_LOOKUP_QUERY",
  "types": "urn:entity:locality",
  "page": 1,
  "take": 100,
  "sort_by": "match",
  "classifier": "ADMIN1_SEGMENT_IDENTITY_V2",
  "disambiguation_split_before_normalization": true,
  "admin1_required_for_non_city_state": true,
  "city_state_exact_two_segment_rule": true,
  "observed_entity_id_allowlist_allowed": false,
  "coordinates_operational": false,
  "insights_allowed": false,
  "recommendation_preflight_allowed": false,
  "profile_seed_resolution_allowed": false,
  "seed_commit_creation_allowed": false,
  "ranking_allowed": false,
  "result_order_selects_winner": false,
  "retry_policy": "PRESEED_LOCALITY_EXACT_REQUEST_BOUNDED_RETRY_V1",
  "max_attempts": 3,
  "fallback_backoff_seconds": [2, 8],
  "retry_after_max_seconds": 120,
  "http_404_is_unresolved_no_retry": true,
  "completed_content_retry_allowed": false,
  "stop_on_first_identity_failure": true,
  "automatic_city_replacement_allowed": false,
  "ci_live_execution_allowed": false,
  "ci_success_auto_authorizes_live": false,
  "explicit_human_live_authorization_required": true,
  "post_pass_human_review_required": true
}
```
