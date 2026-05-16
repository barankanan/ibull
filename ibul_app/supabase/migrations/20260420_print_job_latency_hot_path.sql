1. _getOrCreatePrintService(defaultUri)  // reusable dispatch client ÖNCEden yaratılır
2. svc.warmup()                          // /warmup çağrısı (font+USB+Pillow)
3. _warmPrinterConfigCache()             // DB printer config cacheYENİ TIMELINE (broadcast ile):
├─ A: RPC                               ~500ms
├─ B: Broadcast delivery                 ~100-200ms  ← WAL yerine direkt
├─ C: Hub claim (NON-BLOCKING)           ~0ms        ← .ignore()
├─ D: HTTP dispatch → USB write          ~2-3s       ← İLK denemede başarılı
└─ TOPLAM: 500 + 200 + 0 + 2500 = ~3.2s ✓

YENİ TIMELINE (broadcast yoksa, postgres_changes ile):
├─ A: RPC                               ~500ms
├─ B: Realtime delivery                  ~1-2s
├─ C: Hub claim (NON-BLOCKING)           ~0ms
├─ D: HTTP dispatch → USB write          ~2-3s       ← İLK denemede başarılı
└─ TOPLAM: 500 + 1500 + 0 + 2500 = ~4.5s