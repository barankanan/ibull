# Geofence Push Setup

## 1) Supabase SQL
Supabase SQL Editor'da çalıştır:

- `SUPABASE_GEOFENCE_PUSH.sql`

## 2) Flutter dependencies
Proje dizininde:

```bash
flutter pub get
```

## 3) Firebase Functions env
`ibul_app` dizininde:

```bash
firebase functions:config:set \
  supabase.url="https://YOUR_PROJECT.supabase.co" \
  supabase.service_role_key="YOUR_SUPABASE_SERVICE_ROLE_KEY"
```

veya yeni runtime env yaklaşımıyla deploy komutunda environment variable ver.

## 4) Functions dependencies
`ibul_app/functions` dizininde:

```bash
npm install
```

## 5) Deploy
`ibul_app` dizininde:

```bash
firebase deploy --only functions
```

Deploy edilen cron function: `sendNearbyInterestPush`  
Çalışma aralığı: `dakikada 1`

## 6) Çalışma mantığı
- Mobil uygulama:
  - FCM token'ı `push_device_tokens` tablosuna kaydeder.
  - Kullanıcı konumunu `user_live_locations` tablosuna yazar.
  - Arama/favori/sepet/kayıtlı liste terimlerini `user_product_interests` tablosuna senkronlar.
- Cloud Function cron:
  - Yakın konumdaki kullanıcıyı ve mağazaları eşleştirir (100 metre).
  - İlgili ürün terimi eşleşiyorsa FCM push gönderir.
  - Aynı kullanıcı + mağaza + ilgi tipi + ürün terimi için bildirimi yalnızca 1 kez gönderir.

## 7) Bildirime tıklama
Bildirim `storeName` data payload'ı ile gelir.  
Uygulama açılınca harita sayfası ilgili mağazaya yönlenir.
