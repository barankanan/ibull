import { createClient } from 'jsr:@supabase/supabase-js@2';

const allowedOrigins = new Set([
  'https://ibul.com.tr',
  'https://www.ibul.com.tr',
  'https://ibul-ecommerce.web.app',
  'https://ibul-ecommerce.firebaseapp.com',
  'http://localhost:3000',
  'http://localhost:5000',
  'http://localhost:8080',
]);

const hits = new Map<string, number[]>();
const maxBodyBytes = 65536;
const maxPerMinute = 10;

Deno.serve(async (request) => {
  const origin = request.headers.get('Origin');
  const cors = corsHeaders(origin);
  if (origin && !cors) {
    return json({ ok: false, error: 'ORIGIN_NOT_ALLOWED' }, 403, {});
  }
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: cors ?? {} });
  }

  const authHeader = request.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ') || authHeader.trim() === 'Bearer') {
    return json({ ok: false, error: 'AUTH_REQUIRED' }, 401, cors ?? {});
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  if (supabaseUrl === '' || anonKey === '') {
    return json({ ok: false, error: 'AUTH_CONFIG_MISSING' }, 401, cors ?? {});
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) {
    return json({ ok: false, error: 'AUTH_REQUIRED' }, 401, cors ?? {});
  }

  if (!allowRequest(data.user.id)) {
    return json({ ok: false, error: 'RATE_LIMITED' }, 429, cors ?? {});
  }

  const raw = await request.text();
  if (raw.length > maxBodyBytes) {
    return json({ ok: false, error: 'BODY_TOO_LARGE' }, 413, cors ?? {});
  }
  let body: Record<string, unknown> = {};
  if (raw.trim() !== '') {
    try {
      const parsed = JSON.parse(raw);
      if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return json({ ok: false, error: 'INVALID_JSON' }, 400, cors ?? {});
      }
      body = parsed as Record<string, unknown>;
    } catch (_) {
      return json({ ok: false, error: 'INVALID_JSON' }, 400, cors ?? {});
    }
  }

  const storagePath = String(body.storage_path ?? body.image_path ?? '').trim();
  if (storagePath !== '') {
    const owner = storagePath.split('/').filter((part) => part !== '')[0] ?? '';
    if (owner !== data.user.id) {
      return json({ ok: false, error: 'IMAGE_OWNER_MISMATCH' }, 403, cors ?? {});
    }
  }

  if (Deno.env.get('VISUAL_SEARCH_ALLOW_MOCK') !== 'true') {
    return json({ ok: false, error: 'PRODUCTION_MOCK_DISABLED' }, 403, cors ?? {});
  }

  const fileName = String(body.file_name ?? '').toLowerCase();
  const jobType = String(body.job_type ?? 'combined');
  return json(analyze(fileName, jobType), 200, cors ?? {});
});

function allowRequest(userId: string): boolean {
  const now = Date.now();
  const recent = (hits.get(userId) ?? []).filter((stamp) => now - stamp < 60_000);
  if (recent.length >= maxPerMinute) {
    hits.set(userId, recent);
    return false;
  }
  recent.push(now);
  hits.set(userId, recent);
  return true;
}

function corsHeaders(origin: string | null): Record<string, string> | null {
  if (origin && !allowedOrigins.has(origin)) return null;
  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
  if (origin) headers['Access-Control-Allow-Origin'] = origin;
  return headers;
}

function json(body: unknown, status: number, cors: Record<string, string>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

function analyze(fileName: string, jobType: string) {
  if (fileName.includes('bos-sonuc') || fileName.includes('empty-result')) {
    return {
      summary: 'Bu görsel için eşleşme veya hasar bulunamadı.',
      confidence: 0.22,
      used_mock: true,
      damages: [],
      missing_parts: [],
      matches: [],
    };
  }
  if (jobType === 'visual_search') {
    return {
      summary: 'Görsele yakın ürünler listelendi.',
      confidence: 0.68,
      used_mock: true,
      damages: [],
      missing_parts: [],
      matches: [],
    };
  }
  return {
    summary: 'Mock analiz yalnız VISUAL_SEARCH_ALLOW_MOCK=true iken döner.',
    confidence: 0.5,
    used_mock: true,
    damages: [],
    missing_parts: [],
    matches: [],
  };
}
