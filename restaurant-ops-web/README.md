# Garson Operasyon Sistemi

Bu klasor, restoran garson akisi icin `Next.js + TypeScript + Tailwind CSS` tabanli ayrik bir operasyon modulu icerir.

## Current Scope

- route bazli waiter ekranlari: `/waiter` ve `/waiter/tables/[tableId]`
- admin print queue ekrani: `/admin/system/printers`
- UI-local draft workspace
- optimistic runtime + rollback
- retryable mutation runtime
- mock repository ile calisan API routes
- Supabase repository ve migration omurgasi
- operation log / print log / split plan / payment / transfer transaction tasarimi
- aktif siparis guncelleme ve hareket aktar RPC omurgasi
- siparis gonderiminde otomatik adisyon print job olusumu

## Key Files

- `src/components/RestaurantWaiterApp.tsx`
  - route ile senkron secili masa, UI runtime ve kritik mutation tetikleyicileri
- `src/state/waiter-store.tsx`
  - backend snapshot ve UI-local state ayrimi
  - optimistic update + rollback + retry yuzeyi
- `src/features/restaurant/domain/`
  - backend uyumlu tipler, mutation sozlesmeleri ve saf reducer
- `src/features/restaurant/data/`
  - mock repository, client adapter, Supabase repository
- `src/app/api/restaurant/*`
  - snapshot ve mutation route katmani
- `supabase/migrations/20260406_restaurant_ops_foundation.sql`
  - tablo ve RPC omurgasi
- `docs/restaurant-ops-architecture.md`
  - domain schema, conflict ve optimistic strateji

## Calistirma

```bash
npm install
npm run dev
```

## Backend Mode

```bash
# mock repository + API
RESTAURANT_DATA_SOURCE=mock

# Supabase repository
RESTAURANT_DATA_SOURCE=supabase
NEXT_PUBLIC_SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
RESTAURANT_VENUE_ID=...
```
