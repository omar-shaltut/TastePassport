# Judge Experience State Machine V1

Status: **FROZEN FOR IMPLEMENTATION VALIDATION**

This document translates the current TastePassport product and ranking decisions into an executable state machine. It does not change retrieval, ranking, or slot-selection policy.

## 1. Product invariant

TastePassport may automate the full run from user input to rendered recommendations, but automation does not transfer recommendation authority to the LLM.

Decision ownership is fixed:

1. **Qloo** supplies personalized venue retrieval.
2. **Deterministic application code** computes same-category intersections, `LEXIMIN_RANK_V1`, slot selection, and global entity deduplication.
3. **LLM** explains the already-selected immutable payload only.
4. **Deterministic validator** rejects LLM output that changes venue identity, order, ranks, category provenance, or unsupported claims.
5. **Frontend** renders the validated run state.

## 2. Frozen cross-category contract

### Slots

Display order is fixed:

1. `CULTURE`
2. `OUTDOORS`
3. `CITY_LIFE`

Category chains are fixed:

- `CULTURE`: `museum -> art_gallery -> book_store`
- `OUTDOORS`: `park`
- `CITY_LIFE`: `restaurant -> shopping_mall`

The chain is an editorial product policy. It is **not** a Qloo-derived cross-category ranking.

There is no global comparison of museum rank versus park rank versus restaurant rank.

### Within-category ordering

For an entity returned by Qloo for both profiles in the same city and same category:

```text
LEXIMIN_RANK_V1
1. max(rank_a, rank_b) ASC
2. rank_a + rank_b ASC
3. entity_id ASC
```

`rankGap` is intentionally absent because it is mathematically redundant after the first two keys.

### Global deduplication

An `entity_id` may appear on at most one final card.

Slots are assembled in display order. If a later slot's current winner has already been selected, the engine chooses the next eligible candidate inside the same category. If that category is exhausted, the engine continues through that slot's fixed category chain.

## 3. Truth contract

A `SHARED_PRIMARY` venue means:

> Qloo independently surfaced this venue for both profiles under the same city and same retrieval category, and deterministic reconciliation selected it.

It does **not** mean:

- the venue is unique to this pair;
- no other profile would receive it;
- it is the #1 overall venue across categories;
- either user is guaranteed to enjoy it.

Approved UI language should use concepts such as `Shared Qloo match`, `surfaced for both profiles`, and the two source ranks.

## 4. Run state machine

A run has exactly one top-level state.

```text
IDLE
  -> INPUT_READY
  -> RESOLVING_PROFILES
  -> RETRIEVING_QLOO
  -> RECONCILING
  -> ASSEMBLING_SLOTS
  -> EXPLAINING
  -> VALIDATING
  -> READY | PARTIAL_READY | FAILED
```

### `IDLE`

No runnable input exists.

Allowed transition:

- `SUBMIT_VALID_INPUT -> INPUT_READY`

### `INPUT_READY`

Required inputs are present and syntactically valid:

- Person A profile reference/signals
- Person B profile reference/signals
- destination city query

For the first judged demo, profile inputs may point to pre-resolved/frozen taste profiles. Free-form user-name-to-Qloo-seed resolution is not implied by this contract.

Allowed transition:

- `START_RUN -> RESOLVING_PROFILES`

### `RESOLVING_PROFILES`

The system resolves the exact Qloo seed IDs/signals that will be sent for each profile.

Success requirement:

- both profiles have non-empty validated Qloo signal sets.

Transitions:

- success -> `RETRIEVING_QLOO`
- failure -> `FAILED(PROFILE_RESOLUTION_FAILED)`

### `RETRIEVING_QLOO`

For each profile, execute the frozen direct-location Qloo retrieval for all six categories:

- `art_gallery`
- `book_store`
- `museum`
- `park`
- `restaurant`
- `shopping_mall`

The two users must use the same city and corresponding category query.

Store Qloo order exactly. The engine must not use the LLM to alter returned entities or ranks.

Transitions:

- all required retrievals complete -> `RECONCILING`
- unrecoverable request failure -> `FAILED(QLOO_RETRIEVAL_FAILED)` unless a slot can be proven independent of the missing evidence; v1 defaults to fail closed.

Important distinction:

`NO_SHARED_QLOO_EVIDENCE` means valid retrievals completed but their intersection was empty.

`EVIDENCE_UNAVAILABLE` means required retrieval evidence is missing or invalid.

These statuses must never be conflated.

### `RECONCILING`

For every category independently:

1. deduplicate each profile list by `entity_id`, preserving first Qloo occurrence;
2. compute same-category intersection by `entity_id`;
3. record `rank_a` and `rank_b` from the original Qloo order;
4. sort shared candidates by `LEXIMIN_RANK_V1`.

No cross-category arithmetic is permitted.

Transition:

- deterministic reconciliation complete -> `ASSEMBLING_SLOTS`

### `ASSEMBLING_SLOTS`

Build slots in this order:

1. `CULTURE`
2. `OUTDOORS`
3. `CITY_LIFE`

For each slot:

1. visit categories in the slot's frozen chain;
2. choose the first not-yet-used shared candidate from that category's reconciled ordering;
3. if no candidate remains, continue to the next category in the chain;
4. if the chain is exhausted, emit `NO_SHARED_QLOO_EVIDENCE`;
5. if required evidence for a category in the chain is unavailable such that its winner cannot be known, emit `EVIDENCE_UNAVAILABLE` rather than pretending the category was empty.

