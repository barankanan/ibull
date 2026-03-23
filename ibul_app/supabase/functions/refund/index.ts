import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type RequestBody = {
  return_id: string;
  provider: string;
  provider_refund_id?: string;
  amount: number;
  success: boolean;
  raw?: Record<string, unknown>;
};

Deno.serve(async (req) => {
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const body = await parseJson<RequestBody>(req);
    const data = await callRpc<Record<string, unknown>>(serviceClient, 'seller_ops.refund_order_return', {
      p_actor_user_id: user.id,
      p_return_id: body.return_id,
      p_provider: body.provider,
      p_provider_refund_id: body.provider_refund_id ?? null,
      p_amount: body.amount,
      p_success: body.success,
      p_raw: body.raw ?? {},
    });
    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
