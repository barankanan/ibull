import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type RequestBody = { order_id: string; reason: string; details?: string };

Deno.serve(async (req) => {
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const body = await parseJson<RequestBody>(req);
    const data = await callRpc<Record<string, unknown>>(serviceClient, 'seller_ops.request_order_return', {
      p_actor_user_id: user.id,
      p_order_id: body.order_id,
      p_reason: body.reason,
      p_details: body.details ?? null,
    });
    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
