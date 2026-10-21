# QMBT-2R — Retrieval-Native Quota-Matched Validation

Status: DRAFT / NOT YET PRE-REGISTERED

This successor protocol is for human review only. It authorizes no live Qloo
Lookup, Insights/recommendation retrieval, holdout inspection, experiment
execution, Seed Commit, or product architecture change. Passing static
validation does not pre-register the protocol or authorize live execution.

## Evidence and scope

- [QMBT-1](QMBT_1_PROTOCOL.md) stopped as
  [INVALID_EXECUTION_API_SEMANTICS](QMBT_1_INVALID_RUN_20261020.md).
- The separately registered [fixed-pool diagnostic](QLOO_FIXED_POOL_DIAGNOSTIC.md)
  [failed](QLOO_FIXED_POOL_DIAGNOSTIC_RESULT_20261020.md). Neither record is
  evidence for or against the product hypothesis; both remain unchanged.
- The V1 and V2 pre-Seed locality-ID resolution attempts are preserved as
  diagnostic history. V1 stopped on New York City with `LOCALITY_AMBIGUOUS`; V2
  resolved New York City and stopped on Tokyo with `LOCALITY_UNRESOLVED`.
- Fixed-pool rescoring is retired. No QMBT-1 harness or failed locality harness
  is repurposed or unlocked by this document.
- Pair2/Pair3 × Istanbul/London material is development/diagnostic only. The
  next confirmatory run requires a new holdout set. No new holdouts have been
  selected or inspected for this draft.

## Estimand and approved retrieval design

The estimand is **end-to-end profile-conditioned retrieval quality versus
unsignaled retrieval**, not common-pool reranking.

Each condition retrieves independently within the same six structural category
quotas. Qloo remains the venue-selection decision source and supplies the
within-category ordering. The baseline is `UNSIGNALED_QLOO_BASELINE`, omitting
`signal.interests.entities`; it must not be described as a popularity baseline.
Conditions need not return identical entity sets. There is no union-pool
rescoring, intersection-only selection, synthetic scoring, zero-imputation of
omitted entities, or LLM invention, substitution, or reordering of venues.

The final target remains 3 unique entities per category and 18 unique entities
per condition. The inherited category-ID priority for cross-category
deduplication, backfill, and final display is:

1. Art gallery — `urn:tag:category:place:art_gallery`
2. Book store — `urn:tag:category:place:book_store`
3. Museum — `urn:tag:category:place:museum`
4. Park — `urn:tag:category:place:park`
5. Restaurant — `urn:tag:category:place:restaurant`
6. Shopping mall — `urn:tag:category:place:shopping_mall`

An entity appears once per final list; later category blocks backfill in Qloo
return order after earlier blocks claim an entity. `retrieval_depth_K` is frozen
at `18` by human decision. Empirical feasibility of filling these quotas remains
an operational question. The frozen retry/stop policy below governs incomplete
recommendation API attempts only; it must never be used to resample a completed
valid response or improve a returned list. Restaurant retrieval remains
validation infrastructure, not a halal endorsement; production compliance
filtering remains mandatory and unchanged.

## Human decisions before pre-registration

| Decision | State |
| --- | --- |
| Holdout-selection procedure | `COMMIT_SEEDED_FROZEN_POOL_SELECTION_V1` — **FROZEN HUMAN DECISION** |
| City operationalization | `QMBT-2R-LOC-DIRECT-QUERY-V1` — **FROZEN HUMAN DECISION** |
| Seed Commit anti-grinding rule | `SINGLE_SHOT_REMOTE_SEED_COMMIT` — **FROZEN HUMAN DECISION** |
| Final holdout identities | `HUMAN_DECISION_REQUIRED` |
| Retrieval depth K | `18` — **FROZEN HUMAN DECISION** |
| Development-only method for validating K | `PRIOR_CASES_SINGLE_PASS_STRUCTURAL_QUOTA_FEASIBILITY` — **FROZEN HUMAN DECISION** |
| Live recommendation API retry/stop conditions | `EXACT_REQUEST_BOUNDED_RETRY_V1` — **FROZEN HUMAN DECISION** |

