# Ads Manager Module

## Klasor Yapisi

- `constants`: tablo adlari ve varsayilan reklam ayarlari
- `enums`: kampanya tipi, hedef, placement, rol ve cuzdan enumlari
- `helpers`: JSON parse, hedef-oneri ve metrik/health hesaplayicilari
- `models`: Supabase tablolarina hazir null-safe veri modelleri
- `preview`: tablo eksiginde devreye giren mock/preview data source
- `repositories`: Supabase + preview fallback veri erisim katmani
- `services`: seller/admin akislari icin is mantigi

## Hizli Baslangic

```dart
final adsService = AdsService();
final sellerDashboard = await adsService.getSellerDashboard(
  sellerId: 'seller-1',
);

final products = await adsService.getSponsoredProducts(
  placement: AdPlacement.homeFeed,
  userId: 'user-1',
  cityCode: 'IST',
);
```

## Entegrasyon Noktalari

- Seller paneli: `AdsService.getSellerDashboard()` + `CampaignService`
- Admin reklam merkezi: `AdsService.getAdminDashboard()` + `CampaignReviewService`
- Home/search/map feed ranking: `AdsService.getPlacementResults()`
- Event tracking: `AdMetricsService.trackUserEvent()`
- Geofence tetikleme: `GeofenceService.getEligibleTriggers()`
- Gelir ve bakiye alani: `AdRevenueService.getRevenueOverview()` ve `AdWalletService`

## Supabase Hazirligi

- Canli tablolar hazir oldugunda `AdsRepository` ayni metodlarla Supabase'a dogrudan yazar/okur.
- Tablolar veya iliskiler eksikse repository otomatik olarak `preview/ads_preview_data_source.dart` fallback'ine duser.
- Kampanya read path'i iliski olarak `campaign_targets`, `campaign_assets` ve `ab_test_variants` bekler.
