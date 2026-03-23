import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type CreateOrderRequest = {
  seller_id: string;
  payment_provider: string;
  provider_payment_id?: string;
  currency?: string;
  subtotal: number;
  shipping_fee?: number;
  commission_rate?: number;
  shipping_address: Record<string, unknown>;
  buyer_note?: string;
  items: Array<Record<string, unknown>>;
};

Deno.serve(async (req) => {
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const body = await parseJson<CreateOrderRequest>(req);
    const data = await callRpc<Record<string, unknown>>(serviceClient, 'seller_ops.create_paid_order', {
      p_actor_user_id: user.id,
      p_seller_id: body.seller_id,
      p_payment_provider: body.payment_provider,
      p_provider_payment_id: body.provider_payment_id ?? null,
      p_currency: body.currency ?? 'TRY',
      p_subtotal: body.subtotal,
      p_shipping_fee: body.shipping_fee ?? 0,
      p_commission_rate: body.commission_rate ?? 0.12,
      p_shipping_address: body.shipping_address,
      p_buyer_note: body.buyer_note ?? null,
      p_items: body.items,
    });
    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});
