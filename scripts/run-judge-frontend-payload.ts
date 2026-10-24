import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { executeFixtureForFrontend } from '../src/frontend/demo.ts';
import type { FixtureRun } from '../src/judge-experience/types.ts';

const inputPath = process.argv[2] ?? 'tests/fixtures/judge-experience/ready.json';
const text = await readFile(resolve(inputPath), 'utf8');
const fixture = JSON.parse(text) as FixtureRun;
const payload = await executeFixtureForFrontend(fixture);
process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);

if (payload.state === 'FAILED') process.exitCode = 1;
