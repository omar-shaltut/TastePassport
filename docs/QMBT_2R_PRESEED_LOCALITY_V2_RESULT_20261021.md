# QMBT-2R Pre-Seed Locality V2 Result — 2026-10-21

Status: FAIL_V2_PRESEED_LOCALITY_PASS

## Provenance

- Live run: `20261021T211847Z`
- Harness commit: `5583dc67cc8c2547f5c605a9ea5f0e470135432e`
- Protocol: `docs/QMBT_2R_PRESEED_LOCALITY_V2.md`
- Classifier: `ADMIN1_SEGMENT_IDENTITY_V2`
- Evidence class: DIAGNOSTIC_NOT_CONFIRMATORY
- CI validation for the exact harness commit: PASS
- Explicit human live authorization: GRANTED

## Observed execution

The authorized V2 pass began with the frozen eight-city manifest and stopped on
the first identity failure as required by the preregistered protocol.

### New York City

Result: `LOCALITY_RESOLVED`

- Final HTTP status: 200
- Attempts: 2
- Attempt 1: `NETWORK_OR_TIMEOUT`
- Attempt 2: `COMPLETED_VALID_2XX`
- Qualifying unique entity IDs: 1
- Resolved entity ID: `81E61924-6CEE-4AB4-93D3-282A5C784AB8`
- Resolved name: `New York`
- Disambiguation: `New York, New York, United States of America`

### Tokyo

Result: `LOCALITY_UNRESOLVED`

- Frozen lookup query: `Tokyo, Tokyo, Japan`
- Final HTTP status: 200
- Attempts: 1
- Attempt 1: `COMPLETED_VALID_2XX`
- Qualifying unique entity IDs: 0

The Search response did contain locality rows related to the query, but no row
satisfied the complete preregistered Tokyo identity path.

Examples observed in the raw response included:

- `Little Tokyo` in Los Angeles, California, United States of America;
- `Little Tokyo` in Toronto, Ontario, Canada; and
- a locality named `Tokyo` whose disambiguation placed it in Dubai, United
  Arab Emirates.

No returned row qualified as Tokyo, Tokyo, Japan under
`ADMIN1_SEGMENT_IDENTITY_V2`.

## Interpretation

The Tokyo failure is not an HTTP or transport failure.

Qloo Search returned a valid HTTP 200 response, but the returned result set did
not contain a locality satisfying the frozen city + admin1 + country identity
rule.

The V2 classifier therefore behaved as preregistered by returning
`LOCALITY_UNRESOLVED`.

This execution provides diagnostic evidence about the suitability of the
current Search-based pre-Seed locality resolution strategy. It is not evidence
for or against the TastePassport product hypothesis.

## Decision

The QMBT-2R Pre-Seed Locality V2 pass did not complete successfully.

Therefore:

1. Do not rerun the same V2 live pass.
2. Do not modify the frozen Tokyo query, aliases, administrative identity, or
   classifier in response to this observed result and then treat the rerun as
   the same preregistered test.
3. Do not create a Seed Commit.
4. Do not perform holdout ranking, profile-seed resolution, Insights retrieval,
   recommendation retrieval, or confirmatory execution.
5. Preserve the V2 protocol and this failed execution as diagnostic evidence.
6. Stop at a new architectural validation gate before selecting a successor
   locality-resolution strategy.
