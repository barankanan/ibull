# PERFORMANCE_FINAL.md — İBUL Web Performance & Phase 16 Audit (Strict Evidence Standard)
_Tarih: 2026-09-26 | Denetçi: Antigravity AI_

---

## 1. MİMARİ VE DEFERRED LOADING KAZANIMLARI (PHASE 16)

1. **Açılış Ağının Ayrıştırılması (Decoupled Startup Graph):**
   - Monolitik `HomeScreenCore` (185 parça içeren yapı) başlangıç rotasından tamamen çıkarılmıştır.
   - `HomeInitialPage` üst görünümü (header, adres, hero) doğrudan yükler; ağır alt bileşenler (`commerce`, `discovery`, `vehicle`, `promotions`, `lower`) 5 ayrı modüle ayrılmıştır.
   - **Kanıt Seviyesi:** Architecture Verified & Code Review Pass.

2. **Home Viewport Lazy Loading:**
   - `HomeViewportSection` widget'ı ile scroll mesafesine (1.25 viewport) duyarlı yükleme sağlanmıştır.
   - İlk açılışta gereksiz veri çekimi engellenmiştir.
   - **Kanıt Seviyesi:** Widget Test 3/3 Pass (`test/home/home_viewport_section_test.dart`). Gerçek tarayıcı waterfall doğrulaması ise taze derleme sonrası **PENDING**.

3. **Runtime Uncaught Crash Koruması:**
   - `loadLibrary()` çağrılarına `.catchError` ve `Error.throwWithStackTrace` eklenerek unhandled promise rejection / `Uygulama kodu yüklenemedi: Uncaught` riski ortadan kaldırılmıştır.
   - **Kanıt Seviyesi:** Fix Implemented. Taze binary üzerinde tarayıcı doğrulaması **PENDING**.

4. **Hero Banner & Speed Index:**
   - Hero banner senkron bellek önbelleğinden (`readCachedUrlsSync`) ilk karede okunup çizilmekte; ardından `HomeHeroBannersFetch.fetch()` ile asenkron yenilenmektedir.
   - **Kanıt Seviyesi:** Code Present. Final build E2E doğrulaması **PENDING**.

---

## 2. DERLEME METRİKLERİ VE KARŞILAŞTIRMA

| Metrik | Önceki Durum | Phase 16 Hedefi | Mevcut Durum |
|---|---|---|---|
| **Startup Home Deferred Parts** | 185 parça | 0 parça | 0 parça (Mimari korundu) |
| **Açılış İstek Sayısı** | Yüksek | ~16–25 | Taze 5-run ölçümü bekleniyor |
| **Largest Task Süresi** | Yüksek | <500 ms | Taze 5-run ölçümü bekleniyor |
| **Total Blocking Time (TBT)** | Yüksek | <1.0 s | Taze 5-run ölçümü bekleniyor |
| **Speed Index** | Yüksek | <5.5 s | Taze 5-run ölçümü bekleniyor |
| **Fingerprinted JS** | Standart | `app.<hash>.js` | `app.17ee0fed1bbafb05.js` (Eski artefact, yenisi derlenecek) |

---

## 3. FINAL 5-COLD RUN TALİMATI

Host işletim sistemindeki süreç limiti temizlendikten sonra taze derleme (`lib/main.dart`) ile Lighthouse CLI üzerinden 5-run cold boot testi çalıştırılmalıdır:

```bash
# Taze derleme
bash scripts/build_web_prod.sh
rm -rf build/web-preprod-final
cp -R ibul_app/build/web build/web-preprod-final

# Yerel sunucu
python3 -m http.server 8088 --directory build/web-preprod-final

# 5-run Lighthouse testi
for i in {1..5}; do
  lighthouse http://localhost:8088/ --output=json --output-path=docs/preprod/run_$i.json --chrome-flags="--headless"
done
```
