import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { reconcileCategory } from '../../src/judge-experience/engine.ts';
import { executeFixtureRun } from '../../src/judge-experience/state-machine.ts';
import type { FixtureRun, RetrievalResult } from '../../src/judge-experience/types.ts';

const fixtureUrl = new URL('../fixtures/judge-experience/ready.json', import.meta.url);

function readyFixture(): FixtureRun {
  return JSON.parse(readFileSync(fixtureUrl, 'utf8')) as FixtureRun;
}

function cloneFixture(): FixtureRun {
  return structuredClone(readyFixture());
}

test('ready fixture implements fixed slots without global ranking', () => {
  const result = executeFixtureRun(readyFixture());
  assert.equal(result.state, 'READY');
  assert.deepEqual(
    result.slots.map((slot) => [slot.slot_id, slot.resolved_category, slot.selected?.entity_id]),
    [
      ['CULTURE', 'museum', 'shared-museum'],
      ['OUTDOORS', 'park', 'shared-park'],
      ['CITY_LIFE', 'shopping_mall', 'shared-mall'],
    ],
  );
  assert.equal(result.validation?.status, 'PASS');
});

test('A/B swap preserves same-category Leximin entity ordering', () => {
  const fixture = readyFixture();
  const museumA = fixture.retrievals.find((r) => r.side === 'A' && r.category === 'museum');
  const museumB = fixture.retrievals.find((r) => r.side === 'B' && r.category === 'museum');
  assert.ok(museumA && museumB);

  const forward = reconcileCategory('museum', museumA, museumB);
  const swappedA: RetrievalResult = { ...museumB, side: 'A' };
  const swappedB: RetrievalResult = { ...museumA, side: 'B' };
  const reverse = reconcileCategory('museum', swappedA, swappedB);

  assert.deepEqual(
    forward.ordered_shared_candidates.map((candidate) => candidate.entity_id),
    reverse.ordered_shared_candidates.map((candidate) => candidate.entity_id),
  );
});

test('first Qloo occurrence supplies the rank when an entity repeats', () => {
  const result = executeFixtureRun(readyFixture());
  const culture = result.slots[0];
  assert.equal(culture?.selected?.entity_id, 'shared-museum');
  assert.equal(culture?.selected?.rank_a, 2);
});

test('fixed Culture priority beats a numerically stronger art-gallery candidate', () => {
  const result = executeFixtureRun(readyFixture());
  assert.equal(result.slots[0]?.resolved_category, 'museum');
  assert.equal(result.slots[0]?.selected?.entity_id, 'shared-museum');
});

test('global entity dedupe makes Outdoors take the next park candidate', () => {
  const result = executeFixtureRun(readyFixture());
  assert.equal(result.slots[0]?.selected?.entity_id, 'shared-museum');
  assert.equal(result.slots[1]?.selected?.entity_id, 'shared-park');
});

test('City Life falls from restaurant to shopping_mall only after empty restaurant intersection', () => {
  const result = executeFixtureRun(readyFixture());
  assert.equal(result.slots[2]?.resolved_category, 'shopping_mall');
  assert.equal(result.slots[2]?.selected?.entity_id, 'shared-mall');
});

test('unavailable earlier evidence cannot masquerade as an empty intersection', () => {
  const fixture = cloneFixture() as unknown as {
    retrievals: Array<RetrievalResult>;
  } & FixtureRun;
  const museumA = fixture.retrievals.find((r) => r.side === 'A' && r.category === 'museum');
  assert.ok(museumA);
  Object.assign(museumA, { status: 'EVIDENCE_UNAVAILABLE', entities: [] });

  const result = executeFixtureRun(fixture);
  assert.equal(result.state, 'FAILED');
  assert.equal(result.error_code, 'QLOO_RETRIEVAL_FAILED');
  assert.equal(result.slots[0]?.status, 'EVIDENCE_UNAVAILABLE');
  assert.equal(result.progress.find((p) => p.state === 'EXPLAINING')?.completed, false);
});

test('honest missing shared evidence produces PARTIAL_READY', () => {
  const fixture = cloneFixture() as unknown as {
    retrievals: Array<RetrievalResult>;
    explanation_payload: FixtureRun['explanation_payload'];
  } & FixtureRun;
  for (const retrieval of fixture.retrievals) {
    if (retrieval.category === 'park') {
      Object.assign(retrieval, {
        entities: [{ entity_id: `park-${retrieval.side}`, rank: 1 }],
      });
    }
  }
  fixture.explanation_payload = {
    ...fixture.explanation_payload,
    slots: fixture.explanation_payload.slots.filter((slot) => slot.slot_id !== 'OUTDOORS'),
  };

  const result = executeFixtureRun(fixture);
  assert.equal(result.state, 'PARTIAL_READY');
  assert.equal(result.slots[1]?.status, 'NO_SHARED_QLOO_EVIDENCE');
  assert.equal(result.validation?.status, 'PASS');
});

test('LLM-like explanation payload cannot substitute a venue', () => {
  const fixture = cloneFixture() as unknown as {
    explanation_payload: {
      shared_taste_summary?: string | null;
      slots: Array<FixtureRun['explanation_payload']['slots'][number]>;
    };
  } & FixtureRun;
  fixture.explanation_payload.slots[0] = {
    ...fixture.explanation_payload.slots[0]!,
    entity_id: 'invented-by-llm',
  };

  const result = executeFixtureRun(fixture);
  assert.equal(result.state, 'FAILED');
  assert.equal(result.error_code, 'EXPLANATION_VALIDATION_FAILED');
  assert.equal(result.validation?.status, 'FAIL');
});

test('forbidden truth-contract claims are rejected', () => {
  const fixture = cloneFixture() as unknown as {
    explanation_payload: {
      shared_taste_summary?: string | null;
      slots: Array<FixtureRun['explanation_payload']['slots'][number]>;
    };
  } & FixtureRun;
  fixture.explanation_payload.slots[0] = {
    ...fixture.explanation_payload.slots[0]!,
    why_it_works: 'This is your #1 overall perfect match.',
  };

  const result = executeFixtureRun(fixture);
  assert.equal(result.state, 'FAILED');
  assert.equal(result.error_code, 'EXPLANATION_VALIDATION_FAILED');
});

test('READY progress only marks successfully completed operational states', () => {
  const result = executeFixtureRun(readyFixture());
  assert.equal(result.state, 'READY');
  assert.ok(result.progress.every((item) => item.completed));
  assert.deepEqual(result.state_history.slice(-3), ['EXPLAINING', 'VALIDATING', 'READY']);
});
