// WebCrypto RSASSA-PKCS1-v1_5 SHA-256. No custom padding or modular exponentiation.
// The service-role credential stays in this process. Callers present their own JWT.

const textEncoder = new TextEncoder();

function bytesToBase64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function hexToBytes(hex) {
  const normalized = hex.trim().toLowerCase();
  if (normalized.length === 0 || normalized.length % 2 !== 0) return null;
  const bytes = new Uint8Array(normalized.length / 2);
  for (let index = 0; index < bytes.length; index += 1) {
    const pair = normalized.slice(index * 2, index * 2 + 2);
    if (!/^[0-9a-f]{2}$/.test(pair)) return null;
    bytes[index] = Number.parseInt(pair, 16);
  }
  return bytes;
}

export function itemLine(item) {
  const product = String(item?.product_id ?? '').trim();
  const name = String(item?.name ?? '').trim();
  const quantity = Math.max(1, Math.round(Number(item?.quantity ?? 1)) || 1);
  const price = Number(item?.price ?? 0);
  const station = String(item?.station_id ?? '').trim();
  const notes = String(item?.notes ?? item?.item_note ?? '').trim();
  return [
    product || '-',
    name || 'Ürün',
    String(quantity),
    price.toFixed(2),
    station || '-',
    notes || '-',
  ].join('|');
}

export function canonicalPayload({
  restaurantId,
  branchId,
  localOrderId,
  jobType,
  outcome,
  revision,
  eventId,
  keyId,
  fingerprint,
  items,
}) {
  const stations = [...new Set(
    items.map((item) => String(item?.station_id ?? '').trim()).filter((id) => id !== ''),
  )].sort();
  const lines = items.map(itemLine).sort();
  return [
    'v2',
    restaurantId.trim(),
    branchId.trim(),
    localOrderId.trim(),
    jobType.trim(),
    outcome.trim(),
    revision.trim(),
    stations.join(','),
    eventId.trim(),
    keyId.trim(),
    fingerprint.trim(),
    lines.join('\n'),
  ].join('|');
}

export function parseEvidence(token) {
  const parts = String(token ?? '').split('.');
  if (parts.length !== 6 || parts[0] !== 'v2') return null;
  const [_, outcome, revision, eventId, keyId, signature] = parts;
  if (!['forwarded', 'uncertain', 'failed'].includes(outcome)) return null;
  if (!/^[0-9a-f]{16}$/.test(keyId) || !/^[0-9a-f]+$/.test(signature)) return null;
  if (revision === '' || eventId === '') return null;
  return { outcome, revision, eventId, keyId, signature };
}

