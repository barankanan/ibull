import { callRpc, getAuthedContext, jsonResponse, mapCaughtError, parseJson } from '../_shared/http.ts';

type DeliveryConfirmRequest = {
  order_id: string;
  quote_id: string;
  option_id: string;
  selected_branch_id?: string | null;
};

Deno.serve(async (req) => {
  try {
    const { user, userClient, serviceClient } = await getAuthedContext(req);
    const body = await parseJson<DeliveryConfirmRequest>(req);
    const { data: optionRows, error: optionError } = await serviceClient
      .from('delivery_options')
      .select(`
        id,
        quote_id,
        shipment_type,
        seller_delivery_fee,
        delivery_quotes!inner(
          id,
          seller_id,
          source
        )
      `)
      .eq('id', body.option_id)
      .eq('quote_id', body.quote_id)
      .limit(1);
    if (optionError) {
      throw optionError;
    }
    const option = (optionRows ?? [])[0] as Record<string, unknown> | undefined;
    if (!option) {
      return jsonResponse(
        {
          ok: false,
          error: 'delivery_option_not_found',
          message: 'Teslimat secenegi bulunamadi.',
        },
        404,
      );
    }

    const shipmentType = `${option.shipment_type ?? ''}`;
    const sellerFee = Number(option.seller_delivery_fee ?? 0);
    const rawQuote = option.delivery_quotes;
    const quote = Array.isArray(rawQuote)
      ? ((rawQuote[0] ?? {}) as Record<string, unknown>)
      : ((rawQuote ?? {}) as Record<string, unknown>);
    const source = `${quote.source ?? ''}`;
    const sellerId = `${quote.seller_id ?? ''}`;

    let walletReserve: Record<string, unknown> | null = null;
    let holdId = '';
    if (
      (shipmentType === 'ihiz_direct' || shipmentType === 'ihiz_to_branch') &&
      sellerFee > 0 &&
      sellerId.length > 0
    ) {
      const idempotencyKey = `hybrid:${body.order_id}:${body.option_id}`;
      const sourceType = source === 'ibul_checkout' ? 'ibul_internal' : 'external';

      const { data: walletData, error: walletError } = await userClient.rpc(
        'wallet_reserve_seller_delivery',
        {
          p_seller_id: sellerId,
          p_amount: sellerFee,
          p_reference_id: body.order_id,
          p_source_type: sourceType,
          p_idempotency_key: idempotencyKey,
          p_metadata: {
            quote_id: body.quote_id,
            option_id: body.option_id,
            shipment_type: shipmentType,
          },
        },
      );

      if (walletError) {
        return jsonResponse(
          {
            ok: false,
            error: 'wallet_reserve_failed',
            message: walletError.message,
          },
          409,
        );
      }
      walletReserve = (walletData as Record<string, unknown>) ?? { ok: true };
      if (walletReserve?.ok === false) {
        return jsonResponse(
          {
            ok: false,
            error: `${walletReserve.error ?? 'wallet_reserve_failed'}`,
            message: `${walletReserve.message ?? 'Satıcı cüzdan bakiyesi yetersiz.'}`,
            wallet_reserve: walletReserve,
          },
          409,
        );
      }
      holdId = `${walletReserve.hold_id ?? ''}`;
    }

    try {
      const confirmData = await callRpc<Record<string, unknown>>(
        serviceClient,
        'hybrid_delivery_confirm_option',
        {
          p_actor_user_id: user.id,
          p_order_id: body.order_id,
          p_quote_id: body.quote_id,
          p_option_id: body.option_id,
          p_selected_branch_id: body.selected_branch_id ?? null,
        },
      );

      if (walletReserve?.ok === true) {
        await serviceClient
          .from('orders')
          .update({ wallet_reserve_status: 'reserved' })
          .eq('id', body.order_id);
      }

      return jsonResponse({
        ok: true,
        data: {
          ...confirmData,
          wallet_reserve: walletReserve,
        },
      });
    } catch (confirmError) {
      if (holdId.length > 0) {
        await userClient.rpc('wallet_release_seller_delivery', {
          p_hold_id: holdId,
          p_idempotency_key: `release:${holdId}:${Date.now()}`,
          p_reason: 'delivery_confirm_rollback',
        });
      }
      throw confirmError;
    }
  } catch (error) {
    return mapCaughtError(error);
  }
});
