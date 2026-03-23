import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type RequestBody = {
  order_id: string;
  code: string;
  description: string;
  location?: string;
  occurred_at?: string;
  raw_payload?: Record<string, unknown>;
};

Deno.serve(async (req) => {
  try {
    const { serviceClient } = await getAuthedContext(req);
    const body = await parseJson<RequestBody>(req);
    const data = await callRpc<Record<string, unknown>>(serviceClient, 'seller_ops.ingest_shipment_event', {
      p_order_id: body.order_id,
      p_code: body.code,
      p_description: body.description,
      p_location: body.location ?? null,
      p_occurred_at: body.occurred_at ?? null,
      p_raw_payload: body.raw_payload ?? {},
    });
    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
