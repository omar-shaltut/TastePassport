import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import type {
  ExplanationRequest,
  JudgeExperienceAdapters,
  JudgeExperienceRunRequest,
} from '../../src/judge-experience/adapters.ts';
import { executeWithAdapters } from '../../src/judge-experience/adapter-runner.ts';
import { createFixtureAdapters } from '../../src/judge-experience/fixture-adapter.ts';
import { CATEGORIES } from '../../src/judge-experience/policy.ts';
import type { FixtureRun } from '../../src/judge-experience/types.ts';

const fixtureUrl = new URL('../fixtures/judge-experience/ready.json', import.meta.url);

function readyFixture(): FixtureRun {
  return JSON.parse(readFileSync(fixtureUrl, 'utf8')) as FixtureRun;
}

function runRequest(fixture: FixtureRun): JudgeExperienceRunRequest {
  const a = fixture.resolved_profiles.find((profile) => profile.side === 'A');
  const b = fixture.resolved_profiles.find((profile) => profile.side === 'B');
  assert.ok(a && b);
  return {
    run_id: fixture.run_id,
    destination_city: fixture.destination_city,
    person_a: { profile_ref: a.profile_ref },
    person_b: { profile_ref: b.profile_ref },
  };
}

test('FixtureAdapter drives the frozen engine without changing selected venues', async () => {
  const fixture = readyFixture();
  const result = await executeWithAdapters(
    runRequest(fixture),
    createFixtureAdapters(fixture),
  );

  assert.equal(result.state, 'READY');
  assert.deepEqual(
    result.slots.map((slot) => [slot.slot_id, slot.resolved_category, slot.selected?.entity_id]),
    [
      ['CULTURE', 'museum', 'shared-museum'],
      ['OUTDOORS', 'park', 'shared-park'],
      ['CITY_LIFE', 'shopping_mall', 'shared-mall'],
    ],
  );
});

test('retrieval boundary receives exactly twelve fixed side/category requests', async () => {
  const fixture = readyFixture();
  const base = createFixtureAdapters(fixture);
  const calls: string[] = [];
  const adapters: JudgeExperienceAdapters = {
    ...base,
    retrievalSource: {
      adapter_id: 'SPY_RETRIEVAL',
      async retrieve(request) {
        calls.push(`${request.side}:${request.category}`);
        return base.retrievalSource.retrieve(request);
      },
    },
  };

  const result = await executeWithAdapters(runRequest(fixture), adapters);
  assert.equal(result.state, 'READY');
  assert.deepEqual(calls, [
    ...CATEGORIES.map((category) => `A:${category}`),
    ...CATEGORIES.map((category) => `B:${category}`),
  ]);
});

test('explanation boundary receives immutable selected slots, not raw retrieval pools', async () => {
  const fixture = readyFixture();
  const base = createFixtureAdapters(fixture);
  let captured: ExplanationRequest | null = null;
  const adapters: JudgeExperienceAdapters = {
    ...base,
    explanationSource: {
      adapter_id: 'SPY_EXPLANATION',
      async explain(request) {
        captured = request;
        return base.explanationSource.explain(request);
      },
    },
  };

  const result = await executeWithAdapters(runRequest(fixture), adapters);
  assert.equal(result.state, 'READY');
  assert.ok(captured);
  assert.deepEqual(Object.keys(captured).sort(), ['destination_city', 'run_id', 'slots']);
  assert.deepEqual(
    captured.slots.map((slot) => slot.selected?.entity_id ?? null),
    ['shared-museum', 'shared-park', 'shared-mall'],
  );
  assert.equal('retrievals' in captured, false);
  assert.equal('resolved_profiles' in captured, false);
});

