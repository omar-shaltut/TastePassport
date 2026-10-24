import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { executeFixtureForFrontend } from '../src/frontend/demo.ts';
import type { FixtureRun } from '../src/judge-experience/types.ts';

const host = process.env.HOST ?? '127.0.0.1';
const port = Number(process.env.PORT ?? '4173');
const fixturePath = resolve('tests/fixtures/judge-experience/ready.json');

const staticFiles = new Map<string, { path: string; type: string }>([
  ['/', { path: 'web/index.html', type: 'text/html; charset=utf-8' }],
  ['/index.html', { path: 'web/index.html', type: 'text/html; charset=utf-8' }],
  ['/app.js', { path: 'web/app.js', type: 'text/javascript; charset=utf-8' }],
  ['/styles.css', { path: 'web/styles.css', type: 'text/css; charset=utf-8' }],
]);

async function frontendPayload() {
  const fixture = JSON.parse(await readFile(fixturePath, 'utf8')) as FixtureRun;
  return executeFixtureForFrontend(fixture);
}

const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url ?? '/', `http://${request.headers.host ?? host}`);
    if (url.pathname === '/api/judge-run') {
      const payload = await frontendPayload();
      response.writeHead(payload.state === 'FAILED' ? 500 : 200, {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
      });
      response.end(JSON.stringify(payload));
      return;
    }

    const file = staticFiles.get(url.pathname);
    if (!file) {
      response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
      response.end('Not found');
      return;
    }

    response.writeHead(200, { 'content-type': file.type });
    response.end(await readFile(resolve(file.path)));
  } catch {
    response.writeHead(500, { 'content-type': 'text/plain; charset=utf-8' });
    response.end('Frontend demo failed safely.');
  }
});

server.listen(port, host, () => {
  process.stdout.write(`TastePassport Judge Frontend: http://${host}:${port}\n`);
});
