# QMBT-2R — Pre-Seed Locality Resolution Authorization

Status: FROZEN / LIVE LOOKUP AUTHORIZED AFTER REPOSITORY VALIDATION

Issue: #4

This record freezes and authorizes exactly one pre-Seed technical locality-resolution pass for the eight already-reviewed city candidates required by `QMBT-2R-LOC-v1`. It does **not** authorize Qloo Insights/recommendation retrieval, profile-seed resolution, Seed Commit creation, holdout ranking, final holdout selection, or confirmatory execution.

## Evidence basis

- Qloo's public Search reference documents `query`, `types`, `page`, `take`, and `sort_by`; `take` permits values through 100.
- The repository's prior working search spike uses `GET https://hackathon.api.qloo.com/search?query=...` with `X-Api-Key` authentication.
- Qloo's public locality documentation identifies `urn:entity:locality` as the named-locality type and documents locality IDs as valid operational geography for later Insights filtering.

This pass uses the Search endpoint only. It is an identity-validation operation, not recommendation preflight.

## Frozen candidates

The pass consumes `config/qmbt-2r/preseed-localities.json` exactly. There are eight candidates and no replacements are permitted during this registered pass. Coordinates are audit metadata only and are never sent to Qloo by this harness.

## Exact request construction

For each candidate, in manifest order, construct exactly:

`GET https://hackathon.api.qloo.com/search?query=<urlencoded lookup_query>&types=urn%3Aentity%3Alocality&page=1&take=100&sort_by=match`

with request headers:

- `Accept: application/json`
- `X-Api-Key: <value read only from process environment variable QLOO_API_KEY>`

No request may add location coordinates, radius, popularity filters, recommendation signals, or another endpoint. Query text is the committed `lookup_query`; it cannot be edited during execution.

## Identity-only eligibility rule

Only these response fields may affect eligibility:

- `entity_id`;
- `name`;
- locality type from `types` and/or `subtype`;
- identity-country text from `disambiguation` or `properties.disambiguation`.

Popularity, rank, score, affinity, recommendation order, venue content, tags, and quota information must not be inspected or used by the classifier.

Text comparison uses deterministic normalization: Unicode decomposition, removal of non-spacing marks, lowercase invariant conversion, replacement of non-alphanumeric runs with one ASCII space, and trimming.

A returned row qualifies only when all of the following hold:

1. `entity_id` is present;
2. its type includes exactly `urn:entity:locality` through `types` or `subtype`;
3. normalized `name` equals one of the candidate's preregistered normalized `accepted_names`; and
4. normalized disambiguation contains one of the candidate's preregistered country aliases as a whole normalized phrase.

Duplicate rows with the same `entity_id` collapse to one ID. Search-result order is ignored.

Classification is deterministic:

- exactly one unique qualifying ID => `LOCALITY_RESOLVED`;
- zero qualifying IDs => `LOCALITY_UNRESOLVED`;
- more than one unique qualifying ID => `LOCALITY_AMBIGUOUS`.

Missing identity fields never trigger guessing or manual selection.

## Lookup retry/stop policy

Policy identifier: `PRESEED_LOCALITY_EXACT_REQUEST_BOUNDED_RETRY_V1`.

Each city request has at most three total attempts: initial attempt plus at most two retries. Every retry must use the identical URI and semantic headers.

Retry is permitted only for:

- network connection failure or client timeout;
- HTTP `408`;
- HTTP `429`;
- HTTP `5xx`; or
- HTTP `2xx` whose body cannot be parsed as JSON or lacks the required `results` container.

For retryable outcomes other than `429`, wait 2 seconds before attempt 2 and 8 seconds before attempt 3. For `429`, honor a valid `Retry-After` value of at most 120 seconds; absent/invalid values use the 2/8 second fallback. A valid `Retry-After` above 120 seconds aborts the pass.

HTTP `404` is a completed no-results content outcome and becomes `LOCALITY_UNRESOLVED`; it is never retried. Other HTTP `4xx` and all unhandled `3xx` responses abort the pass. A parseable `2xx` with a `results` container is completed content and is never retried because it is empty, ambiguous, or otherwise unfavorable.

If a retryable request has no completed response after three attempts, or a nonretryable transport/API condition occurs, abort as `PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT`.

If any candidate classifies as `LOCALITY_UNRESOLVED` or `LOCALITY_AMBIGUOUS`, stop the whole registered pass immediately. Do not replace the city, edit aliases, change the query, add coordinates, switch endpoints, inspect Insights, or continue toward a Seed Commit.

## Artifacts

Manual execution writes a timestamped directory under `artifacts/qmbt-2r-preseed-locality/` containing:

- raw response bodies for audit;
- a deterministic redacted summary containing only candidate identity, attempts/status, resolved identity fields, and classifications; and
- the frozen manifest copy used by the run.

Request headers and API keys must never be written to artifacts or logs. Raw responses are audit evidence; non-identity fields inside them are not eligibility inputs.

## Execution authorization and stop gate

Repository CI must validate this protocol, manifest, and harness offline. CI must never invoke the live harness.

After those checks pass, one deliberate manual invocation of the frozen harness is **LIVE LOOKUP AUTHORIZED** for exactly these eight city candidates. No other Qloo live operation is authorized by this record.

After the pass completes, stop for human review. Even if all eight cities resolve, do **not** create the Seed Commit or compute holdout ranking until the locality results are explicitly accepted.

## Static contract

```json
{
  "protocol": "QMBT-2R-PRESEED-LOCALITY",
  "status": "FROZEN_LIVE_LOOKUP_AUTHORIZED_AFTER_REPOSITORY_VALIDATION",
  "parent_protocol": "QMBT-2R-LOC-v1",
  "issue": 4,
  "candidate_count": 8,
  "endpoint": "https://hackathon.api.qloo.com/search",
  "http_method": "GET",
  "query_source": "COMMITTED_LOOKUP_QUERY",
  "types": "urn:entity:locality",
  "page": 1,
  "take": 100,
  "sort_by": "match",
  "coordinates_operational": false,
  "insights_allowed": false,
  "recommendation_preflight_allowed": false,
  "profile_seed_resolution_allowed": false,
  "seed_commit_creation_allowed": false,
  "ranking_allowed": false,
  "identity_fields_only": true,
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
  "manual_live_execution_allowed_after_ci": true,
  "post_pass_human_review_required": true
}
```
