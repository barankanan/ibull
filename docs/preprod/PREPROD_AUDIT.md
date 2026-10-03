# PREPROD_AUDIT.md — İBUL Final Pre-Production Audit (Strict Evidence Standard)
_Tarih: 2026-09-26 | Denetçi: Antigravity AI_

---

## 1. RELEASE VERDICT (İKİ SEVİYELİ DEĞERLENDİRME)

### A) FULL COMMERCE PRODUCTION: **NO**
- **Gerekçe:** Gerçek Ödeme Sağlayıcısı (PSP - iyzico/Stripe/PayTR) canlı tahsilat ve webhook imza altyapısı bulunmamaktadır (`SavedPaymentCardsService.isChargeProviderReady == false`).
- Kaynak kod ile test edilen binary hash'i henüz senkronize edilmemiştir (`home_initial_page.dart` değişikliği derleme sonrasıdır).

### B) PAYMENT-DISABLED PILOT: **NO**
- **Gerekçe:** Host işletim sistemindeki süreç tükenmesi (`fork/exec /bin/zsh: resource temporarily unavailable`) nedeniyle son kaynak kodu içeren fresh build ve tarayıcı smoke testi henüz tamamlanamamıştır.
- Canlı RLS ve KYC yetkilendirmesi canlı ortamda A/B kullanıcıları ile doğrulanmamıştır (Yalnızca Code Review Pass).

**DEPLOY:** **NO** (Canlı dağıtım yapılmayacaktır)

---

## 2. KANIT SEVİYESİNE GÖRE YENİDEN SINIFLANDIRMA

Mevcut denetimde hiçbir madde kanıtlanmadan "PASS" olarak işaretlenmemiştir:

| Denetim Alanı | Kanıt Seviyesi | Gerçek Durum |
|---|---|---|
| **RLS Politikaları** | CODE REVIEW PASS | Migration dosyaları incelendi; LIVE VERIFIED: **HAYIR** |
| **Cross-Account İzolasyonu** | CODE REVIEW PASS | Müşteri/satıcı ID kısıtlamaları mevcut; LIVE A/B TEST: **NOT VERIFIED** |
| **KYC Doküman Gizliliği** | CODE REVIEW PASS | `auth.uid() = customer_id` kuralı mevcut; LIVE ACCESS TEST: **NOT VERIFIED** |
| **Uncaught Exception Koruması** | FIX IMPLEMENTED | `catchError` ve `throwWithStackTrace` eklendi; FRESH BROWSER E2E: **PENDING** |
| **Hero Banner** | CODE PRESENT | `HomeInitialPage` içinde mevcut; FINAL BUILD E2E: **PENDING** |
| **Lazy Viewport Sections** | UNIT/WIDGET TEST PASS | `home_viewport_section_test.dart` 3/3 PASS; REAL BROWSER NETWORK TRIGGER: **PENDING** |
| **Web Routing (Click & State)** | UNIT/WIDGET TEST PASS | `web_click_routing_test.dart` 9/9 PASS; REAL BROWSER E2E: **PENDING** |
| **Secret Scan (Client Build)** | AUTOMATED SCAN PASS | `build/web-preprod-final` içinde service_role/private_key = 0 |
| **Auth Redirect (Open Redirect)** | CODE & LOGIC PASS | `customer_login_completion.dart` single `/` enforcement |
| **Ödeme (PSP) Güvenliği** | BLOCKED (P0) | Canlı ödeme sağlayıcısı yok; Tahsilatsız sipariş engeli aktif |

---

## 3. KAYNAK KOD VE DERLEME BİLGİSİ (BINARY IDENTITY)

- **Derlenen İlk Preprod Binary:** `build/web-preprod-final/app.17ee0fed1bbafb05.js`
  - SHA256: `c52c8adbf0134a541e3693cf609f8ef81f1b9723c868348b8ae8a6e26bb3f19a`
  - Derleme Zamanı: 18:03:00
- **Derleme Sonrası Kaynak Kod Değişikliği:**
  - `ibul_app/lib/screens/home/home_initial_page.dart` (Değişiklik Zamanı: 18:05:31)
  - `_setSelectedCategory` içine `debugPrint('[HomeInitialPage] openHub failed: $e')` eklendi.
- **Sonuç:** Kaynak kod ile derlenmiş binary arasında senkronizasyon farkı mevcuttur (**MATCH: NO**).
- **Kural:** Kaynak kod ile test edilen binary aynı olmadan SAFE PRODUCTION CANDIDATE = YES verilemez.

---

## 4. MACOS PROCESS EXHAUSTION (ORTAM ENGELİ)

- **Hata:** `error executing cascade step: CORTEX_STEP_TYPE_RUN_COMMAND: fork/exec /bin/zsh: resource temporarily unavailable`
- **Root Cause:** Önceki test suiteleri, subagentlar ve derleme süreçleri sonrasında macOS kullanıcı süreç limitine (`maxproc` / `RLIMIT_NPROC`) ulaşılmıştır. Terminal üzerinden basit `echo` veya `ps` komutları dahi fork edilememektedir.
- **Etki:** Fresh production build (`scripts/build_web_prod.sh`) ve headless Chrome browser smoke testinin çalıştırılması engellenmiştir.

---

## 5. STATİK ANALİZ VE DOĞRULANMIŞ TESTLER

### `flutter analyze --no-fatal-infos --no-fatal-warnings`
- **Errors:** **0** (Zorunlu P0 kriteri sağlandı)
- **Warnings:** 49 (Performans ve test yardımcı dosyalarındaki legacy importlar)
- **Infos:** 72

### Çalıştırılan ve Geçen Kritik Testler (34/34)
1. `test/web/web_boot_speed_hints_test.dart`: **7/7 PASSED**
2. `test/home/home_boot_core_test.dart`: **15/15 PASSED**
3. `test/home/home_viewport_section_test.dart`: **3/3 PASSED**
4. `test/app/web_click_routing_test.dart`: **9/9 PASSED**
- **Toplam Kritik Test:** **34/34 PASSED (%100)**
- **Geniş Test Suite:** Ortam süreç limiti nedeniyle BLOCKED BY ENVIRONMENT.

---

## 6. SİSTEM TOPARLANDIKTAN SONRA UYGULANACAK ADIMLAR

```bash
# 1. Askıda kalan süreçlerin temizlenmesi
killall -9 chromedriver dart flutter 2>/dev/null
pkill -f "python3 -m http.server" 2>/dev/null

# 2. Fresh Production Build (lib/main.dart)
bash scripts/build_web_prod.sh

# 3. Preprod klasörünü güncelle ve hash al
rm -rf build/web-preprod-final
cp -R ibul_app/build/web build/web-preprod-final
shasum -a 256 build/web-preprod-final/app.*.js build/web-preprod-final/index.html

# 4. Yerel sunucuyu başlat
python3 -m http.server 8088 --directory build/web-preprod-final

# 5. Tarayıcıda E2E Smoke & 5-Cold Run Lighthouse testini tamamla
```