test('retrieval adapter failure fails closed before explanation when it affects a slot', async () => {
  const fixture = readyFixture();
  const base = createFixtureAdapters(fixture);
  let explanationCalled = false;
  const adapters: JudgeExperienceAdapters = {
    ...base,
    retrievalSource: {
      adapter_id: 'FAILING_RETRIEVAL',
      async retrieve(request) {
        if (request.side === 'A' && request.category === 'museum') {
          throw new Error('synthetic retrieval failure');
        }
        return base.retrievalSource.retrieve(request);
      },
    },
    explanationSource: {
      adapter_id: 'EXPLANATION_SPY',
      async explain(request) {
        explanationCalled = true;
        return base.explanationSource.explain(request);
      },
    },
  };

  const result = await executeWithAdapters(runRequest(fixture), adapters);
  assert.equal(result.state, 'FAILED');
  assert.equal(result.error_code, 'QLOO_RETRIEVAL_FAILED');
  assert.equal(result.slots[0]?.status, 'EVIDENCE_UNAVAILABLE');
  assert.equal(explanationCalled, false);
});

test('retrieval adapter cannot smuggle evidence under mismatched request metadata', async () => {
  const fixture = readyFixture();
  const base = createFixtureAdapters(fixture);
  const adapters: JudgeExperienceAdapters = {
    ...base,
    retrievalSource: {
      adapter_id: 'MALFORMED_RETRIEVAL',
      async retrieve(request) {
        const result = await base.retrievalSource.retrieve(request);
        if (request.side === 'A' && request.category === 'museum') {
          return { ...result, category: 'park' };
        }
        return result;
      },
    },
  };

  const result = await executeWithAdapters(runRequest(fixture), adapters);
  assert.equal(result.state, 'FAILED');
  assert.equal(result.error_code, 'QLOO_RETRIEVAL_FAILED');
});

test('profile resolver adapter cannot return a different side or profile reference', async () => {
  const fixture = readyFixture();
  const base = createFixtureAdapters(fixture);
  const adapters: JudgeExperienceAdapters = {
    ...base,
    profileResolver: {
      adapter_id: 'MALFORMED_PROFILE',
      async resolveProfile(request) {
        const profile = await base.profileResolver.resolveProfile(request);
        return { ...profile, side: request.side === 'A' ? 'B' : 'A' };
      },
    },
  };

  const result = await executeWithAdapters(runRequest(fixture), adapters);
  assert.equal(result.state, 'FAILED');
  assert.equal(result.error_code, 'PROFILE_RESOLUTION_FAILED');
});

test('explanation adapter still cannot substitute deterministic venue selection', async () => {
  const fixture = readyFixture();
  const base = createFixtureAdapters(fixture);
  const adapters: JudgeExperienceAdapters = {
    ...base,
    explanationSource: {
      adapter_id: 'MALICIOUS_EXPLANATION',
      async explain(request) {
        const payload = await base.explanationSource.explain(request);
        return {
          ...payload,
          slots: payload.slots.map((slot, index) =>
            index === 0 ? { ...slot, entity_id: 'adapter-invented-venue' } : slot,
          ),
        };
      },
    },
  };

  const result = await executeWithAdapters(runRequest(fixture), adapters);
  assert.equal(result.state, 'FAILED');
  assert.equal(result.error_code, 'EXPLANATION_VALIDATION_FAILED');
});

test('Adapter Boundary V1 implementation is network-free', () => {
  const adapterSource = readFileSync(
    new URL('../../src/judge-experience/fixture-adapter.ts', import.meta.url),
    'utf8',
  );
  const runnerSource = readFileSync(
    new URL('../../src/judge-experience/adapter-runner.ts', import.meta.url),
    'utf8',
  );
  const source = `${adapterSource}\n${runnerSource}`;

  assert.doesNotMatch(source, /\bfetch\s*\(/);
  assert.doesNotMatch(source, /hackathon\.api\.qloo\.com/i);
  assert.doesNotMatch(source, /QLOO_API_KEY|X-Api-Key/i);
  assert.doesNotMatch(source, /node:https|node:http/);
});
