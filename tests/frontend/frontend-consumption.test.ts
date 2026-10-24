import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { executeFixtureForFrontend } from '../../src/frontend/demo.ts';
import type { FixtureRun } from '../../src/judge-experience/types.ts';

const fixtureUrl = new URL('../fixtures/judge-experience/ready.json', import.meta.url);

function readyFixture(): FixtureRun {
  return JSON.parse(readFileSync(fixtureUrl, 'utf8')) as FixtureRun;
}

test('frontend consumes adapter output without inventing a global ranking', async () => {
  const payload = await executeFixtureForFrontend(readyFixture());
  assert.equal(payload.state, 'READY');
  assert.equal(payload.destination_city, 'London');
  assert.deepEqual(
    payload.cards.map((card) => [card.slot_id, card.entity_id]),
    [
      ['CULTURE', 'shared-museum'],
      ['OUTDOORS', 'shared-park'],
      ['CITY_LIFE', 'shared-mall'],
    ],
  );
  assert.ok(payload.cards.every((card) => !('overall_rank' in card)));
});

test('frontend payload is presentation-minimized and excludes raw evidence', async () => {
  const payload = await executeFixtureForFrontend(readyFixture());
  const serialized = JSON.stringify(payload);
  for (const forbidden of [
    'retrievals',
    'qloo_seed_entity_ids',
    'ordered_shared_candidates',
    'worst_rank',
    'total_rank',
  ]) {
    assert.equal(serialized.includes(forbidden), false, `Leaked ${forbidden}`);
  }
});

test('validated explanations and source ranks survive into the cards', async () => {
  const payload = await executeFixtureForFrontend(readyFixture());
  const culture = payload.cards[0];
  assert.equal(culture?.rank_a, 2);
  assert.equal(culture?.rank_b, 3);
  assert.equal(culture?.why_it_works, 'Qloo surfaced this museum for both profiles.');
  assert.match(payload.evidence_note, /Qloo surfaces the venue evidence/);
});

test('failed explanation validation cannot leak unsafe copy into the frontend', async () => {
  const fixture = structuredClone(readyFixture()) as unknown as {
    explanation_payload: FixtureRun['explanation_payload'] & {
      slots: Array<FixtureRun['explanation_payload']['slots'][number]>;
    };
  } & FixtureRun;
  fixture.explanation_payload.slots[0] = {
    ...fixture.explanation_payload.slots[0]!,
    why_it_works: 'This is your #1 overall perfect match.',
  };

  const payload = await executeFixtureForFrontend(fixture);
  assert.equal(payload.state, 'FAILED');
  assert.equal(payload.summary, null);
  assert.ok(payload.cards.every((card) => card.why_it_works === null));
});

test('static frontend source contains no forbidden recommendation claims', () => {
  const html = readFileSync(new URL('../../web/index.html', import.meta.url), 'utf8');
  const app = readFileSync(new URL('../../web/app.js', import.meta.url), 'utf8');
  const source = `${html}\n${app}`;
  assert.doesNotMatch(source, /perfect match/i);
  assert.doesNotMatch(source, /unique(?:ly)? matched/i);
  assert.doesNotMatch(source, /#1 overall/i);
});
