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

const maxBodyBytes = 5 * 1024 * 1024; // 5 MB max response size
const requestTimeoutMs = 15000; // 15 seconds
const maxRedirects = 5;

// Forbidden IPv4 prefixes & metadata endpoints
const forbiddenIpPrefixes = [
  '0.',
  '10.',
  '127.',
  '169.254.', // RFC 3927 Link-local & Cloud Metadata (169.254.169.254)
  '192.168.',
  '192.0.2.', // TEST-NET-1
  '198.51.100.', // TEST-NET-2
  '203.0.113.', // TEST-NET-3
  '224.', // Multicast
  '240.', // Reserved
  '255.255.255.255',
];

function isPrivateOrForbiddenIp(ip: string): boolean {
  let trimmed = ip.trim().toLowerCase();

  // Strip brackets if IPv6
  if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
    trimmed = trimmed.substring(1, trimmed.length - 1);
  }

  // IPv6 loopback, unspecified, and local ranges
  if (
    trimmed === 'localhost' ||
    trimmed === '::' ||
    trimmed === '::1' ||
    trimmed.startsWith('fe80:') || // Link-local IPv6
    trimmed.startsWith('fc00:') || // Unique local address (RFC 4193)
    trimmed.startsWith('fd00:') || // Unique local address
    trimmed.startsWith('2001:db8:') || // Documentation
    trimmed.startsWith('64:ff9b:') // NAT64 prefix
  ) {
    return true;
  }

  // IPv4-mapped IPv6 (e.g. ::ffff:127.0.0.1 or ::ffff:169.254.169.254)
  if (trimmed.startsWith('::ffff:')) {
    const v4Part = trimmed.substring(7);
    if (v4Part.includes('.')) {
      return isPrivateOrForbiddenIp(v4Part);
    }
  }

  // Check IPv4 prefix blocks
  for (const prefix of forbiddenIpPrefixes) {
    if (trimmed.startsWith(prefix)) return true;
  }

  // RFC 1918: 172.16.0.0 - 172.31.255.255
  if (trimmed.startsWith('172.')) {
    const parts = trimmed.split('.');
    if (parts.length >= 2) {
      const second = parseInt(parts[1], 10);
      if (second >= 16 && second <= 31) return true;
    }
  }

  // RFC 6598: 100.64.0.0/10 (Carrier-Grade NAT)
  if (trimmed.startsWith('100.')) {
    const parts = trimmed.split('.');
    if (parts.length >= 2) {
      const second = parseInt(parts[1], 10);
      if (second >= 64 && second <= 127) return true;
    }
  }

  // RFC 2544: 198.18.0.0/15 (Benchmarking)
  if (trimmed.startsWith('198.')) {
    const parts = trimmed.split('.');
    if (parts.length >= 2) {
      const second = parseInt(parts[1], 10);
      if (second === 18 || second === 19) return true;
    }
  }

  // Alibaba Cloud metadata: 100.100.100.200
  if (trimmed === '100.100.100.200') return true;

  // Numeric decimal/hex IP evasion checks (e.g. 2130706433 or 0x7f000001)
  if (/^\d+$/.test(trimmed)) {
    const num = parseInt(trimmed, 10);
    const b1 = (num >>> 24) & 255;
    const b2 = (num >>> 16) & 255;
    const b3 = (num >>> 8) & 255;
    const b4 = num & 255;
    return isPrivateOrForbiddenIp(`${b1}.${b2}.${b3}.${b4}`);
  }

  return false;
}

function validateUrlSecurity(urlString: string): { valid: boolean; error?: string; url?: URL } {
  try {
    const parsed = new URL(urlString);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return { valid: false, error: 'Yalnızca HTTP ve HTTPS protokolleri desteklenir.' };
    }
    if (parsed.username || parsed.password) {
      return { valid: false, error: 'URL kimlik bilgisi (kullanıcı/şifre) içeremez.' };
    }
    const hostname = parsed.hostname.toLowerCase();
    if (
      hostname === 'localhost' ||
      hostname.endsWith('.local') ||
      hostname.endsWith('.internal') ||
      hostname.endsWith('.localhost') ||
      hostname.endsWith('.corp') ||
      hostname.endsWith('.onion') ||
      hostname === 'metadata.google.internal' ||
      hostname === 'instance-data'
    ) {
      return { valid: false, error: 'Yerel ve bulut metadata adreslerine erişim engellendi.' };
    }
    if (isPrivateOrForbiddenIp(hostname)) {
      return { valid: false, error: 'Özel IP ve bulut metadata adreslerine erişim engellendi.' };
    }
    return { valid: true, url: parsed };
  } catch (_) {
    return { valid: false, error: 'Geçersiz URL biçimi.' };
  }
}