`QMBT-2R-LOC-DIRECT-QUERY-V1` supersedes the prior `QMBT-2R-LOC-v1`
locality-ID prerequisite. It does not reinterpret V1 or V2 as successful; those
failed executions remain diagnostic evidence.

`retrieval_depth_K = 18` is frozen before any new retrieval. It is derived
structurally, not tuned on taste quality. For category position `j` in the fixed
priority order, earlier categories can have assigned at most `3(j-1)` unique
entity IDs. To guarantee 3 current-category candidates remain after excluding
all earlier assignments, a response containing `K` distinct current-category
entity IDs must satisfy:

`K >= 3(j-1) + 3 = 3j`

With six categories, the worst case is `j = 6`, so `K >= 18`. QMBT-2R therefore
freezes the smallest worst-case structural depth: `K = 18`.

This is a combinatorial backfill bound, not an empirical claim about Qloo API
behavior. It applies only when a category retrieval returns at least 18 distinct
entity IDs. API acceptance of the requested depth and actual development quota
fill remain operational questions. Semantic quality, affinity magnitudes,
evaluator preference, or confirmatory holdout output must not be used to change
K.

The holdout-selection procedure, direct-query city operationalization, and
single-shot remote Seed Commit rule are frozen below, but the final holdout
identities are not chosen here. This draft authorizes no live retrieval. Any
eventual completion requires human review, a committed pre-registration, and
successful repository validation before a separately authorized confirmatory
run.

## Development-only validation method for K=18

Method identifier:
`PRIOR_CASES_SINGLE_PASS_STRUCTURAL_QUOTA_FEASIBILITY`.

Purpose: test whether the frozen retrieval design can structurally produce the
required quota-matched lists on development-only material. This gate must not
measure or optimize taste quality.

The development dataset is limited to the already-exposed
Pair2/Pair3 × Istanbul/London cases. For each of the four profile-pair × city
cases, run exactly three independent conditions: profile side A, profile side B,
and `UNSIGNALED_QLOO_BASELINE`. Each condition requests the six frozen categories
independently with `take = 18`. This is one registered structural pass:
4 cases × 3 conditions × 6 categories = 72 category retrieval requests.

A later direct-location development harness must use frozen direct location
queries for Istanbul and London under the same geography semantics as the
confirmatory design: `filter.location.query=<frozen development query>` and
`filter.location.radius=0`. The exact development query strings and request
construction must be committed and repository-validated before a separately
authorized live development pass. No live development request is authorized by
this protocol amendment.

For each completed category response, record at minimum:

- request condition, city, category ID, and requested `take`;
- API outcome/status and attempt count;
- returned entity count and distinct entity-ID count;
- returned entity IDs in Qloo order;
- cross-category duplicate skips;
- selected count for the category; and
- final unique entity count for the condition.

List construction is deterministic. Traverse the six frozen categories in the
frozen priority order. Within each category, traverse returned entities in Qloo
order and select the first three entity IDs not already selected by an earlier
category. Duplicate IDs are skipped. Do not use affinity magnitude, generated
explanations, LLM judgment, synthetic scores, zero-imputation, intersection-only
selection, substitution, or venue reordering.

A completed development condition satisfies the structural gate only if it
produces exactly 3 selected entities in every category and exactly 18 unique
entities overall. All 12 development conditions must satisfy that gate for the
structural result to be `DEVELOPMENT_K_FEASIBLE`.

A returned distinct-ID count below 18 is telemetry, not by itself a failure, if
the deterministic assembly still fills all six quotas. Conversely, a completed
valid response set that cannot fill a quota is structural evidence of
`DEVELOPMENT_K_NOT_FEASIBLE`; the request must not be retried because of its
content, and K must not be increased or retuned automatically.

Transport/API errors, rate limits, malformed or truncated responses, and other
incomplete attempts are handled only by the frozen
`EXACT_REQUEST_BOUNDED_RETRY_V1` policy below. They are not reclassified as K
failures.

No evaluator is run, no semantic or baseline advantage is scored, no affinity
comparison is used, and no new holdout is accessed. Exact repeatability across
multiple successful live passes is not a success criterion for this structural
gate. Any stability study, if later justified, must be registered separately
and cannot be used to retune K.

