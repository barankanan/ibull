import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type RequestBody = { order_id: string; note?: string };

Deno.serve(async (req) => {
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const body = await parseJson<RequestBody>(req);
    const data = await callRpc<Record<string, unknown>>(serviceClient, 'seller_ops.mark_order_preparing', {
      p_actor_user_id: user.id,
      p_order_id: body.order_id,
      p_note: body.note ?? null,
    });
    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