There is no LLM involvement.

Transition:

- immutable slot payload created -> `EXPLAINING`

### `EXPLAINING`

The LLM receives only the immutable selected-slot payload plus approved Qloo metadata required to explain it.

The LLM may produce:

- concise `why_it_works` copy;
- a short shared-taste summary grounded in the selected payload.

The LLM must not:

- add a venue;
- substitute a venue;
- reorder slots;
- alter ranks;
- claim cross-category overall ranking;
- claim pair exclusivity;
- convert `NO_SHARED_QLOO_EVIDENCE` into a recommendation.

Transition:

- explanation generated -> `VALIDATING`

### `VALIDATING`

A deterministic validator checks at minimum:

- every explained `entity_id` exists in the immutable selected payload;
- slot order is unchanged;
- venue names correspond to selected entity IDs;
- ranks equal the deterministic evidence payload;
- no extra venue appears;
- no forbidden overall-ranking or exclusivity claim is emitted;
- empty slots remain empty.

Transitions:

- all three slots have valid selected venues and explanation validates -> `READY`
- one or more slots are honestly empty but all available content validates -> `PARTIAL_READY`
- validator or upstream integrity failure -> `FAILED`

### `READY`

Three validated slot cards can be rendered.

This state means all three slots are filled; it does not mean three globally ranked recommendations exist.

### `PARTIAL_READY`

At least one slot has no shared evidence, while the run itself is valid.

The frontend renders available slots plus truthful empty-state cards.

This is a successful fail-closed product outcome, not a system failure.

### `FAILED`

The run cannot truthfully render a recommendation result due to missing/invalid execution evidence or validator failure.

The UI must display a retry/error state, not recommendations.

## 5. Judge-visible progress mapping

The processing screen may expose operational state, never private chain-of-thought.

| Internal state | Judge-visible step |
| --- | --- |
| `RESOLVING_PROFILES` | Understanding both taste profiles |
| `RETRIEVING_QLOO` | Searching the city through Qloo |
| `RECONCILING` | Finding shared Qloo matches |
| `ASSEMBLING_SLOTS` | Building Culture, Outdoor, and City Life picks |
| `EXPLAINING` | Explaining why the selected places work for both |
| `VALIDATING` | Verifying the final recommendations |

A checkmark may appear only after the corresponding state successfully completes.

## 6. Screen flow

### Screen 1 — Plan Together

Purpose: collect Person A, Person B, and destination.

Primary action: `Find our shared taste`.

### Screen 2 — Taste Signals

Purpose: show the exact resolved taste anchors/signals that will be sent to Qloo.

No additional semantic signals may be silently introduced after this screen.

Primary action: `Find our shared taste` / continue into automated execution.

### Screen 3 — Agent Working

Purpose: show real state-machine progress using the mapping in section 5.

No fake chain-of-thought or fabricated tool activity.

### Screen 4 — Shared Taste Summary

Purpose: provide a concise explanation of common ground grounded only in the immutable selected payload and approved metadata.

This screen must not claim uniqueness/exclusivity.

### Screen 5 — Shared Picks

Render fixed slots in order:

1. Culture Pick
2. Outdoor Pick
3. City Life Pick

Each selected card should expose:

- venue name;
- user-facing venue type from approved metadata, not blindly from retrieval category;
- destination/location metadata;
- `Shared Qloo match` evidence label;
- Person A source rank;
- Person B source rank;
- validated explanation.

Do not render `#1 overall`, `perfect match`, or equivalent unsupported claims.

## 7. Error and empty-state contract

Minimum machine-readable statuses:

- `SHARED_PRIMARY`
- `NO_SHARED_QLOO_EVIDENCE`
- `EVIDENCE_UNAVAILABLE`
- `PROFILE_RESOLUTION_FAILED`
- `QLOO_RETRIEVAL_FAILED`
- `EXPLANATION_VALIDATION_FAILED`

`NO_SHARED_QLOO_EVIDENCE` is slot-level and may lead to `PARTIAL_READY`.

Evidence/integrity failures lead to `FAILED` unless the affected evidence provably cannot change any rendered slot; v1 intentionally uses the stricter fail-closed interpretation.

## 8. Implementation gate

Before frontend/backend implementation is considered compliant with this document, automated tests must prove:

1. A/B swap leaves reconciled ordering unchanged.
2. `rankGap` is not part of the implementation.
3. No cross-category rank arithmetic exists.
4. Same entity cannot occupy two slots.
5. A later fallback category is used only after the earlier category has no eligible unused shared candidate.
6. Retrieval failure is not treated as empty intersection.
7. Empty shared evidence cannot trigger LLM venue creation.
8. LLM output cannot alter selected entity IDs or slot order.
9. `READY` requires three filled slots; honest shortfall produces `PARTIAL_READY`.
10. Judge-visible progress reflects completed state transitions only.

## 9. Explicitly unresolved and therefore not implemented in V1

- one-sided or cross-category fallback tiers;
- rank normalization for unequal result-list lengths;
- quality floors such as top-half thresholds;
- global ranking across categories;
- dynamic slot priorities;
- free-form arbitrary-user taste resolution unless separately validated;
- claims of pair-exclusive recommendations;
- confirmatory holdout tuning.

Any of these requires a new architecture decision and validation gate rather than a silent implementation change.
