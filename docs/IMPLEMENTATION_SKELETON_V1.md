# Implementation Skeleton V1

Status: **IMPLEMENTED FOR OFFLINE VALIDATION**

This skeleton implements the frozen Judge Experience contract as TypeScript pure functions and a fixture-driven state machine. It deliberately does not contain a Qloo HTTP client, LLM provider client, frontend, database, or secret handling.

## Scope

- strict TypeScript domain types for retrieval evidence, reconciliation, slots, explanation payloads, progress, and terminal states;
- `LEXIMIN_RANK_V1` inside a single category only;
- fixed `CULTURE / OUTDOORS / CITY_LIFE` chains;
- same-category `entity_id` intersection;
- first-Qloo-occurrence duplicate semantics;
- global final-card deduplication;
- fail-closed distinction between `NO_SHARED_QLOO_EVIDENCE` and `EVIDENCE_UNAVAILABLE`;
- immutable explanation validator;
- synchronous fixture state-machine execution for development and tests.

## Non-goals

This stage does **not** implement:

- live Qloo requests;
- free-form taste-to-seed resolution;
- an LLM call;
- a web UI;
- cross-category scoring;
- one-sided fallback;
- holdout execution.

Those remain separate validation/implementation stages.

## Local fixture execution

With Node 22.6+:

```bash
npm test
npm run typecheck
npm run fixture -- tests/fixtures/judge-experience/ready.json
```

The fixture runner is intentionally network-free. A failed invariant exits nonzero.

## Architecture boundary

```text
fixture retrieval evidence
  -> same-category reconciliation
  -> LEXIMIN_RANK_V1
  -> fixed slot assembly + dedupe
  -> immutable selected payload
  -> untrusted explanation payload fixture
  -> deterministic validator
  -> READY | PARTIAL_READY | FAILED
```

A future Qloo adapter must produce the same `RetrievalResult` contract. A future LLM adapter must produce the same `ExplanationPayload` contract. Neither adapter may change deterministic selection logic.