function corsHeaders(origin: string | null): Record<string, string> {
  const headers: Record<string, string> = {
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, apikey, X-Client-Info',
  };
  if (origin && allowedOrigins.has(origin)) {
    headers['Access-Control-Allow-Origin'] = origin;
  } else {
    headers['Access-Control-Allow-Origin'] = '*';
  }
  return headers;
}

function jsonResponse(data: unknown, status = 200, origin: string | null = null): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(origin),
    },
  });
}

// Harici sitelerin (örn. anker-tr.com) SSL sertifikası uyuşmazlıkları (invalid peer certificate, NotValidForName vb.)
// nedeniyle taramanın durmaması için SSL doğrulama esnekliği sağlayan Deno HTTP client'ı
let customHttpClient: any = undefined;
try {
  // @ts-ignore: Deno runtime check
  if (typeof (Deno as any).createHttpClient === 'function') {
    // @ts-ignore
    customHttpClient = (Deno as any).createHttpClient({
      danger_accept_invalid_certs: true,
    });
  }
} catch (clientErr) {
  console.warn('Deno.createHttpClient başlatılamadı:', clientErr);
}

function isSslOrCertError(err: unknown): boolean {
  if (!(err instanceof Error)) return false;
  const msg = err.message.toLowerCase();
  return (
    msg.includes('invalid peer certificate') ||
    msg.includes('notvalidforname') ||
    msg.includes('certificate') ||
    msg.includes('ssl') ||
    msg.includes('tls') ||
    msg.includes('handshake')
  );
}

