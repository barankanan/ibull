# Hybrid Delivery Backend (IBUL + IHIZ)

Bu paket, hibrit teslimat karar motorunu Supabase tarafinda calistirir.

## Eklenen SQL

- `ibul_app/supabase/migrations/20260306_hybrid_delivery_system.sql`
- Kopyasi: `SUPABASE_HYBRID_DELIVERY_SYSTEM.sql`

Icerik:
- `addresses`, `user_saved_addresses`, `seller_locations`
- `cargo_companies`, `cargo_branches`
- `delivery_quotes`, `delivery_options`
- `orders` tablosuna hibrit teslimat kolonlari
- RPC fonksiyonlari:
  - `hybrid_delivery_quote`
  - `hybrid_delivery_branch_search`
  - `hybrid_delivery_confirm_option`

## Eklenen Edge Functions

- `delivery_quote`
- `delivery_branch_search`
- `delivery_confirm`

## Deploy Komutlari

Asagidaki komutlar `ibul_app` dizininden calistirilir:

```bash
supabase login
supabase link --project-ref <PROJECT_REF>
supabase db push
supabase functions deploy delivery_quote
supabase functions deploy delivery_branch_search
supabase functions deploy delivery_confirm
```

## Function Cagrilari

### 1) delivery_quote

Request:

```json
{
  "source": "seller_external",
  "seller_id": "uuid",
  "customer_address": {
    "formatted_address": "Adres",
    "city": "Eskisehir",
    "district": "Odunpazari",
    "lat": 39.78,
    "lng": 30.52
  },
  "weather": "rain",
  "is_night": false,
  "surge_level": "medium",
  "payer_mode": "hybrid",
  "selected_company_id": null
}
```

### 2) delivery_branch_search

Request:

```json
{
  "company_id": "uuid",
  "origin_lat": 39.78,
  "origin_lng": 30.52,
  "city": "Eskisehir",
  "limit": 10
}
```

### 3) delivery_confirm

Request:

```json
{
  "order_id": "order-id-or-uuid",
  "quote_id": "uuid",
  "option_id": "uuid",
  "selected_branch_id": null
}
```

Donus:
- Secilen teslimat tipi order'a islenir.
- `ihiz_direct` / `ihiz_to_branch` ve `seller_delivery_fee > 0` ise wallet reserve zorunludur.
- Reserve basarisizsa endpoint `409` doner, secim onaylanmaz.
