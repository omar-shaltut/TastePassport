import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { executeWithAdapters } from '../src/judge-experience/adapter-runner.ts';
import { createFixtureAdapters } from '../src/judge-experience/fixture-adapter.ts';
import type { JudgeExperienceRunRequest } from '../src/judge-experience/adapters.ts';
import type { FixtureRun } from '../src/judge-experience/types.ts';

const inputPath = process.argv[2];
if (!inputPath) {
  throw new Error('Usage: npm run fixture -- <fixture.json>');
}

const text = await readFile(resolve(inputPath), 'utf8');
const fixture = JSON.parse(text) as FixtureRun;
const profileA = fixture.resolved_profiles.find((profile) => profile.side === 'A');
const profileB = fixture.resolved_profiles.find((profile) => profile.side === 'B');

if (!profileA || !profileB) {
  throw new Error('Fixture runner requires one resolved profile per side.');
}

const request: JudgeExperienceRunRequest = {
  run_id: fixture.run_id,
  destination_city: fixture.destination_city,
  person_a: { profile_ref: profileA.profile_ref },
  person_b: { profile_ref: profileB.profile_ref },
};

const result = await executeWithAdapters(
  request,
  createFixtureAdapters(fixture),
);
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);

if (result.state === 'FAILED') {
  process.exitCode = 1;
}
