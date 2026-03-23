import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type DeliveryQuoteRequest = {
  source: 'ibul_checkout' | 'seller_external';
  seller_id: string;
  customer_address: {
    formatted_address?: string;
    city?: string;
    district?: string;
    lat?: number | string;
    lng?: number | string;
    latitude?: number | string;
    longitude?: number | string;
    place_id?: string;
    label?: string;
    is_default?: boolean;
  };
  weather?: 'clear' | 'rain' | 'storm' | 'snow';
  is_night?: boolean;
  surge_level?: 'normal' | 'medium' | 'high';
  payer_mode?: 'customer_pays' | 'seller_pays' | 'hybrid';
  selected_company_id?: string | null;
};

Deno.serve(async (req) => {
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const body = await parseJson<DeliveryQuoteRequest>(req);

    const data = await callRpc<Record<string, unknown>>(
      serviceClient,
      'hybrid_delivery_quote',
      {
        p_actor_user_id: user.id,
        p_source: body.source,
        p_seller_id: body.seller_id,
        p_customer_address: body.customer_address,
        p_weather: body.weather ?? 'clear',
        p_is_night: body.is_night ?? false,
        p_surge_level: body.surge_level ?? 'normal',
        p_payer_mode: body.payer_mode ?? 'seller_pays',
        p_selected_company_id: body.selected_company_id ?? null,
      },
    );

    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
