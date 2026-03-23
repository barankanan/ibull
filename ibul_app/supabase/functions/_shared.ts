import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

export async function createClients(req: Request) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const authHeader = req.headers.get('Authorization') ?? ''
  const token = authHeader.replace('Bearer ', '').trim()

  if (!token) {
    throw new Error('AUTH_TOKEN_MISSING')
  }

  const admin = createClient(supabaseUrl, serviceRoleKey)
  const { data: authData, error: authError } = await admin.auth.getUser(token)
  if (authError || !authData.user) {
    throw new Error('AUTH_INVALID_TOKEN')
  }

  return { admin, user: authData.user }
}
