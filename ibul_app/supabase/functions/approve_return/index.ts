import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type RequestBody = { return_id: string; approve: boolean; note?: string };

Deno.serve(async (req) => {
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const body = await parseJson<RequestBody>(req);
    const data = await callRpc<Record<string, unknown>>(serviceClient, 'seller_ops.approve_order_return', {
      p_actor_user_id: user.id,
      p_return_id: body.return_id,
      p_approve: body.approve,
      p_note: body.note ?? null,
    });
    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
