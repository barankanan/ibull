import { createHmac, timingSafeEqual } from 'node:crypto';
import { createServer } from 'node:http';

const postgrest = process.env.POSTGREST_URL ?? '';
const secret = process.env.IBUL_EVIDENCE_JWT_SECRET ?? '';
const anon = process.env.SUPABASE_ANON_KEY ?? '';
const sessions = new Map(
  (process.env.IBUL_AUTH_SESSIONS ?? '')
    .split(',')
    .map((row) => row.trim())
    .filter((row) => row.includes(':'))
    .map((row) => {
      const separator = row.indexOf(':');
      return [row.slice(0, separator), row.slice(separator + 1)];
    }),
);

function verifyUserToken(token) {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const expected = createHmac('sha256', secret).update(`${parts[0]}.${parts[1]}`).digest();
  const actual = Buffer.from(parts[2].replaceAll('-', '+').replaceAll('_', '/'), 'base64');
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) return null;
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  const now = Math.floor(Date.now() / 1000);
  if (payload.role !== 'authenticated') return null;
  if (typeof payload.exp !== 'number' || payload.exp <= now) return null;
  if (sessions.get(payload.session_id) !== payload.sub) return null;
  if (typeof payload.sub !== 'string' || payload.sub === '') return null;
  if (typeof payload.session_id !== 'string' || payload.session_id === '') return null;
  return { id: payload.sub, sessionId: payload.session_id };
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', 'http://127.0.0.1');
  if (url.pathname === '/auth/v1/user') {
    if ((req.headers.apikey ?? '') !== anon) {
      res.writeHead(401).end('{"error":"invalid api key"}');
      return;
    }
    const header = String(req.headers.authorization ?? '');
    const user = header.toLowerCase().startsWith('bearer ')
      ? verifyUserToken(header.slice(7).trim())
      : null;
    if (user == null) {
      res.writeHead(401).end('{"error":"invalid token"}');
      return;
    }
    res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ id: user.id }));
    return;
  }
  if (url.pathname === '/auth/v1/logout' && req.method === 'POST') {
    if ((req.headers.apikey ?? '') !== anon) {
      res.writeHead(401).end('{"error":"invalid api key"}');
      return;
    }
    const header = String(req.headers.authorization ?? '');
    const user = header.toLowerCase().startsWith('bearer ')
      ? verifyUserToken(header.slice(7).trim())
      : null;
    if (user == null) {
      res.writeHead(401).end('{"error":"invalid token"}');
      return;
    }
    sessions.delete(user.sessionId);
    res.writeHead(204).end();
    return;
  }
  if (url.pathname.startsWith('/rest/v1/rpc/')) {
    try {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      const name = url.pathname.slice('/rest/v1/rpc/'.length);
      const response = await fetch(`${postgrest}/rpc/${name}`, {
        method: 'POST',
        headers: {
          authorization: String(req.headers.authorization ?? ''),
          'content-type': 'application/json',
          connection: 'close',
        },
        body: Buffer.concat(chunks),
      });
      const text = await response.text();
      res.writeHead(response.status, { 'content-type': 'application/json' }).end(text);
    } catch (error) {
      console.error(error);
      if (!res.headersSent) res.writeHead(502).end('{"error":"upstream closed"}');
    }
    return;
  }
  res.writeHead(404).end('{"error":"not found"}');
});

server.listen(0, '127.0.0.1', () => {
  console.log(`GATEWAY_PORT ${server.address().port}`);
});
