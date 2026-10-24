# Frontend Consumption V1

Status: development implementation gate.

## Purpose

Render the frozen Judge Experience from an adapter-produced presentation payload without moving recommendation authority into the browser.

## Boundary

The browser consumes `JUDGE_FRONTEND_V1`, a deliberately minimized presentation contract containing only:

- terminal run state;
- destination city and non-secret profile references;
- verified progress labels;
- the three fixed slot outcomes;
- selected venue identity/display metadata;
- Person A / Person B source ranks for selected venues;
- validated explanation copy;
- the product truth note.

The browser does **not** receive raw Qloo retrieval pools, seed entity IDs, reconciliation candidate lists, worst-rank/total-rank internals, or any global cross-category score.

## Flow

`FixtureAdapter -> executeWithAdaptersEnvelope -> deterministic validation -> buildFrontendPayload -> /api/judge-run -> static web UI`

The fixture-backed HTTP endpoint is development infrastructure only. It does not make network calls to Qloo or an LLM provider.

## Visual contract

The selected Judge Experience direction is represented as:

1. destination + run status;
2. `Your Shared Taste` hero;
3. three equal-status cards in frozen order: Culture, Outdoor, City Life;
4. `Shared Qloo match` plus Person A / Person B source ranks;
5. validated `Why it works for both` explanation;
6. verified execution trace;
7. a trust note stating that Qloo supplies venue evidence, deterministic code reconciles it, and AI explains only after selection.

There is no `#1 Overall`, no global venue ranking, and no pair-exclusivity/perfect-match claim.

## Failure behavior

`FAILED` renders a fail-closed panel and does not display explanation copy. `PARTIAL_READY` may render honest empty slots with `NO_SHARED_QLOO_EVIDENCE`; the browser never fills them with another category or invented venue.

## Framework decision

V1 intentionally uses dependency-free HTML/CSS/JavaScript. This validates payload consumption and the visual/product contract before selecting a frontend framework. A later framework migration must preserve `JUDGE_FRONTEND_V1` semantics and cannot move selection logic client-side.

## Non-goals

- no Qloo live adapter;
- no LLM provider integration;
- no holdout access;
- no client-side ranking or slot selection;
- no production deployment or authentication;
- no image-provider integration yet.
