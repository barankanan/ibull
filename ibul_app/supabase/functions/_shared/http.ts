import { createClient, SupabaseClient, User } from 'jsr:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

export type AuthedContext = {
  user: User;
  userClient: SupabaseClient;
  serviceClient: SupabaseClient;
};

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

export function errorResponse(code: string, message: string, status = 400, details?: unknown) {
  return jsonResponse({ ok: false, error: { code, message, details } }, status);
}

export async function getAuthedContext(req: Request): Promise<AuthedContext> {
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    throw new Error('AUTH_HEADER_MISSING');
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) {
    throw new Error('UNAUTHORIZED');
  }

  return {
    user: data.user,
    userClient,
    serviceClient,
  };
}

export async function parseJson<T>(req: Request): Promise<T> {
  try {
    return await req.json() as T;
  } catch (_) {
    throw new Error('INVALID_JSON');
  }
}

export function mapCaughtError(error: unknown) {
  if (error instanceof Error) {
    switch (error.message) {
      case 'AUTH_HEADER_MISSING':
        return errorResponse('AUTH_HEADER_MISSING', 'Authorization header bulunamadı.', 401);
      case 'UNAUTHORIZED':
        return errorResponse('UNAUTHORIZED', 'JWT doğrulanamadı.', 401);
      case 'INVALID_JSON':
        return errorResponse('INVALID_JSON', 'İstek gövdesi geçerli JSON değil.', 400);
      default:
        return errorResponse('UNHANDLED_ERROR', error.message, 400);
    }
  }
  return errorResponse('UNHANDLED_ERROR', 'Bilinmeyen hata oluştu.', 400);
}

export async function callRpc<T>(client: SupabaseClient, fn: string, params: Record<string, unknown>) {
  const { data, error } = await client.rpc(fn, params);
  if (error) {
    throw new Error(`${fn}:${error.message}`);
  }
  return data as T;
}
