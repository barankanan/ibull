# PAYMENT-DISABLED PILOT READINESS

## Amaç
PSP (Iyzico vb.) entegre edilene kadar sistemin sadece Kapıda/Elden Ödeme mantığı ile (kredi kartı ödemesi tamamen kapalı) "Pilot" modda güvenli şekilde çalışabilmesini sağlamak.

## Durum
**PILOT RELEASE GATE:** BLOCKED (Canlı ortamdaki açıklar halen aktiftir, migration kodu hazırdır ancak uygulanmamıştır).

## Engelleyen Sorunlar (Blockers) ve Çözüm Aşamaları
1. **FAKE PAID PATH & PRICE TAMPERING**:
   - **Sorun**: `orders_user_insert` politikası ve `create_order_from_cart` içindeki kargo hesaplamasındaki zafiyetler sebebiyle müşteriler sahte siparişler ve sahte fiyatlar oluşturabiliyordu.
   - **Açık Doğrulandı mı?**: EVET (İşlem yapılabildiği kanıtlandı).
   - **Düzeltme Hazır mı?**: EVET (`20241027120000_harden_orders.sql`).
   - **Canlıya Uygulandı mı?**: HAYIR.

2. **TABLE ORDERS (GARSON EKRANI) AÇIĞI**:
   - **Sorun**: `table_orders` tablosu tüm `authenticated` kullanıcılara (tüm müşterilere dahil) `ALL` ve `INSERT` yetkisiyle açık bırakılmıştı. İstemci (Garson uygulaması) kodları incelendiğinde müşterilerin bu tabloya REST üzerinden doğrudan kayıt eklemediği, sadece yetkili satıcı/garsonların erişmesi gerektiği anlaşıldı.
   - **Açık Doğrulandı mı?**: EVET. (Politikaların `qual=true` olduğu canlı veritabanından çekilen RLS kuralları ile kanıtlandı).
   - **Düzeltme Hazır mı?**: EVET (Migration içinde `table_orders_seller_all` politikası yazılarak `auth.uid()::text = seller_id` koruması getirildi).
   - **Canlıya Uygulandı mı?**: HAYIR.

## Güvenli Operasyon Akışı (Pilot) - (Migration Uygulandıktan Sonraki Hedef Durum)
- **Müşteri (Checkout)**: Arayüzden siparişi verir, `create_order_from_cart` RPC'si üzerinden sunucuda `status = 'confirmed'` olarak oluşur. Kargo tutarı eksi girilemez.
- **Müşteri API Erişimi**: Kendi siparişini REST API ile görebilir ancak `UPDATE` yetkisi yoktur ve `INSERT` doğrudan yapılamaz (RPC'ye zorlanır). Müşteri hiçbir şekilde `status='paid'` yapamaz.
- **Satıcı/Kurye**: Sipariş teslim edildiğinde sadece satıcı/kurye siparişin durumunu `paid` veya `closed` olarak günceller (Sadece nakit/kapıda ödeme için. Kredi kartı ödemeleri için satıcılar bile yetkisizdir).
- **Garson (Masa Siparişleri)**: Garsonlar/Satıcılar, kendi `seller_id`lerine ait `table_orders` kayıtlarını sorunsuzca okur, günceller ve oluşturur. Diğer restoranlara veya normal müşterilere bu ekran kapalıdır.

## Canlıya Geçiş İçin Kalan Somut İşler
1. `20241027120000_harden_orders.sql` dosyasının canlı ortama uygulanması (`supabase db push` veya DB konsolu üzerinden).
2. Canlı ortama uygulandıktan sonra POSTMAN/cURL veya test JWT'leri ile bir kez daha doğrudan API istekleri atılarak, açıkların 401/403 veya Trigger Exception döndürdüğünün doğrulanması.

**KARAR:** Canlı uygulama tamamlanmadan pilot yayına çıkılması GÜVENSİZDİR.