async function safeFetchWithSsrfProtection(
  targetUrl: string,
  redirectCount = 0
): Promise<{ status: number; html: string; finalUrl: string; contentType: string }> {
  if (redirectCount > maxRedirects) {
    throw new Error('Aşırı yönlendirme (redirect loop) tespit edildi.');
  }

  const check = validateUrlSecurity(targetUrl);
  if (!check.valid || !check.url) {
    throw new Error(check.error || 'Güvenlik doğrulaması başarısız.');
  }

  // Safe dual DNS resolve (both IPv4 'A' and IPv6 'AAAA')
  try {
    const [ipv4Result, ipv6Result] = await Promise.allSettled([
      Deno.resolveDns(check.url.hostname, 'A'),
      Deno.resolveDns(check.url.hostname, 'AAAA'),
    ]);

    const resolvedIps: string[] = [];
    if (ipv4Result.status === 'fulfilled') {
      resolvedIps.push(...ipv4Result.value);
    }
    // AAAA (IPv6) kaydı bulunamadığında (Deno NotFound hatası) fırlatılan exception'ı yakala ve IPv4 (A kaydı) varsa işlemi başarılı say
    if (ipv6Result.status === 'fulfilled') {
      resolvedIps.push(...ipv6Result.value);
    }

    for (const ip of resolvedIps) {
      if (isPrivateOrForbiddenIp(ip)) {
        throw new Error(`Alan adı (${check.url.hostname}) özel/yasaklı bir IP adresine çözümlendi: ${ip}`);
      }
    }
  } catch (dnsErr) {
    if (dnsErr instanceof Error && dnsErr.message.includes('özel/yasaklı bir IP')) {
      throw dnsErr;
    }
    // DNS çözümleme hatası (örneğin IPv6 kaydının bulunamaması) durumunda IPv4 varsa fetch aşamasına devam edilir
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), requestTimeoutMs);

  try {
    const fetchOptions: any = {
      method: 'GET',
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        'Sec-Ch-Ua': '"Chromium";v="124", "Google Chrome";v="124"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"macOS"',
      },
      redirect: 'manual', // Manually handle each redirect to inspect target URL and IP
      signal: controller.signal,
    };

    if (customHttpClient) {
      fetchOptions.client = customHttpClient;
    }

    let response: Response;
    try {
      response = await fetch(check.url.toString(), fetchOptions);
    } catch (primaryFetchErr) {
      if (fetchOptions.client && primaryFetchErr instanceof TypeError) {
        delete fetchOptions.client;
        response = await fetch(check.url.toString(), fetchOptions);
      } else {
        throw primaryFetchErr;
      }
    }

    clearTimeout(timeoutId);

    // Check for redirects
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get('Location');
      if (!location) {
        throw new Error('Yönlendirme konumu (Location) bulunamadı.');
      }
      const resolvedLocation = new URL(location, check.url).toString();
      return safeFetchWithSsrfProtection(resolvedLocation, redirectCount + 1);
    }

    if (response.status === 403 || response.status === 429) {
      throw new Error(`Site bot koruması nedeniyle doğrudan erişimi engelledi (${response.status}).`);
    }

    if (response.status === 401) {
      throw new Error('Erişim yetkisi reddedildi (401). Satıcı yetkisi veya API anahtarı gereklidir.');
    }

    if (response.status === 404) {
      throw new Error('Ürün sayfası bulunamadı (404). Lütfen URL adresini kontrol edin.');
    }

    if (!response.ok) {
      throw new Error(`Kaynak site HTTP ${response.status} hatası döndürdü.`);
    }

    const contentType = response.headers.get('content-type') ?? '';
    const contentLength = response.headers.get('content-length');
    if (contentLength && parseInt(contentLength, 10) > maxBodyBytes) {
      throw new Error('Kaynak sayfa boyutu izin verilen sınırı (5MB) aşıyor.');
    }

    const html = await response.text();
    if (html.length > maxBodyBytes) {
      throw new Error('Kaynak sayfa içeriği izin verilen sınırı (5MB) aşıyor.');
    }

    return {
      status: response.status,
      html,
      finalUrl: check.url.toString(),
      contentType,
    };
  } catch (err: unknown) {
    clearTimeout(timeoutId);

    // SSL / TLS / Peer Certificate Hatası Telafisi ve Otomatik 'www.' / 'http://' Yönlendirmesi
    if (isSslOrCertError(err)) {
      // 1. Taranacak URL'de 'www.' yoksa ve istek 'invalid peer certificate' veya SSL el sıkışma hatasıyla başarısız olursa:
      // Otomatik olarak hostname'in başına 'www.' ekle (örn: https://anker-tr.com/... -> https://www.anker-tr.com/...) ve isteği yeniden dene.
      if (!check.url.hostname.startsWith('www.') && !/^\d+\.\d+\.\d+\.\d+$/.test(check.url.hostname)) {
        try {
          const wwwUrl = new URL(check.url.toString());
          wwwUrl.hostname = `www.${check.url.hostname}`;
          return await safeFetchWithSsrfProtection(wwwUrl.toString(), redirectCount);
        } catch (wwwErr) {
          if (!isSslOrCertError(wwwErr)) {
            throw wwwErr;
          }
        }
      }

      // 2. Alternatif olarak SSL handshake hatasında, isteği 'http://' üzerinden gönderip sunucunun güvenli hedefe (301/302 Redirect) yönlendirmesini takip et.
      if (check.url.protocol === 'https:') {
        try {
          const httpUrl = new URL(check.url.toString());
          httpUrl.protocol = 'http:';
          return await safeFetchWithSsrfProtection(httpUrl.toString(), redirectCount);
        } catch (httpErr) {
          throw httpErr;
        }
      }
    }

    if (err instanceof Error) {
      if (err.name === 'AbortError') {
        throw new Error('Bağlantı zaman aşımına uğradı (15s). Kaynak site yanıt vermiyor.');
      }
      throw err;
    }
    throw new Error('Kaynak sayfa taranırken bilinmeyen bir hata oluştu.');
  }
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get('Origin');

  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders(origin) });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'METHOD_NOT_ALLOWED' }, 405, origin);
  }

  // 1. Auth check
  const authHeader = request.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ') || authHeader.trim() === 'Bearer') {
    return jsonResponse({ ok: false, error: 'AUTH_REQUIRED' }, 401, origin);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  if (!supabaseUrl || !anonKey) {
    return jsonResponse({ ok: false, error: 'SERVER_CONFIG_MISSING' }, 500, origin);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return jsonResponse({ ok: false, error: 'AUTH_INVALID' }, 401, origin);
  }

  // 2. Body check
  let body: { urls?: string[]; url?: string };
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ ok: false, error: 'INVALID_JSON_BODY' }, 400, origin);
  }

  const urls: string[] = [];
  if (Array.isArray(body.urls)) {
    urls.push(...body.urls);
  } else if (typeof body.url === 'string') {
    urls.push(body.url);
  }

  if (urls.length === 0) {
    return jsonResponse({ ok: false, error: 'URL_REQUIRED' }, 400, origin);
  }

  if (urls.length > 20) {
    return jsonResponse({ ok: false, error: 'Tek seferde en fazla 20 URL taranabilir.' }, 400, origin);
  }

  // 3. Process URLs with SSRF protection
  const results = [];
  for (const urlStr of urls) {
    try {
      const fetched = await safeFetchWithSsrfProtection(urlStr);
      results.push({
        url: urlStr,
        finalUrl: fetched.finalUrl,
        success: true,
        status: fetched.status,
        contentType: fetched.contentType,
        html: fetched.html,
      });
    } catch (fetchErr: unknown) {
      results.push({
        url: urlStr,
        success: false,
        error: fetchErr instanceof Error ? fetchErr.message : 'Tarama başarısız.',
      });
    }
  }

  return jsonResponse({ ok: true, results }, 200, origin);
});
