# Restaurant Ops Production Backbone

## Domain Schema

### Core entities

- `venue`
  - coklu sube ve coklu restoran destegi
- `table`
  - masa bazli runtime durum
  - `revision` alanı optimistic concurrency icin zorunlu
- `table_draft`
  - masa bazli garson workspace
  - `editing_check_id` ile aktif fis guncelleme akisi
- `draft_item`
  - UI local draft veya opsiyonel autosave draft snapshot
- `check`
  - mutfaga dusmus / aktif fis
- `check_item`
  - normalize siparis satirlari
- `partial_payment`
  - ara odeme ve kapanis odemesi
- `split_plan`
  - fis bolme ana kaydi
- `split_plan_part`
  - bolunmus odeme parcalari
- `customer`
  - masa / siparis bazli baglanabilen musteri
- `print_log`
  - adisyon / mutfak cikti izi
- `operation_log`
  - kritik her mutation icin denetlenebilir audit kaydi

### State separation

- `backend state`
  - sunucudan gelen canonical snapshot
  - `revision` ve `snapshotVersion` tasir
- `ui state`
  - secili masa, drawer/modaller, filtreler
  - local draft editleri ve henüz gonderilmemis degisiklikler
- `optimistic state`
  - backend snapshot uzerine gecici mutation uygulanmis gorunum
  - hata olursa rollback edilir

## Route Structure

```text
/waiter
/waiter/tables/[tableId]
/api/restaurant/snapshot
/api/restaurant/commands
```

## Mutation Strategy

### UI-local mutations

- `ADD_DRAFT_ITEM`
- `UPDATE_DRAFT_ITEM`
- `REMOVE_DRAFT_ITEM`
- `CLEAR_DRAFT`
- `LOAD_ORDER_INTO_DRAFT`

Bu aksiyonlar once UI workspace uzerinde ilerler. Kritik commit aninda ilgili draft payload backend'e gonderilir.

### Transaction-first mutations

- `SEND_DRAFT`
- `UPDATE_ORDER_ITEM`
- `REMOVE_ORDER_ITEM`
- `MOVE_ORDER_ITEMS`
- `ADD_PARTIAL_PAYMENT`
- `CLOSE_BILL`
- `TRANSFER_TABLE`
- `CREATE_SPLIT_PLAN`
- `ASSIGN_CUSTOMER`
- `CREATE_CUSTOMER_AND_ASSIGN`
- `REGISTER_PRINT`
- `NEW_BILL`

Bu aksiyonlar RPC veya transaction mantigina yakin server katmani uzerinden ilerler.

### Supabase RPC coverage

- `upsert_check_from_draft`
  - siparis gonder / siparis guncelle
- `update_check_item`
  - aktif siparis satiri duzenleme
- `remove_check_item`
  - aktif siparis satiri silme
- `move_check_items`
  - hareket aktar
- `take_partial_payment`
  - ara odeme / hesap kapama
- `transfer_table`
  - masa aktar
- `create_split_plan`
  - fis bol
- `assign_customer`
  - mevcut musteri sec
- `create_customer_and_assign`
  - yeni musteri olustur ve bagla
- `register_print_log`
  - yazdirma talebini kuyrukla

## Conflict Management

- Her masa satirinda `revision` tutulur.
- Client mutation gonderirken `expectedTableVersion` ve gerekirse `expectedTargetTableVersion` yollar.
- Sunucu `revision` farki yakalarsa `TABLE_VERSION_CONFLICT` doner.
- Client rollback yapar, en yeni snapshot ile state'i degistirir ve toast ile operatoru bilgilendirir.
- Onerilen ek adim:
  - Supabase Realtime presence ile masa bazli "kim acik" gostergesi
  - kritik drawer aksiyonlarinda "baran tablet-2 su an bu masada" uyarisi

## Optimistic Update + Rollback

1. Mutation local reducer ile gorunume uygulanir.
2. Aynı anda API route cagrilir.
3. Basariliysa canonical snapshot server cevabiyla yenilenir.
4. Basarisizsa:
   - conflict varsa server snapshot geri basilir
   - diger hata varsa onceki snapshot restore edilir
   - toast + retry firsati sunulur

## Retry Strategy

- store son basarisiz remote mutation'i saklar
- `retryLastMutation` guncel snapshot uzerinden yeni revision ile tekrar dener
- runtime panelinde `Son Islemi Tekrar Dene` aksiyonu cikar
- `Snapshot Yenile` aksiyonu operatorun canonical state'e hizli donmesini saglar

## Edge-case Rules

- taslak varken hesap kapatilamaz
- ara odeme kalan tutari gecemez
- dolu masaya `all` transfer yasak, `merge` veya `draft-only` zorunlu
- split plan toplami kalan tutarla birebir eslesmelidir
- ayni masa kaynak ve hedef olamaz
- yazdirma kaydi bos masa / bos siparis icin olusturulmaz

## Service Layer

- `RestaurantClientAdapter`
  - UI ile API veya local mock arasindaki adapter
- `RestaurantRepository`
  - server tarafinda mock veya Supabase implementasyonu
- `WaiterStoreProvider`
  - optimistic runtime, retry, rollback ve dirty-state takibi