## Live API retry and stop policy

Policy identifier: `EXACT_REQUEST_BOUNDED_RETRY_V1`.

The purpose of retry is to recover from an incomplete recommendation API attempt,
never to resample a completed Qloo recommendation response. Every attempt and
outcome must be logged. A retry must preserve the same request semantics and all
experiment parameters, including profile signals, direct location query, radius,
category, filters, `take = 18`, and condition. No query mutation, parameter
mutation, geography fallback, fallback category, entity substitution, or
result-based retry is allowed.

A category request has at most three total attempts: the initial attempt plus
at most two retries. Retry is permitted only for:

- network connection failure or client timeout;
- HTTP `408`;
- HTTP `429`;
- HTTP `5xx`; or
- HTTP `2xx` whose body is truncated, cannot be parsed as JSON, or lacks the
  required result container needed to enumerate returned entities.

For retryable outcomes other than `429`, wait 2 seconds before attempt 2 and
8 seconds before attempt 3. For `429`, use a valid `Retry-After` value when it is
120 seconds or less; if the header is absent or invalid, use the same 2-second /
8-second fallback. A `Retry-After` value greater than 120 seconds aborts the
registered run rather than extending or modifying the protocol.

HTTP `4xx` responses other than `408` and `429` are non-retryable and abort the
registered run. A parseable `2xx` response with a valid result container is a
completed response even when it contains zero entities, fewer than 18 entities,
duplicate IDs, or no optional affinity value. Such a completed response must
never be retried because of its content.

The first completed valid response is accepted. Previously successful category
requests must not be repeated within the same registered run. If a retryable
request still has no completed valid response after three attempts, or any
non-retryable condition occurs, abort the entire registered run as
`INCOMPLETE_EXECUTION_API_OR_TRANSPORT`. Partial results must not be evaluated.

A new registered run after such an abort requires explicit human authorization.
It must use the same frozen protocol unless a separately reviewed protocol
amendment is committed first. Partial outputs from the aborted run must not be
used to change K, categories, direct location queries, holdouts, thresholds,
retry rules, or any other confirmatory choice.

Completed valid responses that fail quota assembly are retrieval outcomes, not
transport errors. In development they produce `DEVELOPMENT_K_NOT_FEASIBLE` under
the frozen structural gate. In confirmatory execution, the affected case is
`CONFIRMATORY_CASE_STRUCTURAL_FAIL`, receives no semantic/baseline positive
credit, and remains part of the four-case denominator. It must not be dropped,
replaced, or retried for a different result.

## Holdout selection procedure

Policy identifier: `COMMIT_SEEDED_FROZEN_POOL_SELECTION_V1`.

City operationalization amendment: `QMBT-2R-LOC-DIRECT-QUERY-V1`.

Seed anti-grinding rule: `SINGLE_SHOT_REMOTE_SEED_COMMIT`.

The purpose is to choose confirmatory holdouts without inspecting Qloo Insights
or recommendation outputs for candidate cities or profiles. The candidate pool
must be created and human-reviewed before any holdout-selection computation or
Qloo recommendation retrieval.

The candidate pool contains exactly:

- 8 city candidates, all different from the prior development cities Istanbul
  and London, each with an explicit researcher-committed `canonical_id`, country,
  city label, latitude, longitude, and frozen direct `filter.location.query`;
- 6 profile-pair candidates; each pair contains two profiles, and each profile
  contains exactly one movie, one brand, and one book seed; and
- no seed entity used in Pair2 or Pair3, no seed entity repeated anywhere in the
  candidate pool, and no profile intentionally centered on nightlife, alcohol,
  gambling, or another prohibited theme.

Latitude and longitude are immutable **audit metadata only**. They never define
the operational geographic filter for confirmatory QMBT-2R.

No pre-Seed Qloo locality-ID resolution is required. No Qloo locality UUID is
part of city eligibility, Seed Commit construction, ranking, or confirmatory
geography. The eight candidate city identities remain the already-reviewed
researcher-committed candidates; their operational direct-query strings are
frozen in `config/qmbt-2r/direct-location-queries-v1.json` before any new
holdout recommendation retrieval.

