# Adapter Boundary V1

Status: **IMPLEMENTATION VALIDATION**

This boundary separates the frozen Judge Experience selection engine from external data and explanation providers. It does not change `LEXIMIN_RANK_V1`, `CROSS_CATEGORY_SLOT_CONTRACT_V1`, Qloo authority, or the truth contract.

## Interfaces

### `ProfileResolverAdapter`

Input:

- side (`A` or `B`)
- frozen/profile reference

Output:

- one `ResolvedProfile` with non-empty Qloo seed entity IDs

The orchestrator rejects a returned side/profile reference that does not match the request.

### `RetrievalSourceAdapter`

Input:

- side
- one of the six frozen categories
- destination city
- resolved profile evidence

Output:

- one `RetrievalResult`

The orchestrator owns the request matrix: exactly A/B x the six frozen categories. The adapter does not choose categories, slots, reconciliation policy, or final venues. Returned side/category/city provenance must match the request. Adapter exceptions or provenance mismatches become `EVIDENCE_UNAVAILABLE` and remain fail-closed where that evidence can affect a rendered slot.

### `ExplanationSourceAdapter`

Input:

- run ID
- destination city
- already assembled immutable slots

It does **not** receive raw retrieval pools or unresolved candidates through this interface.

Output:

- `ExplanationPayload`

The existing deterministic validator remains authoritative. An explanation adapter cannot add, substitute, reorder, or rerank venues, alter source ranks, fill empty slots, or emit forbidden truth-contract claims.

## Fixture implementation

`FixtureAdapter` implements all three interfaces using committed local fixture data only. It contains no HTTP client, Qloo endpoint, credential handling, or LLM provider call.

The fixture runner now executes through this adapter boundary, so the CI smoke test exercises the same seam intended for future integrations.

## Orchestration

`executeWithAdapters` performs:

1. resolve A and B profiles through `ProfileResolverAdapter`;
2. request the fixed 12 retrievals through `RetrievalSourceAdapter`;
3. run the existing deterministic reconciliation and slot assembly;
4. pass only immutable slots to `ExplanationSourceAdapter`;
5. invoke the existing canonical fixture/state-machine execution and deterministic explanation validator.

Selection policy remains in the engine, not in adapters.

## Explicitly not implemented

- no `QlooAdapter`;
- no live network calls;
- no secrets;
- no LLM provider adapter;
- no frontend adapter;
- no retry policy changes;
- no category or slot changes;
- no holdout execution.

A live Qloo adapter requires a separate authorization/validation gate and must implement the existing `RetrievalSourceAdapter` without changing deterministic selection behavior.
