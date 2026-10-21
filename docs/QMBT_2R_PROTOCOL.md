# QMBT-2R — Retrieval-Native Quota-Matched Validation

Status: DRAFT / NOT YET PRE-REGISTERED

This successor skeleton is for human review only. It authorizes no live Qloo
Lookup, Insights/recommendation retrieval, holdout inspection, experiment
execution, or product architecture change. Passing static validation does not
pre-register the protocol.

## Evidence and scope

- [QMBT-1](QMBT_1_PROTOCOL.md) stopped as
  [INVALID_EXECUTION_API_SEMANTICS](QMBT_1_INVALID_RUN_20261020.md).
- The separately registered [fixed-pool diagnostic](QLOO_FIXED_POOL_DIAGNOSTIC.md)
  [failed](QLOO_FIXED_POOL_DIAGNOSTIC_RESULT_20261020.md). Neither record is
  evidence for or against the product hypothesis; both remain unchanged.
- Fixed-pool rescoring is retired. No current QMBT-1 harness is repurposed or
  unlocked by this document.
- Pair2/Pair3 × Istanbul/London material is development/diagnostic only.
  The next confirmatory run requires a new holdout set. No new holdouts have
  been selected or inspected for this draft.

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
| City operationalization | `QMBT-2R-LOC-v1` — **FROZEN HUMAN DECISION** |
| Seed Commit anti-grinding rule | `SINGLE_SHOT_REMOTE_SEED_COMMIT` — **FROZEN HUMAN DECISION** |
| Final holdout identities | `HUMAN_DECISION_REQUIRED` |
| Retrieval depth K | `18` — **FROZEN HUMAN DECISION** |
| Development-only method for validating K | `PRIOR_CASES_SINGLE_PASS_STRUCTURAL_QUOTA_FEASIBILITY` — **FROZEN HUMAN DECISION** |
| Live recommendation API retry/stop conditions | `EXACT_REQUEST_BOUNDED_RETRY_V1` — **FROZEN HUMAN DECISION** |

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

The holdout-selection procedure, Qloo-locality city operationalization, and
single-shot remote Seed Commit rule are frozen below, but the candidate pool and
final holdout identities are not chosen here. The required pre-Seed locality
Lookup is also **not authorized by this draft**; it requires a separate reviewed
execution authorization before any live Qloo request. Building, technically
resolving, and committing the pool remains a human review gate because the Seed
Commit irreversibly determines the deterministic ranking. The development-only
validation method and live recommendation retry/stop policy are also frozen, but
this draft still authorizes no live retrieval. Any eventual completion requires
human review, a committed pre-registration, and successful repository validation
before a separately authorized confirmatory run.

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
experiment parameters, including profile signals, city, category, filters,
`take = 18`, and condition. No parameter mutation, fallback category, entity
substitution, or result-based retry is allowed.

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
used to change K, categories, holdouts, thresholds, retry rules, or any other
confirmatory choice.

Completed valid responses that fail quota assembly are retrieval outcomes, not
transport errors. In development they produce `DEVELOPMENT_K_NOT_FEASIBLE` under
the frozen structural gate. In confirmatory execution, the affected case is
`CONFIRMATORY_CASE_STRUCTURAL_FAIL`, receives no semantic/baseline positive
credit, and remains part of the four-case denominator. It must not be dropped,
replaced, or retried for a different result.

This retry policy applies to recommendation retrieval. The pre-Seed locality
Lookup described below cannot be executed until a separate authorization freezes
its exact request and transport-retry handling; no content-based retry or query
mutation may be introduced there.

## Holdout selection procedure

Policy identifier: `COMMIT_SEEDED_FROZEN_POOL_SELECTION_V1`.

City operationalization amendment: `QMBT-2R-LOC-v1`.

Seed anti-grinding rule: `SINGLE_SHOT_REMOTE_SEED_COMMIT`.

The purpose is to choose confirmatory holdouts without inspecting Qloo Insights
or recommendation outputs for candidate cities or profiles. The candidate pool
must be created and human-reviewed before any holdout-selection computation or
Qloo recommendation retrieval.

The candidate pool contains exactly:

- 8 city candidates, all different from the prior development cities Istanbul
  and London, each with an explicit researcher-committed `canonical_id`, country,
  city label, latitude, and longitude;
- 6 profile-pair candidates; each pair contains two profiles, and each profile
  contains exactly one movie, one brand, and one book seed; and
- no seed entity used in Pair2 or Pair3, no seed entity repeated anywhere in the
  candidate pool, and no profile intentionally centered on nightlife, alcohol,
  gambling, or another prohibited theme.

Latitude and longitude are immutable **audit metadata only**. They never define
the operational geographic filter for confirmatory QMBT-2R.

Before a Seed Commit may exist, all eight city candidates must complete one
registered technical locality-resolution pass using only the Qloo Lookup /
Entity Search capability. No Qloo Insights/recommendation call is permitted.
Eligibility may use only identity fields needed to establish the intended
locality: Qloo entity ID, name, entity type, and country. Recommendation counts,
affinity, popularity, rank, venue content, quota fill, or any other performance
signal must not be inspected or used.

