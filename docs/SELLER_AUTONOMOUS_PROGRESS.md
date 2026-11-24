# İBUL Satıcı — Otonom Çalışma Günlüğü

Ayrıntılı kanıt: `docs/RESTAURANT_PILOT_PROGRESS.md`. Tamamlanan işler burada yeniden açılmaz.

## 2026-11-24 (gece) — ilk otonom oturum

- **Durum:** HEAD `e0f4976` (offline sipariş ~45 sn gecikmesi: 3 sn sınırlı personel yoklaması + yazıcı bulut okumaları `RestaurantCloudGate`'e bağlı). Bu commit `RESTAURANT_PILOT_PROGRESS.md` içinde henüz yok.
- **Çakışma:** Başka bir oturum `ibul-restaurant-completion-e60b65` çalışma ağacında macOS Release derlemesi yürütüyor (`~/IBUL_isolated_build/flutter-build-stage1f`). İkinci derleme BAŞLATILMADI, o ağaca dokunulmadı.
- **Disk:** 6,2 GB boş (yeni Flutter/Xcode derlemesi için yetersiz → derleme yok).
- **Doğrulama (PASS):** `lan_offline_delay_budget_test` + `garson_quantity_line_total_test` + `adisyon_payments_loader_test` = 24/24; `flutter analyze` (e0f4976'nın 3 lib dosyası) sorun yok.
- **Ortam notu:** Yeni çalışma ağaçlarında `ibul_app/lib/core/config/generated_runtime_config.g.dart` (gitignore'lu, anahtar içerir) yoktur ve testler derlenmez. Yerel çözüm: `generated_runtime_config_stub.dart` dosyasını `.g.dart` adıyla kopyala (anahtarsız; Git'e girmez). Anahtarı `strings` ile çıkarma.
- **BLOCKED / onay gerektiren:** garson kimliği üretim migration'ı; fiziksel iPhone/WAN/yazıcı testleri.
- **Yarın ilk görev:** diğer oturumun stage1f derlemesi bittikten sonra Mac Release gerçek ekran doğrulaması; `e0f4976` için WAN-kesik gerçek ölçümün (kullanıcı evdeyken) belgelenmesi.
