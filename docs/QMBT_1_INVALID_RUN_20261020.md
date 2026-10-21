# QMBT-1 Invalid Execution — 20261020T224345Z

Status: INVALID_EXECUTION_API_SEMANTICS

## Provenance

- Run ID: `20261020T224345Z`
- Git commit: `6460548b39822d3bc5a6664b166452e8c2d5a4e7`
- Protocol: `QMBT_1`
- Execution mode: `CONFIRMATORY`
- Failure point: Pair 2 × Istanbul × `art_gallery`

## Observed failure

The personalized fixed-pool response for Profile E did not return the exact same entity set as the frozen category pool.

## Interpretation

This run is invalid and is not evidence for or against the QMBT-1 hypothesis.

The preregistered harness assumed that `filter.results.entities` would return every supplied frozen-pool entity so that the exact same entity set could be ranked under:

1. Profile A
2. Profile B
3. `UNSIGNALED_QLOO_BASELINE`

Observed Qloo API behavior violated that assumption.

## Evidence produced

The run produced:

- `run-manifest.json`
- an empty/incomplete `pair2-istanbul` run directory

It did not produce:

- a completed `case-record.json`
- blind semantic packets
- blind baseline packets
- a completed run summary

## Decision

Do not rerun QMBT-1 unchanged.

Before any protocol amendment or new confirmatory run, conduct a separate API-semantics diagnostic spike to determine whether fixed candidate scoring can be implemented reproducibly without assuming complete return of `filter.results.entities`.
