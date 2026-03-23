import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type RequestBody = { order_id: string };

Deno.serve(async (req) => {
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const body = await parseJson<RequestBody>(req);
    const data = await callRpc<Record<string, unknown>>(serviceClient, 'seller_ops.seller_accept_order', {
      p_actor_user_id: user.id,
      p_order_id: body.order_id,
    });
    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