export async function verifyEvidenceSignature({
  modulusHex,
  exponent,
  signatureHex,
  payload,
}) {
  if (exponent !== 65537) return false;
  const modulus = hexToBytes(modulusHex);
  const signature = hexToBytes(signatureHex);
  if (modulus == null || signature == null || modulus.length < 256 || modulus.length > 512) {
    return false;
  }
  if (signature.length !== modulus.length) return false;
  const key = await crypto.subtle.importKey(
    'jwk',
    {
      kty: 'RSA',
      n: bytesToBase64Url(modulus),
      e: bytesToBase64Url(new Uint8Array([1, 0, 1])),
      alg: 'RS256',
      ext: true,
    },
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  return crypto.subtle.verify(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    signature,
    textEncoder.encode(payload),
  );
}

function timeoutMs() {
  const parsed = Number(DenoOrNode.env('IBUL_EVIDENCE_RPC_TIMEOUT_MS') || '8000');
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 8000;
}

async function authenticate(request) {
  const header = request.headers.get('authorization') ?? '';
  const anon = DenoOrNode.env('SUPABASE_ANON_KEY');
  const base = DenoOrNode.env('SUPABASE_URL');
  if (!header.toLowerCase().startsWith('bearer ') || !anon || !base) return null;
  const response = await fetch(`${base}/auth/v1/user`, {
    headers: { authorization: header, apikey: anon },
    signal: AbortSignal.timeout(timeoutMs()),
  });
  if (!response.ok) return null;
  const user = await response.json();
  if (!user || typeof user.id !== 'string' || !/^[0-9a-f-]{36}$/i.test(user.id)) return null;
  return { id: user.id };
}

async function postRpc(baseUrl, token, name, body) {
  const response = await fetch(`${baseUrl}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
      apikey: DenoOrNode.env('SUPABASE_ANON_KEY'),
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs()),
  });
  const text = await response.text();
  return { status: response.status, text };
}

export async function inspectEvidenceRequest(request) {
  try {
    if (request.method === 'OPTIONS') {
      return { response: new Response(null, { status: 204 }) };
    }
    if (request.method !== 'POST') return { response: json({ error: 'Yalnız POST.' }, 405) };
    const databaseUrl = DenoOrNode.env('SUPABASE_URL');
    const serviceKey = DenoOrNode.env('SUPABASE_SERVICE_ROLE_KEY');
    if (!databaseUrl || !serviceKey || !DenoOrNode.env('SUPABASE_ANON_KEY')) {
      return { response: json({ error: 'Doğrulayıcı yapılandırması yok.' }, 500) };
    }
    const user = await authenticate(request);
    if (user == null) return { response: json({ error: 'Yetkisiz istek.' }, 401) };
    const body = await request.json();
    const restaurantId = String(body.p_restaurant_id ?? '');
    const evidence = parseEvidence(body.p_local_print_evidence);
    let accepted = false;
    let branchId = '';
    if (evidence != null) {
      const keyCall = await postRpc(
        databaseUrl,
        serviceKey,
        'restaurant_lan_print_evidence_public_key',
        { p_restaurant_id: restaurantId, p_key_id: evidence.keyId },
      );
      const key = firstRow(keyCall.text);
      if (keyCall.status < 400 && key && key.revoked !== true && key.modulus && key.branch_id) {
        branchId = String(key.branch_id);
        const payload = canonicalPayload({
          restaurantId,
          branchId,
          localOrderId: String(body.p_local_order_id ?? ''),
          jobType: String(body.p_job_type ?? ''),
          outcome: evidence.outcome,
          revision: evidence.revision,
          eventId: evidence.eventId,
          keyId: evidence.keyId,
          fingerprint: String(key.server_fingerprint ?? ''),
          items: Array.isArray(body.p_items) ? body.p_items : [],
        });
        try {
          accepted = await verifyEvidenceSignature({
            modulusHex: String(key.modulus),
            exponent: Number(key.exponent),
            signatureHex: evidence.signature,
            payload,
          });
        } catch (error) {
          console.error(error);
          accepted = false;
        }
      }
    }
    return {
      response: null,
      accepted,
      databaseUrl,
      serviceKey,
      body,
      evidence,
      branchId,
      userId: user.id,
    };
  } catch (error) {
    return { response: errorResponse(error) };
  }
}

export async function submitEvidenceOrder(inspection) {
  try {
    const order = await postRpc(
      inspection.databaseUrl,
      inspection.serviceKey,
      'create_table_order_with_print_jobs',
      {
        p_restaurant_id: inspection.body.p_restaurant_id,
        p_table_number: inspection.body.p_table_number,
        p_items: inspection.body.p_items,
        p_waiter_id: inspection.body.p_waiter_id ?? null,
        p_waiter_name: inspection.body.p_waiter_name ?? null,
        p_notes: inspection.body.p_notes ?? null,
        p_job_type: inspection.body.p_job_type ?? 'new_order',
        p_order_type: inspection.body.p_order_type ?? 'table',
        p_local_order_id: inspection.body.p_local_order_id ?? null,
        p_local_print_evidence: inspection.evidence == null
          ? null
          : (inspection.accepted ? inspection.body.p_local_print_evidence : 'rejected'),
        p_verified_actor: inspection.userId,
        p_evidence_branch: inspection.accepted ? inspection.branchId : null,
      },
    );
    return new Response(order.text, {
      status: order.status,
      headers: { 'content-type': 'application/json' },
    });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function handleEvidenceRequest(request) {
  const inspection = await inspectEvidenceRequest(request);
  if (inspection.response) return inspection.response;
  return submitEvidenceOrder(inspection);
}

function errorResponse(error) {
  if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
    return json({ error: 'Doğrulama zaman aşımı.' }, 504);
  }
  console.error(error);
  return json({ error: 'Doğrulama hatası.' }, 500);
}

function firstRow(text) {
  try {
    const decoded = JSON.parse(text);
    if (Array.isArray(decoded)) return decoded[0] ?? null;
    return decoded;
  } catch (_) {
    return null;
  }
}

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

const DenoOrNode = {
  env(name) {
    if (typeof Deno !== 'undefined' && Deno.env?.get) return Deno.env.get(name) ?? '';
    return globalThis.process?.env?.[name] ?? '';
  },
};