The frozen direct-query values are:

1. `city:us:new-york-city` — `New York City, United States of America`
2. `city:jp:tokyo` — `Tokyo, Japan`
3. `city:fr:paris` — `Paris, France`
4. `city:mx:mexico-city` — `Mexico City, Mexico`
5. `city:br:sao-paulo` — `São Paulo, Brazil`
6. `city:sg:singapore` — `Singapore, Singapore`
7. `city:au:sydney` — `Sydney, Australia`
8. `city:za:cape-town` — `Cape Town, South Africa`

These strings are not mutable during a registered run and may not be changed in
response to sparse, empty, weak, or unfavorable recommendation output. There is
no fallback to locality ID, WKT, latitude/longitude, geohash, `signal.location`,
alternative query text, or city replacement. A change to any frozen query is a
new reviewed protocol amendment, not a retry.

The Seed Commit contains the complete, human-reviewed candidate pool including
all eight frozen direct-location query values and the deterministic selector.
Before creating it, the separate Seed authorization must register the target
seed branch and exact parent commit SHA. The bytes to be committed must already
be reviewed before `git commit`.

`SINGLE_SHOT_REMOTE_SEED_COMMIT` means:

- create exactly one Seed Commit from those reviewed bytes and the registered
  parent;
- push that same commit object to the registered remote branch;
- do not generate, score, compare, or discard alternative candidate Seed
  Commits locally or remotely;
- if a push must be retried for transport reasons, retry the **same commit SHA**,
  never recreate the commit;
- the first GitHub-visible commit on the registered seed branch whose tree
  satisfies the frozen Seed schema is the Seed Commit;
- compute no holdout ranking until GitHub confirms that remote commit SHA; and
- never amend, rebase, squash, force-rewrite, or replace the Seed Commit.

If the registered parent/branch is no longer usable or the remote history is
ambiguous before ranking, stop for human review. Do not derive a new seed or
create another candidate Seed Commit automatically.

After GitHub confirms the Seed Commit, compute for every candidate:

`SHA256(seed_commit_sha | QMBT-2R | candidate_type | canonical_id)`

The separators are the literal ASCII ` | ` sequence shown above and the input is
UTF-8. Rank ascending by the lowercase hexadecimal SHA-256 digest, with
`canonical_id` ascending as the deterministic collision tiebreaker. Ranking uses
the researcher-committed `canonical_id` and is independent of Qloo geography
resolution or recommendation performance.

Select the first two ranked city candidates and the first two ranked profile-pair
candidates. Their cross-product defines exactly four confirmatory
profile-pair × city cases. No taste-quality, affinity, evaluator, quota-fill,
popularity, recommendation output, or prior locality-resolution performance may
influence this ranking or selection.

For profile seeds only, exact Qloo entity resolution occurs after provisional
profile-pair selection. Entity resolution is not a Qloo
Insights/recommendation preflight and must not retrieve venue recommendations.
If any of the six seeds in a provisional pair cannot be resolved unambiguously
to exactly one intended entity, reject the entire pair and advance to the next
profile pair in the already-frozen hash ranking. Do not substitute a single
seed, edit the pair, or inspect recommendation outputs to decide replacement.
Continue deterministically until two fully resolved pairs are obtained. If the
six-pair pool cannot supply two fully resolved pairs, stop for human review; do
not expand the pool post hoc.

For every confirmatory request, the selected city's operational geography is
only its frozen direct query:

- set `filter.location.query=<frozen direct query>`;
- set `filter.location.radius=0`;
- do not set `filter.location` to a locality UUID, WKT point, polygon, or other
  geography value;
- do not use latitude/longitude or geohash as the operational filter; and
- do not add `signal.location`.

These settings are identical across personalized and
`UNSIGNALED_QLOO_BASELINE` conditions. No recommendation preflight is allowed.
A later quota shortfall is handled by the frozen structural-failure rules; it
cannot justify changing a city, query, or radius.

If the frozen direct query produces a completed valid response that is empty,
sparse, or cannot fill quota, handle that result under the frozen structural
rules. Do not mutate the query or geography and do not retry for different
content. If the request cannot complete under the frozen transport policy,
classify the registered execution as `INCOMPLETE_EXECUTION_API_OR_TRANSPORT`.

