# Temizlik Adayları (SİLİNMEDİ — kullanıcı onayı bekliyor)

Ölçüm tarihi: 2026-11-25. Disk: 460 GB, boş ~0,4 GB (%97). Hiçbir şey silinmedi; yalnız boyut ölçüldü.
Hedef: Flutter/Xcode derlemesi için ≥10 GB boş.

| # | Yol | Boyut | Neden gereksiz olabilir | Silinirse ne kaybolur | Risk |
|---|-----|-------|--------------------------|------------------------|------|
| 1 | `~/Library/Developer/CoreSimulator/Caches` | 10 GB | Simülatör önbelleği, yeniden üretilir | Yalnız ilk simülatör açılışı yavaşlar | Düşük |
| 2 | `~/Library/Developer/Xcode/DerivedData` | 2,1 GB | Xcode ara derleme çıktısı | Sonraki derleme tam yeniden derlenir | Düşük |
| 3 | `~/Library/Caches/Google` (Chrome önbelleği) | 9,6 GB | Tarayıcı önbelleği (İBUL dışı) | Tarayıcı sayfaları yeniden iner | Düşük |
| 4 | `~/IBUL_isolated_build/flutter-build` | 8,7 GB | Eski izole derleme klasörü | Eski derleme çıktısı; kaynak kodda kayıp yok | Orta: hangisi güncel teyit et |
| 5 | `~/IBUL_isolated_build/flutter-build-stage1c` (+ `flutter_build_cache_aside_stage1c`, `hooks_objective_c_cache_stage1c_aside`) | 2,6 GB + 0,7 GB | Aşama 1c derlemesi, 1d/1f ile aşıldı | Eski derleme; belgede ekran kanıtı kayıtlı | Düşük |
| 6 | `~/IBUL_isolated_build/flutter-build-stage1d` | 6,7 GB | Çalışan uygulama bu derlemeden olabilir (günlük: "çalışan stage1d") | Çalışan uygulama bozulabilir | YÜKSEK: önce çalışan sürecin yolunu kontrol et |
| 7 | `~/IBUL_isolated_build/flutter-build-stage1f` | 5,7 GB | En yeni derleme | Mac Release doğrulaması için gerekli | Silme |
| 8 | `~/Library/Developer/Xcode/iOS DeviceSupport` | 5,5 GB | Eski iOS sürümlerinin cihaz sembolleri | Cihaz yeniden bağlanınca yeniden indirilir | Düşük |
| 9 | `~/.npm` | 9,7 GB | npm önbelleği | Paketler yeniden iner | Düşük |
| 10 | `~/.gradle` | 11 GB | Gradle önbelleği | Android derlemesinde yeniden iner | Düşük |
| 11 | `~/Library/Developer/CoreSimulator/Devices` | 19 GB | Kullanılmayan simülatör cihazları (`xcrun simctl delete unavailable`) | O cihazlardaki uygulama verisi | Orta |
| 12 | `~/Library/Caches/com.spotify.client`, `*.ShipIt`, Opera, Firefox | ~5 GB | Üçüncü taraf uygulama önbellekleri | Yeniden oluşur | Düşük |
| 13 | `.claude/worktrees/ibul-restaurant-completion-e60b65` (ibul_app/build) | 2,9 GB | Aktif worktree | — | Silme |

Önerilen sıra (≈25 GB, düşük risk): 1, 2, 3, 8, 9, 10, 5. Madde 6 ve 7 silinmez; 4 için hangi derlemenin güncel olduğu doğrulanmalı.
Silme komutlarını yalnız kullanıcı onayından sonra çalıştır.
