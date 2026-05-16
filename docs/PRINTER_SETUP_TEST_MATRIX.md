# Yazıcı Kurulum Sistemi — Test Matrisi (Mac + Windows)

Bu doküman, yazıcı ekleme/kurulum akışını production seviyesine taşımak için **otomatik test kapsamını** ve **manuel QA checklist**’ini tek yerde toplar.

## Kapsam ve bileşenler

### Flutter (UI + orchestrator)

- `ibul_app/lib/screens/seller/desktop_printer_setup_page.dart`
- `ibul_app/lib/screens/seller/printer_system_setup_wizard.dart`
- `ibul_app/lib/screens/seller/printer_test_dialog.dart`
- `ibul_app/lib/screens/seller/kitchen_print_management_page.dart`
- `ibul_app/lib/services/local_print_service.dart`
- `ibul_app/lib/services/desktop_print_orchestrator.dart`
- `ibul_app/lib/services/print_station_service.dart`
- `ibul_app/lib/services/printer_repository.dart`
- `ibul_app/lib/widgets/bridge_error_dialog.dart`

### Python bridge

- `local_print_bridge/server.py`
- `local_print_bridge/transport.py` (+ CUPS)
- `local_print_bridge/windows_transport.py`
- `local_print_bridge/printers.py`
- `local_print_bridge/queue_manager.py`
- `local_print_bridge/windows/installer/IbulPrintBridgeSetup.iss`
- `local_print_bridge/windows/build_windows_installer.ps1`

### Hosting / packaging

- `scripts/check_windows_installer_hosting.mjs`

## ErrorCode sözlüğü (wire contract)

Bu kodlar, bridge response’larında `errorCode` alanı olarak gelir. Flutter tarafı `BridgeStructuredError.tryParse()` ile parse eder ve aksiyon gösterebilir.

- `bridge_not_running`: Bridge kapalı/ulaşılamıyor (wizard offline snapshot).
- `driver_missing`: Sürücü yok veya yazıcıyla eşleşmemiş.
- `printer_unavailable`: Yazıcı offline/kullanılamıyor (Windows + bazı CUPS durumları).
- `print_system_disabled`: Baskı sistemi kapalı (HTTP 503).
- `cups_queue_busy`: CUPS kuyruğu aktif iş işliyor.
- `cups_queue_stuck`: CUPS kuyruğu submit sonrası takılı kaldı (UI “Kuyruğu Temizle”).
- `duplicate_test_suppressed`: Test fişi spam koruması devrede, duplicate istek bastırıldı.
- `queue_missing`: Bridge’de aktif queue yok, queue-clear çağrılamıyor.
- `queue_clear_failed`: Kuyruk temizleme başarısız.

## Mac test senaryoları (otomasyon + manuel)

### M1) Bridge yokken
- **UI**: Wizard “Bridge çalışmıyor” + kurulum yönlendirmesi, yazıcı tarama/test disabled.
- **Bridge**: `/health` unreachable.
- **Test türü**:
  - Flutter widget test: wizard offline snapshot + butonların disable olması.

### M2) Bridge var ama yazıcı yokken
- **Bridge**: `/health ok`, `/printers count=0`.
- **UI**: “Yazıcı bulunamadı” + “Yeniden tara”.
- **Test türü**:
  - Flutter widget test: boş printer listesi mesajı.

### M3) Bridge var + CUPS yazıcı var
- **Bridge**: `/printers` içinde `backend=cups`, `statusLevel=ready`.
- **UI**: seçim → test fişi → role mapping kaydı.
- **Test türü**:
  - Flutter orchestrator unit test: `printTestReceipt` success → `savePrinterRoles` success.

### M4) Aynı yazıcı CUPS + USB Direct görünürse
- **Bridge**: `/printers` içinde aynı cihaz 2 backend ile döner.
- **Beklenti**:
  - UI duplicate uyarısı (Mac için “CUPS önerilir”) ve yanlış seçimde kilitlenmeme.
- **Test türü**:
  - (Eksik) Bridge tarafında duplicate flag + Flutter tarafında öneri metni için test.

### M5) CUPS queue stuck/busy
- **Bridge**: test/print endpoint structured error: `errorCode=cups_queue_busy|cups_queue_stuck`, `suggested_action=clear_queue`.
- **UI**: “Kuyruğu Temizle” + “Tekrar Dene”.
- **Test türü**:
  - Flutter widget test: structured error dialog açılır, “Kuyruğu Temizle” butonu görünür.
  - Python server test: belirli koşulda `cups_queue_stuck` döndürme (unit seviyesinde).

### M6) Test başarılı ama role mapping başarısız
- **Beklenti**: Fiziksel test basılmış olsa bile “Test başarılı ama kayıt yapılamadı”.
- **Test türü**:
  - Flutter orchestrator test: `saveSingleRoleSelection` `saved_warning` döndüğünde UI warning state.

### M7) Role mapping var ama yazıcı live scan’de yok (stale)
- **Beklenti**:
  - UI “kayıtlı ama bağlı değil” (saved_record) gösterir.
  - Garson baskısı stale printer’a dispatch etmez.
