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

## 2026-11-25 00:04 — ikinci otonom oturum (kod değişikliği yok)

- **Yapılan:** kural dosyası uygulandı; madde 1'deki fast-forward ile hedef/günlük belgeleri alındı (6bc6f06).
- **Doğrulama (PASS):** adisyon_payments_loader + garson_quantity_line_total + lan_offline_delay_budget = 24/24 (HEAD e0f4976).
- **Neden kod yok:** Aşama 1'de kalan işlerin tümü kullanıcı/fiziksel cihaz gerektiriyor; disk boş alanı 1,7 GB (<10 GB) → derleme yok; çalışan stage1d uygulaması dokunulmadan bırakıldı. Tek güvenli işi seçecek kanıtlı bir hata bulunamadı.
- **BLOCKED:** garson kimliği migration onayı; iPhone/WAN/Ethernet yazıcı testleri; disk temizliği (CLEANUP onayı).
- **Sıradaki:** disk açılınca Mac Release gerçek ekran doğrulaması; öncelik 3 için order_service.dart unit_price temizleme (satır ~3791-3828) denetimi.

## 2026-11-25 (gündüz) — interaktif oturum, P0-00 denetimi (kod değişikliği yok)

- **Durum:** HEAD 90b76bb (dal claude/ibul-restaurant-completion-e60b65). Ana klasörde 248 commit'siz dosya var, dokunulmadı. Disk %97, 381 MB boş → derleme yok.
- **Doğrulama (PASS):** adisyon_payments_loader + garson_quantity_line_total + lan_offline_delay_budget + printer_readiness (12/12, tek durum kaynağı) + adisyon_line_edit = 43/43.
- **Denetim:** `order_service.dart` `_normalizeExternalCargoProductLines` (satır 3791-3828) e-ticaret kargo yolu; birim fiyat adede bölünmüyor, restoran akışıyla ilgisi yok → hata yok, kod değişmedi.
- **P0-01..P0-07:** kod tarafı önceki oturumlarda PASS/NOT VERIFIED; kalanlar fiziksel iPhone/WAN/Ethernet yazıcı ve üretim migration onayı (BLOCKED, bkz. SELLER_WEEKLY_GOALS.md).
- **Aşama 2 (P1+) kilitli:** kullanıcı onayı yok, başlanmadı.
- **Sıradaki:** disk ≥10 GB olunca Mac Release gerçek ekran doğrulaması; CLEANUP onayı (docs/CLEANUP_CANDIDATES.md henüz yok).
