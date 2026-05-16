# Ibul Seller Desktop Setup

Bu belge, browser tabanli Seller Panel yerine Windows ve macOS icin masaustu Seller Desktop App kurulumunu aciklar.

## Hedef

- Seller Panel ayni Flutter UI ile masaustunde acilir.
- Oturum yonetimi Supabase ile ayni sekilde devam eder.
- Yerel yazdirma browser yerine desktop uygulamanin icinde yonetilir.
- `local_print_bridge` uygulama acilisinda auto-start edilerek kullanilir.

## Platformlar

- Windows 10/11 x64
- macOS 13+ Intel / Apple Silicon

## Calistirma

### macOS gelistirme

```bash
./scripts/run_seller_desktop.sh
```

### Windows gelistirme

PowerShell:

```powershell
.\scripts\build_seller_desktop_windows.ps1 -BuildOnly
flutter run -d windows --target lib/main_seller.dart `
  --dart-define=IBUL_SUPABASE_URL=... `
  --dart-define=IBUL_SUPABASE_ANON_KEY=...
```

## Build artifacts

### macOS app

```bash
./scripts/build_seller_desktop.sh
```

Cikti:

```text
build/macos/Build/Products/Release/IbulSellerDesktop.app
```

### macOS DMG

```bash
./scripts/package_seller_desktop_macos.sh
```

Cikti:

```text
build/macos/dist/IbulSellerDesktop.dmg
```

### Windows exe + installer

PowerShell:

```powershell
.\scripts\build_seller_desktop_windows.ps1
```

Ciktilar:

```text
build/windows/x64/runner/Release/
build/windows/installer/IbulSellerDesktopSetup.exe
```

## Uygulama ici yazdirma akisi

1. Seller Desktop App acilir.
2. `BridgeManager.ensureReady()` embedded bridge'i baslatmayi dener.
3. Seller oturumu acildiginda `DesktopPrintHub` restoran icin devreye girer.
4. `/printer-setup` ekraninda:
   - `Yazicilari Tara`
   - `Adisyon Yazicisi Sec`
   - `Mutfak Yazicisi Sec`
   - `Test Fisi Gonder`
   - `Bu cihazi Yazici Merkezi yap`
5. Diger cihazlar sadece print queue'ya is gonderir.

## Ortam degiskenleri

Zorunlu:

- `IBUL_SUPABASE_URL`
- `IBUL_SUPABASE_ANON_KEY`

Opsiyonel:

- `IBUL_GOOGLE_CLIENT_ID`
- `IBUL_GOOGLE_SERVER_CLIENT_ID`
- `IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL`
- `IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL`

Geriye donuk alias kabul edilir:

- `IBUL_WINDOWS_INSTALLER_DOWNLOAD_URL` -> `IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL`
- `IBUL_MACOS_INSTALLER_DOWNLOAD_URL` -> `IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL`

## Paketleme notlari

### Windows

- Flutter build ciktisi Inno Setup ile installer'a sarilir.
- Installer seller desktop uygulamasini ve gerekiyorsa bridge bundle'ini birlikte dagitir.
- Hedef dosya: [windows/installer/IbulSellerDesktopSetup.iss](/Users/barankananogullari/Desktop/ibul2026%20kopyas%C4%B1%209/windows/installer/IbulSellerDesktopSetup.iss:1)

### macOS

- Flutter `build macos` ile `.app` uretilir.
- `hdiutil` ile imaj olusturulur.
- Noterization / signing ayri CI veya release makinesinde yapilmalidir.

## Release checklist

Release adimlari icin:

- [SELLER_DESKTOP_RELEASE_CHECKLIST.md](/Users/barankananogullari/Desktop/ibul2026%20kopyas%C4%B1%209/docs/SELLER_DESKTOP_RELEASE_CHECKLIST.md:1)

## Beklenen UX

- Browser'da Seller Panel acilirsa masaustu uygulama indirme banner'i gorunur.
- Desktop uygulamada terminal veya manuel Python komutu gosterilmez.
- Yazdirma duyarliligi yuksek restoranlar Seller Desktop App'e yonlendirilir.
