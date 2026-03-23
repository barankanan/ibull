import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type DeliveryBranchSearchRequest = {
  company_id: string;
  origin_lat: number;
  origin_lng: number;
  city?: string | null;
  limit?: number;
};

Deno.serve(async (req) => {
  try {
    const { serviceClient } = await getAuthedContext(req);
    const body = await parseJson<DeliveryBranchSearchRequest>(req);

    const data = await callRpc<Record<string, unknown>>(
      serviceClient,
      'hybrid_delivery_branch_search',
      {
        p_company_id: body.company_id,
        p_origin_lat: body.origin_lat,
        p_origin_lng: body.origin_lng,
        p_city: body.city ?? null,
        p_limit: body.limit ?? 10,
      },
    );

    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
