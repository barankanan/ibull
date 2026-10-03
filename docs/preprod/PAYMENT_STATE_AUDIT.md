# PAYMENT STATE AUDIT

## Durum Özeti
**Payment Bypass / Price Tampering Eksikliği:** FAKE PAID PATH PROVEN (Açık canlıda doğrulandı, risk devam ediyor).

## Bulgu Detayları
1. **Pilot Mod (Payment-Disabled)**: Müşteri arayüzünde "Kredi Kartı" seçeneği kapalı (`isChargeProviderReady = false`). Siparişler UI üzerinden her zaman RPC üzerinden (`create_order_from_cart`) `status='confirmed'` olarak başlatılıyor. Ancak bu, API seviyesindeki zafiyeti engellemiyor.
2. **REST API Açığı (Fake Paid Path)**: `orders` tablosundaki `orders_user_insert` politikası, müşterilerin (authenticated role) doğrudan tabloya veri eklemesine izin veriyordu (`with_check = (auth.uid() = user_id)`).
3. **RPC Fiyat Manipülasyonu**: `create_order_from_cart` fonksiyonu, `p_shipping_amount` (Kargo tutarı) değerini doğrudan istemciden alıyor ve hiçbir sınırlandırma olmadan (`greatest(0, ...)` kontrolü olmadan) `total_amount` toplamına ekliyordu. İstemci kargo tutarını `-100` göndererek siparişin toplam tutarını düşürebilir.

## Exploit Kanıtı ve Rol Testi
- **Açık Doğrulandı mı?**: EVET. 
- Müşterinin `authenticated` yetkisiyle (`set local role authenticated;` kullanarak, Supabase'deki default `BYPASSRLS = false` özelliği güvence altına alınarak) doğrudan `orders` tablosuna `status = 'paid'` olan sahte bir sipariş eklenebildiği görülmüştür.
- Test, canlı veritabanında bir transaction (`BEGIN; ... ROLLBACK;`) içerisinde yapıldığı için kalıcı bir kayıt veya yan etki (mutfak fişi, vb.) oluşmamış ve kalıntılar canlı veritabanından silinmiştir.

## Hardening (Sertleştirme) Çözümü ve Süreci
- **Düzeltme Hazır mı?**: EVET. `20241027120000_harden_orders.sql` migration dosyası oluşturuldu.
- **Test Ortamında Doğrulandı mı?**: HAYIR. (Yerel/Staging ortamında Docker eksikliği sebebiyle Supabase CLI çalıştırılamadığı için test edilemedi. İncelemeler kod ve SQL analizi üzerinden yapıldı).
- **Canlıya Uygulandı mı?**: HAYIR. (Talepler doğrultusunda canlıya müdahale edilmedi).
- **Canlı Uygulama Sonrası Doğrulandı mı?**: HAYIR.

### Çözüm İçeriği (Migration)
1. `orders_user_insert` politikası silinir (İstemciler sadece güvenli RPC kullanmak zorundadır).
2. `orders_status_guard` adında bir BEFORE INSERT/UPDATE trigger'ı eklenir. `payment_method = 'card'` olan siparişlerin herhangi bir kullanıcı (müşteri, satıcı, kurye) tarafından REST API üzerinden `paid` yapılması engellenir.
3. Müşterilerin kendi siparişini hiçbir ödeme türünde (nakit/kart) `paid` olarak güncellemesi kesinlikle engellenir.
4. `create_order_from_cart` RPC'si güncellenerek, müşteriden gelen `p_shipping_amount` parametresine `greatest(0, ...)` koruması eklenmiştir. Fiyat hesaplaması zaten sunucudaki `products` tablosuna dayandığı için toplamlar artık tamamen güvenlidir.

## Sonuç
**SECURITY TEST RESULT:** FAIL (Zafiyet devam ediyor).
**RELEASE GATE:** BLOCKED (Migration oluşturuldu, ancak canlıya uygulanması bekleniyor).
