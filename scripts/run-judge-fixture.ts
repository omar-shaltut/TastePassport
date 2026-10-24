import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { executeFixtureRun } from '../src/judge-experience/state-machine.ts';
import type { FixtureRun } from '../src/judge-experience/types.ts';

const inputPath = process.argv[2];
if (!inputPath) {
  throw new Error('Usage: npm run fixture -- <fixture.json>');
}

const text = await readFile(resolve(inputPath), 'utf8');
const fixture = JSON.parse(text) as FixtureRun;
const result = executeFixtureRun(fixture);
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);

if (result.state === 'FAILED') {
  process.exitCode = 1;
}