After profile-seed resolution, commit the selected city identities and frozen
direct-query strings, selected profile pairs, all 12 resolved profile-seed
entity IDs, the Seed Commit SHA, ranking digests, and any whole-pair
deterministic skips. Only then may a later human review change protocol status
from `DRAFT / NOT YET PRE-REGISTERED` to a pre-registered state, after repository
validation passes.

From the first confirmatory retrieval onward, holdout cities, direct location
queries, selected profile pairs, seed identities, resolved entity IDs, K,
category framework, evaluator thresholds, and selection policy are immutable
for that registered experiment. No failed or weak confirmatory output may
trigger replacement or reselection.

## Static contract

This machine-readable contract records approved decisions and unresolved
fields only. It is not an executable retrieval configuration. Prose cannot
override it or the unchanged evaluator sections below. Altering a frozen
decision requires a separately reviewed protocol decision, not a validator
update to make a failing check pass.

```json
{
  "protocol": "QMBT-2R",
  "status": "DRAFT / NOT YET PRE-REGISTERED",
  "execution_allowed": false,
  "ci_live_qloo_allowed": false,
  "estimand": "END_TO_END_PROFILE_CONDITIONED_RETRIEVAL_VS_UNSIGNALED",
  "retrieval": "QUOTA_MATCHED_INDEPENDENT_RETRIEVAL",
  "recommendation_source": "QLOO",
  "fixed_pool_rescoring": false,
  "synthetic_scores": false,
  "zero_imputation": false,
  "intersection_only_selection": false,
  "llm_venue_reordering": false,
  "category_ids": ["art_gallery", "book_store", "museum", "park", "restaurant", "shopping_mall"],
  "quota_per_category": 3,
  "target_entities_per_condition": 18,
  "within_category_order": "QLOO_RETURN_ORDER",
  "baseline": "UNSIGNALED_QLOO_BASELINE",
  "baseline_signal_interests_entities": false,
  "evaluator_count": 4,
  "semantic_min_agreement": 3,
  "baseline_min_agreement": 3,
  "baseline_both_sides_required": true,
  "aggregate_min_positive_cases": 3,
  "aggregate_case_count": 4,
  "aggregate_both_cities_required": true,
  "aggregate_both_pairs_required": true,
  "blind_packet_entities": 18,
  "answer_key_hidden_until_all_responses": true,
  "requires_new_holdout_set": true,
  "prior_case_role": "DEVELOPMENT_DIAGNOSTIC_ONLY",
  "holdout_selection_policy": {
    "policy_id": "COMMIT_SEEDED_FROZEN_POOL_SELECTION_V1",
    "city_operationalization_policy": "QMBT-2R-LOC-DIRECT-QUERY-V1",
    "seed_commit_policy": "SINGLE_SHOT_REMOTE_SEED_COMMIT",
    "city_pool_size": 8,
    "profile_pair_pool_size": 6,
    "selected_city_count": 2,
    "selected_profile_pair_count": 2,
    "confirmatory_cross_product_case_count": 4,
    "exclude_prior_development_cities": true,
    "exclude_prior_seed_entities": true,
    "unique_seed_entities_across_pool": true,
    "prohibited_theme_exclusion_required": true,
    "city_coordinates_role": "AUDIT_METADATA_ONLY",
    "city_preseed_resolution_required": false,
    "city_direct_query_manifest": "config/qmbt-2r/direct-location-queries-v1.json",
    "city_direct_query_candidate_count": 8,
    "confirmatory_location_filter": "FROZEN_FILTER_LOCATION_QUERY",
    "confirmatory_filter_location_radius": 0,
    "confirmatory_filter_location_query_required": true,
    "confirmatory_locality_id_filter_allowed": false,
    "confirmatory_wkt_filter_allowed": false,
    "confirmatory_geohash_filter_allowed": false,
    "confirmatory_signal_location_allowed": false,
    "confirmatory_coordinate_filter_allowed": false,
    "query_mutation_during_registered_run_allowed": false,
    "content_based_location_retry_allowed": false,
    "post_seed_city_replacement_allowed": false,
    "seed_parent_and_branch_registered_before_commit": true,
    "seed_commit_first_remote_schema_match": true,
    "seed_alternative_commit_generation_allowed": false,
    "ranking_before_remote_seed_confirmation_allowed": false,
    "seed_push_retry_requires_same_commit_sha": true,
    "seed_commit_history_rewrite_allowed": false,
    "ranking_hash": "SHA256(seed_commit_sha | QMBT-2R | candidate_type | canonical_id)",
    "rank_ascending": true,
    "canonical_id_collision_tiebreak_ascending": true,
    "profile_seed_entity_resolution_after_selection_only": true,
    "qloo_recommendation_preflight_allowed": false,
    "unresolved_seed_rejects_entire_pair": true,
    "single_seed_substitution_allowed": false,
    "advance_by_frozen_pair_rank": true,
    "pool_expansion_after_resolution_failure_allowed": false,
    "final_holdouts_require_post_resolution_commit": true,
    "post_first_confirmatory_reselection_allowed": false
  },
  "live_api_policy": {
    "policy_id": "EXACT_REQUEST_BOUNDED_RETRY_V1",
    "max_attempts_per_request": 3,
    "retryable_outcomes": ["NETWORK_OR_TIMEOUT", "HTTP_408", "HTTP_429", "HTTP_5XX", "MALFORMED_OR_TRUNCATED_2XX"],
    "fallback_backoff_seconds": [2, 8],
    "retry_after_max_seconds": 120,
    "nonretryable_http_4xx_except": [408, 429],
    "retry_payload_mutation_allowed": false,
    "accept_first_valid_response": true,
    "retry_completed_valid_response": false,
    "abort_entire_run_on_nonretryable_or_exhausted": true,
    "partial_results_evaluable": false,
    "fresh_run_requires_human_authorization": true,
    "completed_quota_shortfall_retryable": false,
    "development_quota_shortfall_classification": "DEVELOPMENT_K_NOT_FEASIBLE",
    "confirmatory_quota_shortfall_classification": "CONFIRMATORY_CASE_STRUCTURAL_FAIL",
    "exhausted_or_nonretryable_classification": "INCOMPLETE_EXECUTION_API_OR_TRANSPORT"
  },
  "human_decisions": {
    "holdout_selection_procedure": "COMMIT_SEEDED_FROZEN_POOL_SELECTION_V1",
    "city_operationalization": "QMBT-2R-LOC-DIRECT-QUERY-V1",
    "seed_commit_anti_grinding_rule": "SINGLE_SHOT_REMOTE_SEED_COMMIT",
    "final_holdout_identities": "HUMAN_DECISION_REQUIRED",
    "retrieval_depth_K": 18,
    "depth_development_validation_method": "PRIOR_CASES_SINGLE_PASS_STRUCTURAL_QUOTA_FEASIBILITY",
    "live_api_stop_conditions": "EXACT_REQUEST_BOUNDED_RETRY_V1"
  }
}
```

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

## Validation and review gate

The three evaluation sections above are inherited verbatim from QMBT-1. Blind
packets retain all 18 entities, without Top-10 truncation; answer keys remain
hidden until all evaluator responses have been collected. Numerical ranking
or affinity differences alone do not establish success. These are operational
criteria, not statistical-significance claims.

Run the following from the repository root, entirely offline:

```powershell
./scripts/validation/Test-Qmbt2rProtocol.ps1
./scripts/validation/Test-Qmbt2rProtocol.Tests.ps1
./scripts/validation/Test-Qmbt2rDirectLocation.ps1
./scripts/validation/Test-Qmbt2rDirectLocation.Tests.ps1
```

Repository CI retains its existing PowerShell syntax and QMBT-1 safety checks
and runs these checks. The validators pin historical evidence, the unchanged
evaluator sections, the frozen K/retry/Seed rules, and the direct-location
contract. They scan repository workflows for direct live-Qloo indicators.
Static checks cannot establish API feasibility or empirically validate the
hypothesis.

Stop at PR review. Live development requests, Seed Commit creation, final
holdout selection, live recommendation calls, confirmatory execution, UI,
agent-loop expansion, policy changes, and merging are outside this draft task.