- **Test türü**:
  - Flutter orchestrator unit test: `_resolveSelection` stale selection ignore + fallback behavior.

### M8) Yazıcı silme
- **Beklenti**: local role mapping, remote mapping, station mapping, working snapshot temizlenir.
- **Test türü**:
  - Flutter orchestrator unit test: cleanup flow + repository çağrıları.

### M9) Test fişi duplicate spam koruması
- **Bridge**: `duplicate_test_suppressed`.
- **UI**: “Test zaten gönderildi / lütfen bekleyin”.
- **Test türü**:
  - Python server test: duplicate suppression response.
  - Flutter widget test: structured error dialog.

### M10) Print system disabled
- **Beklenti**: test basılamaz; garson siparişleri `paused_by_operator`/pending kontrollü.
- **Test türü**:
  - Python server test: 503 + `print_system_disabled`.
  - Flutter widget test: disabled state message.

## Windows test senaryoları (otomasyon + manuel)

### W1) Bridge kurulu değil
- **UI**: download CTA (`AppRuntimeConfig.windowsInstallerDownloadUrl`)
- **Test türü**:
  - Flutter widget test: platform=windows → installer button görünür.

### W2) Installer linki 404 / artifact yok
- **Beklenti**: deploy fail (predeploy check).
- **Test türü**:
  - Node script: `node scripts/check_windows_installer_hosting.mjs` fail.

### W3) Installer kuruldu ama bridge başlamadı
- **UI**: “kuruldu ama çalışmıyor” + “başlatmayı dene” + log path.
- **Test türü**:
  - Flutter widget test: `/health` fail state.

### W4) Bridge çalışıyor ama printer listesi boş
- **Bridge**: `/printers count=0` (spooler boş).
- **UI**: Windows spooler yönlendirmesi + “Yeniden tara”.
- **Test türü**:
  - Flutter widget test: empty printers on windows.

### W5) Windows spooler RAW test
- **Bridge**: printer `backend=windows-spool`; `/print/test` success.
- **Test türü**:
  - Python unit test: `discover_windows_printers()` parse + `backend=windows-spool`.

### W6) Firewall/antivirus
- **UI**: “port 3001 erişilemiyor olabilir”.
- **Test türü**:
  - Flutter unit test: `LocalPrintHealthStatus.reason=connection_error|web_cors_blocked` mapping.

### W7) Startup/autostart
- **Bridge**: `/setup/enable-autostart` → enabled + path.
- **Test türü**:
  - Python test: `_enable_autostart(platform='windows')` file write smoke (mock FS).

### W8) Log path
- **Beklenti**: `%LOCALAPPDATA%\\IbulPrintBridge` altında log.
- **Test türü**:
  - Python unit test: `runtime_paths` resolves to LocalAppData on windows (mock env).

## Manuel QA checklist (özet)

### Mac
- Bridge health ok
- Yazıcı tara (CUPS görünür)
- Test fişi → başarılı
- Adisyon rol ata → kaydet
- Mutfak rol ata → kaydet
- Garson adisyon bas
- Garson mutfak bas
- Queue stuck simülasyonu → “Kuyruğu Temizle”
- Yazıcı çıkar/tak → stale state
- Bridge restart + app restart

### Windows
- Temiz cihaz
- Installer indir/kur
- Bridge autostart → PC restart sonrası çalışıyor
- Health ok
- Yazıcılar listeleniyor
- Test fişi
- Rol atama
- Garson adisyon + mutfak
- Log path doğrulama

## Canlı QA (production öncesi)

### Mac canlı QA
- Duplicate CUPS/USB aynı cihaz uyarısı + badge’ler (Önerilen/Alternatif/Queue takılmış)
- CUPS queue stuck simülasyonu → UI “Kuyruğu Temizle”
- Queue clear sonrası tekrar test
- Stale printer (yazıcı çıkar/tak) → “Kayıtlı ama bağlı değil”, otomatik fallback yok
- Rol kaydet (başarılı + başarısız senaryo)
- Garson adisyon bas
- Garson mutfak bas
- Bridge restart
- App restart

### Windows canlı QA
- Temiz Windows cihaz
- Installer indir (`/downloads/IbulPrintBridgeSetup.exe`)
- Kur
- Health ok
- Printer scan (spooler)
- Test fişi
- Role assignment
- Garson adisyon
- Garson mutfak
- Restart sonrası autostart
- Log path (%LOCALAPPDATA%\\IbulPrintBridge)
- Uninstall/reinstall

## Çalıştırma komutları

### Flutter

```bash
cd ibul_app
flutter test test/printer_setup/
flutter test test/screens/desktop_printer_setup_page_test.dart
dart analyze lib/services lib/screens
```

### Python

```bash
cd ..
PYTHONPATH=. python3 -m unittest -q
python3 -m py_compile server.py transport.py print_station.py receipt.py kitchen.py raster.py
```

### Hosting check

```bash
node scripts/check_windows_installer_hosting.mjs
```

