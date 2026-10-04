import { callRpc, errorResponse, getAuthedContext, jsonResponse, mapCaughtError } from '../_shared/http.ts';

Deno.serve(async (req) => {
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const raw = await req.text();
    if (raw.length > 16384) {
      return errorResponse('BODY_TOO_LARGE', 'İstek gövdesi çok büyük.', 413);
    }
    const body = raw.trim() === '' ? {} : JSON.parse(raw) as Record<string, unknown>;
    if ('amount' in body || 'p_amount' in body || 'success' in body || 'p_success' in body) {
      return errorResponse(
        'CLIENT_REFUND_REJECTED',
        'İade tutarı ve başarı durumu istemciden kabul edilmez.',
        403,
      );
    }
    const returnId = body.return_id;
    if (typeof returnId !== 'string' || returnId.trim() === '') {
      return errorResponse('RETURN_ID_REQUIRED', 'İade kaydı gerekli.', 400);
    }
    const data = await callRpc<Record<string, unknown>>(
      serviceClient,
      'seller_ops.request_return_refund',
      {
        p_actor_user_id: user.id,
        p_return_id: returnId,
      },
    );
    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