A city is technically eligible only when the registered Lookup procedure
unambiguously resolves it to exactly one intended `urn:entity:locality`
consistent with the committed city label and country. The resolved Qloo locality
ID is then frozen into the candidate pool before the Seed Commit. If any of the
eight candidates is unresolved, ambiguous, has the wrong type/country, or cannot
complete the registered identity check, **stop for human review and do not create
a Seed Commit**. There is no automatic replacement, fallback coordinate, fuzzy
confirmatory query, or content-based retry. Any reviewed candidate-pool revision
must undergo a new complete pre-Seed locality-resolution pass before it can be
committed.

The pre-Seed locality pass is an identity-validation step only. This protocol
freezes its methodology but does not authorize the live requests. A separate
authorization must freeze the exact Lookup request construction and
transport-only retry handling before the first Qloo Lookup call.

The Seed Commit contains the complete, human-reviewed candidate pool including
all eight frozen Qloo locality IDs and the deterministic selector. Before
creating it, the separate Seed authorization must register the target seed
branch and exact parent commit SHA. The bytes to be committed must already be
reviewed before `git commit`.

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
the researcher-committed `canonical_id`, not the Qloo locality ID.

Select the first two ranked city candidates and the first two ranked profile-pair
candidates. Their cross-product defines exactly four confirmatory
profile-pair × city cases. No taste-quality, affinity, evaluator, quota-fill,
popularity, recommendation output, or locality-resolution performance may
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
only its frozen Qloo locality ID:

- set `filter.location=<frozen qloo locality id>`;
- set `filter.location.radius=0`;
- do not use `filter.location.query`;
- do not use latitude/longitude as the operational filter; and
- do not add `signal.location`.

These settings are identical across personalized and
`UNSIGNALED_QLOO_BASELINE` conditions. No recommendation preflight is allowed.
A later quota shortfall is handled by the frozen structural-failure rules; it
cannot justify changing a city, locality ID, or radius.

If a selected frozen locality ID becomes unusable after the Seed Commit or
pre-registration, abort the affected registered execution as
`INCOMPLETE_EXECUTION_API_OR_TRANSPORT`. Do not replace the city, advance to the
next ranked city, fall back to coordinates, use `filter.location.query`, or
change `filter.location.radius`.

After profile-seed resolution, commit the selected city identities and frozen
locality IDs, selected profile pairs, all 12 resolved profile-seed entity IDs,
the Seed Commit SHA, ranking digests, and any whole-pair deterministic skips.
Only then may a later human review change protocol status from
`DRAFT / NOT YET PRE-REGISTERED` to a pre-registered state, after repository
validation passes.

From the first confirmatory retrieval onward, holdout cities, locality IDs,
selected profile pairs, seed identities, resolved entity IDs, K, category
framework, evaluator thresholds, and selection policy are immutable for that
registered experiment. No failed or weak confirmatory output may trigger
replacement or reselection.

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
    "city_operationalization_policy": "QMBT-2R-LOC-v1",
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
    "city_preseed_resolution_required": true,
    "city_preseed_resolution_scope": "ALL_8_CANDIDATES",
    "city_resolution_api": "QLOO_LOOKUP_ENTITY_SEARCH_ONLY",
    "city_resolution_requires_single_locality": true,
    "city_resolution_allowed_identity_fields": ["id", "name", "type", "country"],
    "city_resolution_failure_action": "STOP_FOR_HUMAN_REVIEW_NO_SEED_COMMIT",
    "qloo_insights_for_city_resolution_allowed": false,
    "qloo_insights_for_pool_construction_allowed": false,
    "locality_ids_committed_before_seed": true,
    "confirmatory_location_filter": "FROZEN_QLOO_LOCALITY_ID",
    "confirmatory_filter_location_radius": 0,
    "confirmatory_filter_location_query_allowed": false,
    "confirmatory_signal_location_allowed": false,
    "confirmatory_coordinate_filter_allowed": false,
    "post_seed_city_replacement_allowed": false,
    "post_seed_locality_unusable_classification": "INCOMPLETE_EXECUTION_API_OR_TRANSPORT",
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
    "city_operationalization": "QMBT-2R-LOC-v1",
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
```

Repository CI retains its existing PowerShell syntax and QMBT-1 safety checks
and runs these new checks. The static validator pins the historical evidence
records and scans repository workflows for direct live-Qloo indicators such as
the hackathon API host, `QLOO_API_KEY`, or execution/reference of the Qloo spike
scripts. It intentionally does not freeze the number or complete contents of
unrelated workflows, so safe CI evolution remains possible. The Qloo evidence
audit may access public GitHub-hosted Qloo documentation, but it does not call
the Qloo API or use Qloo secrets. The checks validate the contract, frozen
evaluator text, evidence preservation, and absence of direct live-Qloo CI
execution indicators; they cannot establish API feasibility or empirically
validate the hypothesis. The approved scope, retrieval-design prose, frozen
K decision, development-only validation method, live recommendation retry/stop
policy, locality operationalization, single-shot Seed Commit rule,
holdout-selection policy, and remaining unresolved final holdout identities are
pinned too, so prose-only changes cannot bypass the static contract.

Stop at PR review. Live locality Lookup, Seed Commit creation, final holdout
selection, live recommendation calls, execution harnesses, UI, agent-loop
expansion, policy changes, and merging are outside this draft task.
