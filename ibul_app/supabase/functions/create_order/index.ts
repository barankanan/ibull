// Legacy seller_ops edge. Not the marketplace checkout path.
// Flutter checkout calls public.create_marketplace_order directly.
// No Dart caller invokes this function. Do not deploy it while
// seller_ops.order_items.product_id is uuid and public.products.id is text.
// seller_ops.create_pending_order fails closed with
// SELLER_OPS_PRODUCT_ID_TYPE_MISMATCH.
import { callRpc, errorResponse, getAuthedContext, jsonResponse, mapCaughtError } from '../_shared/http.ts';

const moneyKeys = [
  'unit_price',
  'price',
  'subtotal',
  'subtotal_amount',
  'total',
  'total_amount',
  'total_price',
  'shipping_fee',
  'shipping_amount',
  'shipping',
  'discount',
  'discount_amount',
  'commission_rate',
  'payment_status',
  'order_status',
  'status',
  'paid',
];

Deno.serve(async (req) => {
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const raw = await req.text();
    if (raw.length > 65536) {
      return errorResponse('BODY_TOO_LARGE', 'İstek gövdesi çok büyük.', 413);
    }
    const body = raw.trim() === '' ? {} : JSON.parse(raw) as Record<string, unknown>;
    if (containsMoneyKey(body)) {
      return errorResponse(
        'CLIENT_PRICE_REJECTED',
        'Fiyat, kargo, indirim ve ödeme durumu istemciden kabul edilmez.',
        400,
      );
    }
    const items = Array.isArray(body.items) ? body.items : [];
    const safeItems = items.map((item) => {
      const row = item as Record<string, unknown>;
      return {
        product_id: row.product_id,
        quantity: row.quantity,
      };
    });
    const data = await callRpc<Record<string, unknown>>(
      serviceClient,
      'seller_ops.create_pending_order',
      {
        p_actor_user_id: user.id,
        p_seller_id: body.seller_id,
        p_items: safeItems,
        p_shipping_address: body.shipping_address ?? {},
        p_buyer_note: body.buyer_note ?? null,
        p_idempotency_key: body.idempotency_key ?? null,
      },
    );
    return jsonResponse({ ok: true, data });
  } catch (error) {
    return mapCaughtError(error);
  }
});

function containsMoneyKey(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(containsMoneyKey);
  if (value === null || typeof value !== 'object') return false;
  return Object.entries(value as Record<string, unknown>).some(([key, child]) => {
    return moneyKeys.includes(key) || containsMoneyKey(child);
  });
}
