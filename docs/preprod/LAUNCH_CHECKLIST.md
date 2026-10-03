# LAUNCH_CHECKLIST.md — İBUL Production Launch Readiness Checklist (Strict Evidence Standard)
_Tarih: 2026-09-26 | Denetçi: Antigravity AI_

---

## 1. RELEASE VERDICT (İKİ SEVİYELİ DEĞERLENDİRME)

- **FULL COMMERCE PRODUCTION:** **NO** (Canlı PSP tahsilat altyapısı eksik; son binary senkronizasyonu bekleniyor)
- **PAYMENT-DISABLED PILOT:** **NO** (macOS süreç limiti nedeniyle taze derleme ve tarayıcı smoke testi bekliyor)
- **DEPLOY:** **NO** (Canlı dağıtım yapılmayacaktır)

---

## 2. KONTROL MADDELERİ VE DOĞRULAMA DURUMU

### A. Kod Kalitesi ve Kritik Testler
- [x] `flutter analyze --no-fatal-infos --no-fatal-warnings`: **0 error** (Zorunlu P0 sağlandı)
- [x] `test/web/web_boot_speed_hints_test.dart`: **7/7 PASSED** (Unit Test Pass)
- [x] `test/home/home_boot_core_test.dart`: **15/15 PASSED** (Unit Test Pass)
- [x] `test/home/home_viewport_section_test.dart`: **3/3 PASSED** (Widget Test Pass)
- [x] `test/app/web_click_routing_test.dart`: **9/9 PASSED** (Widget Test Pass)
- [ ] Tam Test Suite: Ortam kaynakları nedeniyle **BLOCKED BY ENVIRONMENT** (Kritik 34 test %100 geçti).

### B. Routing ve Navigasyon
- [x] `/home` → `/` canonical yönlendirmesi (Unit Test Pass)
- [x] `/hesabim/favoriler` sekme/URL uyumu (Unit Test Pass)
- [x] `/hesabim` genel bakış sekme/URL uyumu (Unit Test Pass)
- [x] `/hesabim/siparisler` sekme/URL uyumu (Unit Test Pass)
- [x] `/urun/:id/:slug` ürün detay URL uyumu (Unit Test Pass)
- [x] `/arac/:id/:slug` araç detay URL uyumu (Unit Test Pass)
- [x] Tarayıcı Back / Forward ve F5 Refresh rotası korunması (Unit Test Pass)
- [ ] Gerçek tarayıcı tıklama doğrulaması: **FRESH BROWSER E2E PENDING**

### C. Güvenlik ve İzolasyon
- [x] Secret Scan: `build/web-preprod-final` içinde private key / service_role = 0 (Automated Scan Pass)
- [x] Open Redirect Koruması: `next` parametresi tek `/` ile sınırlandırıldı (Code Review Pass)
- [ ] Kullanıcı Rol Koruması: BEFORE UPDATE trigger yazıldı (Code Review Pass / Live Test Not Verified)
- [ ] KYC Doküman Gizliliği: `auth.uid() = customer_id` RLS yazıldı (Code Review Pass / Live Access Not Verified)
- [ ] Cross-tenant İzolasyon: Müşteri/satıcı kısıtlamaları yazıldı (Code Review Pass / Live A/B Not Verified)
- [ ] Canlı Ödeme Sağlayıcısı (PSP): Hazır değil (**P0 BLOCKER for Full Commerce**)

### D. Performans ve Mimarisi
- [x] Phase 16 modüler ana sayfa mimarisi (Architecture Pass)
- [x] Viewport lazy-loading (`HomeViewportSection`) (Widget Test Pass)
- [ ] Taze kaynak kodlu binary üretimi: `scripts/build_web_prod.sh` (Ortam Bekliyor)
- [ ] Final binary üzerinde 5-run cold boot performans ölçümü (Ortam Bekliyor)

---

## 3. CANLIYA ÇIKIŞ ÖNCESİ ÇALIŞTIRILACAK TEK KOMUT DİZİSİ

```bash
# 1. Ortam temizliği sonrası taze derleme
bash scripts/build_web_prod.sh

# 2. Binary kopyalama ve hash doğrulaması
rm -rf build/web-preprod-final
cp -R ibul_app/build/web build/web-preprod-final
shasum -a 256 build/web-preprod-final/app.*.js build/web-preprod-final/index.html

# 3. Yerel sunucuyu açıp tarayıcı testini tamamla
python3 -m http.server 8088 --directory build/web-preprod-final

# 4. Yalnızca tüm E2E testler ve PSP sağlandıktan sonra (ŞU AN ASLA ÇALIŞTIRMAYIN):
# firebase deploy --only hosting:ibul --project ibul-ecommerce
```
