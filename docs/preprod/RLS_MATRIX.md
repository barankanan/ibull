# RLS MATRIX

| Resource | SELECT | INSERT | UPDATE | DELETE | Anon | Authenticated owner | Other user | Seller | Other seller | Admin | Live tested |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **users/profiles** | 🟢 | 🟢 | 🟢 | 🟢 | Denied | Allowed | Denied | - | - | Allowed | VERIFIED |
| **stores** | 🟢 | 🟢 | 🟢 | 🟢 | Allowed | Allowed | - | Allowed | Denied | Allowed | VERIFIED |
| **products** | 🟢 | 🟢 | 🟢 | 🟢 | Allowed | - | - | Allowed | Denied | Allowed | VERIFIED |
| **orders** | 🟢 | ⚠️ | 🔒 | 🟢 | Denied | VULNERABLE | Denied | Allowed | Denied | Allowed | FAIL (Risk Active) |
| **table_orders** | 🟢 | ⚠️ | ⚠️ | ⚠️ | Denied | VULNERABLE | VULNERABLE | VULNERABLE | VULNERABLE | Allowed | FAIL (Risk Active) |
| **vehicle_listings** | 🟢 | 🟢 | 🟢 | 🟢 | Allowed | Allowed | - | Allowed | Denied | Allowed | VERIFIED |
| **vehicle_reservations**| 🟢 | 🔒 | 🔒 | 🟢 | Denied | Allowed (RPC) | Denied | Allowed | Denied | Allowed | VERIFIED |
| **vehicle_kyc_documents**| 🟢 | 🟢 | 🟢 | 🟢 | Denied | Allowed | Denied | Allowed | Denied | Allowed | VERIFIED |
| **cart/favorites** | 🟢 | 🟢 | 🟢 | 🟢 | Denied | Allowed | Denied | - | - | Allowed | VERIFIED |
| **coupons/campaigns** | 🟢 | 🟢 | 🟢 | 🟢 | Allowed | - | - | Allowed | Denied | Allowed | VERIFIED |

*(Not: Tablolardaki yetkiler Supabase `db query` üzerinden canlı olarak doğrulanmıştır. `orders` tablosundaki Payment Bypass zafiyeti ve `table_orders` tablosundaki Public Insert/Update zafiyeti (⚠️) şu anda CANLIDA AÇIK durumdadır. Çözüm olarak `20241027120000_harden_orders.sql` migration dosyası hazırlanmış olup, canlıya uygulandığı an riskler (🔒) durumuna geçecektir.)*
