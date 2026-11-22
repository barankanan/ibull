// Runs the real Edge entry point (functions/verify-lan-print-evidence/index.ts)
// as a Deno subprocess with a locked-down permission set, against a stub
// Supabase. Run:
//   deno test --allow-net=127.0.0.1 --allow-run --allow-read --allow-env \
//     tests/verify_print_evidence_deno_test.ts
// Nothing here talks to a real Supabase project.
import { assertEquals } from 'jsr:@std/assert@1';
import {
  canonicalPayload,
} from '../functions/verify-lan-print-evidence/verify_print_evidence.mjs';

const RID = '11111111-1111-4111-8111-111111111111';
const BRANCH = '22222222-2222-4222-8222-222222222222';
const USER = '33333333-3333-4333-8333-333333333333';
const KEY_ID = 'abcdef0123456789';
const ITEMS = [{ product_id: 'p1', name: 'Çay', quantity: 2, price: 10, station_id: 's1' }];

const hex = (b: Uint8Array) => [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
const b64uToBytes = (s: string) =>
  Uint8Array.from(atob(s.replaceAll('-', '+').replaceAll('_', '/')), (c) => c.charCodeAt(0));

const pair = await crypto.subtle.generateKey(
  { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
  true,
  ['sign', 'verify'],
);
const jwk = await crypto.subtle.exportKey('jwk', pair.publicKey);
const modulusHex = hex(b64uToBytes(jwk.n!));

async function sign(payload: string) {
  return hex(new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', pair.privateKey, new TextEncoder().encode(payload))));
}

type Stub = {
  rpcCalls: { name: string; body: Record<string, unknown> }[];
  rpcHeaders: { name: string; authorization: string | null; apikey: string }[];
  serviceKey: string; revoked: boolean; exponent: number;
};
const stub: Stub = { rpcCalls: [], rpcHeaders: [], serviceKey: 'svc', revoked: false, exponent: 65537 };

const stubServer = Deno.serve({ hostname: '127.0.0.1', port: 0, onListen() {} }, async (req) => {
  const url = new URL(req.url);
  if (url.pathname === '/auth/v1/user') {
    return (req.headers.get('authorization') ?? '') === 'Bearer good'
      ? Response.json({ id: USER })
      : new Response('no', { status: 401 });
  }
  const name = url.pathname.split('/').pop()!;
  const body = await req.json();
  // Platform kuralı: Authorization'daki değer JWT değilse (yeni tip sb_secret_ anahtarı)
  // veritabanı isteği reddeder. Gizli anahtar yalnız `apikey` başlığında kabul edilir.
  const authorization = req.headers.get('authorization');
  const apikey = req.headers.get('apikey') ?? '';
  stub.rpcHeaders.push({ name, authorization, apikey });
  if (authorization !== null) {
    const bearer = authorization.replace(/^bearer /i, '');
    if (bearer.split('.').length !== 3) {
      return Response.json(
        { code: 'PGRST301', details: null, hint: null, message: `Expected 3 parts in JWT; got ${bearer.split('.').length}` },
        { status: 401 },
      );
    }
  } else if (apikey !== stub.serviceKey) {
    return new Response('no', { status: 401 });
  }
  stub.rpcCalls.push({ name, body });
  if (name === 'restaurant_lan_print_evidence_public_key') {
    return Response.json([{
      modulus: modulusHex, exponent: stub.exponent, branch_id: BRANCH,
      server_fingerprint: 'fp1', revoked: stub.revoked,
    }]);
  }
  return Response.json({ ok: true });
});
const stubUrl = `http://127.0.0.1:${(stubServer.addr as Deno.NetAddr).port}`;

async function startEdge(env: Record<string, string>) {
  const entry = new URL('../functions/verify-lan-print-evidence/index.ts', import.meta.url).pathname;
  const proc = new Deno.Command(Deno.execPath(), {
    args: ['run', '--allow-net=127.0.0.1', '--allow-env', '--allow-read', entry],
    env: { PORT: '0', ...env }, stdout: 'piped', stderr: 'piped',
  }).spawn();
  const reader = proc.stdout.pipeThrough(new TextDecoderStream()).getReader();
  let buf = '';
  while (!/EVIDENCE_VERIFIER_PORT (\d+)/.test(buf)) {
    const { value, done } = await reader.read();
    if (done) throw new Error('edge process exited early');
    buf += value;
  }
  const port = Number(/EVIDENCE_VERIFIER_PORT (\d+)/.exec(buf)![1]);
  return {
    url: `http://127.0.0.1:${port}`,
    async stop() { proc.kill(); await reader.cancel().catch(() => {}); await proc.stderr.cancel().catch(() => {}); await proc.status; },
  };
}

const fullEnv = { SUPABASE_URL: stubUrl, SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: 'svc' };

async function evidenceFor(localId: string, outcome = 'forwarded') {
  const payload = canonicalPayload({
    restaurantId: RID, branchId: BRANCH, localOrderId: localId, jobType: 'new_order',
    outcome, revision: 'r1', eventId: 'e1', keyId: KEY_ID, fingerprint: 'fp1', items: ITEMS,
  });
  return `v2.${outcome}.r1.e1.${KEY_ID}.${await sign(payload)}`;
}

const reqBody = (localId: string, evidence: string | null) => JSON.stringify({
  p_restaurant_id: RID, p_table_number: 1, p_items: ITEMS, p_local_order_id: localId,
  p_job_type: 'new_order', p_local_print_evidence: evidence,
});

async function post(edge: { url: string }, body: string, auth = 'Bearer good', method = 'POST') {
  const res = await fetch(edge.url, {
    method, headers: { authorization: auth, 'content-type': 'application/json' },
    body: method === 'POST' ? body : undefined,
  });
  await res.text();
  return res.status;
}

const lastOrder = () => stub.rpcCalls.filter((c) => c.name === 'create_table_order_with_print_jobs').at(-1)!.body;

Deno.test('real Edge entry: valid signature is accepted and bound to the key branch', async () => {
  const edge = await startEdge(fullEnv);
  try {
    stub.rpcCalls.length = 0; stub.revoked = false; stub.exponent = 65537;
    const ev = await evidenceFor('L-1');
    assertEquals(await post(edge, reqBody('L-1', ev)), 200);
    const o = lastOrder();
    assertEquals(o.p_local_print_evidence, ev);
    assertEquals(o.p_evidence_branch, BRANCH);
    assertEquals(o.p_verified_actor, USER);
  } finally { await edge.stop(); }
});

Deno.test('real Edge entry: forged, replayed-on-other-order, revoked and bad-exponent are rejected', async () => {
  const edge = await startEdge(fullEnv);
  try {
    stub.revoked = false; stub.exponent = 65537;
    const ev = await evidenceFor('L-2');
    // Same signature presented for a different local order.
    await post(edge, reqBody('L-OTHER', ev));
    assertEquals(lastOrder().p_local_print_evidence, 'rejected');
    assertEquals(lastOrder().p_evidence_branch, null);
    // Flipped signature byte.
    const forged = ev.slice(0, -1) + (ev.endsWith('0') ? '1' : '0');
    await post(edge, reqBody('L-2', forged));
    assertEquals(lastOrder().p_local_print_evidence, 'rejected');
    // Revoked key.
    stub.revoked = true;
    await post(edge, reqBody('L-2', ev));
    assertEquals(lastOrder().p_local_print_evidence, 'rejected');
    stub.revoked = false;
    // Exponent other than 65537.
    stub.exponent = 3;
    await post(edge, reqBody('L-2', ev));
    assertEquals(lastOrder().p_local_print_evidence, 'rejected');
    stub.exponent = 65537;
    // Malformed token: never dropped to "no evidence" (that would let the
    // server print an order that may already be on paper). It goes up as
    // 'rejected', which the server holds for the operator.
    await post(edge, reqBody('L-2', 'v2.forwarded.garbage'));
    assertEquals(lastOrder().p_local_print_evidence, 'rejected');
    assertEquals(lastOrder().p_evidence_branch, null);
    await post(edge, reqBody('L-2', '   '));
    assertEquals(lastOrder().p_local_print_evidence, null);
  } finally { await edge.stop(); }
});

Deno.test('real Edge entry: auth, method and configuration gates', async () => {
  const edge = await startEdge(fullEnv);
  try {
    stub.rpcCalls.length = 0;
    assertEquals(await post(edge, reqBody('L-3', null), 'Bearer bad'), 401);
    assertEquals(await post(edge, reqBody('L-3', null), ''), 401);
    assertEquals(await post(edge, '', 'Bearer good', 'GET'), 405);
    assertEquals(stub.rpcCalls.length, 0, 'no RPC may run before authentication');
  } finally { await edge.stop(); }
  const bare = await startEdge({ SUPABASE_URL: stubUrl });
  try {
    assertEquals(await post(bare, reqBody('L-3', null)), 500);
  } finally { await bare.stop(); }
});

Deno.test('real Edge entry: unsigned online order passes without evidence fields', async () => {
  const edge = await startEdge(fullEnv);
  try {
    assertEquals(await post(edge, reqBody('L-4', null)), 200);
    assertEquals(lastOrder().p_local_print_evidence, null);
    assertEquals(lastOrder().p_evidence_branch, null);
  } finally { await edge.stop(); }
});

Deno.test('real Edge entry: yeni tip gizli anahtar (JWT değil) yalnız apikey başlığında gider', async () => {
  const secret = 'sb_secret_test_0123456789';
  const edge = await startEdge({ ...fullEnv, SUPABASE_SERVICE_ROLE_KEY: secret });
  try {
    stub.rpcCalls.length = 0; stub.rpcHeaders.length = 0; stub.serviceKey = secret;
    stub.revoked = false; stub.exponent = 65537;
    const ev = await evidenceFor('L-secret');
    assertEquals(await post(edge, reqBody('L-secret', ev)), 200);
    assertEquals(lastOrder().p_local_print_evidence, ev);
    for (const h of stub.rpcHeaders) {
      assertEquals(h.authorization, null, `${h.name}: gizli anahtar Authorization'da gitmemeli`);
      assertEquals(h.apikey, secret);
    }
    assertEquals(stub.rpcHeaders.length, 2);
  } finally { stub.serviceKey = 'svc'; await edge.stop(); }
});

Deno.test('real Edge entry: eski tip JWT servis anahtarı Bearer + apikey ile gider', async () => {
  const legacy = 'aaa.bbb.ccc';
  const edge = await startEdge({ ...fullEnv, SUPABASE_SERVICE_ROLE_KEY: legacy });
  try {
    stub.rpcCalls.length = 0; stub.rpcHeaders.length = 0; stub.serviceKey = legacy;
    const ev = await evidenceFor('L-legacy');
    assertEquals(await post(edge, reqBody('L-legacy', ev)), 200);
    for (const h of stub.rpcHeaders) {
      assertEquals(h.authorization, `Bearer ${legacy}`);
      assertEquals(h.apikey, legacy);
    }
  } finally { stub.serviceKey = 'svc'; await edge.stop(); }
});

Deno.test({ name: 'shutdown', sanitizeOps: false, sanitizeResources: false, fn: async () => { await stubServer.shutdown(); } });
