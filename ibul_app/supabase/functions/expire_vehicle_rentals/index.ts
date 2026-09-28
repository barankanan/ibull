import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: { 'Access-Control-Allow-Origin': '*' },
    });
  }
  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const cronSecret = Deno.env.get('EXPIRE_RENTALS_SECRET') ?? '';
  const auth = req.headers.get('Authorization') ?? '';
  const headerSecret = req.headers.get('x-cron-secret') ?? '';
  const allowed =
    (serviceKey !== '' && auth === `Bearer ${serviceKey}`) ||
    (cronSecret !== '' &&
      (auth === `Bearer ${cronSecret}` || headerSecret === cronSecret));
  if (!allowed) {
    return new Response(JSON.stringify({ ok: false, error: 'forbidden' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  const client = createClient(url, serviceKey);
  const { data, error } = await client.rpc('expire_unpaid_vehicle_rentals');
  if (error) {
    return new Response(
      JSON.stringify({ ok: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
  return new Response(JSON.stringify(data ?? { ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
