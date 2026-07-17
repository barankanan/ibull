# Windows seller installer download

**Customer download (web + Satıcı Panel):** GitHub Release asset (Firebase Spark `.exe` hosting yok):

- https://github.com/barankanan/ibull/releases/download/ibul-public-downloads/IbulSellerSetup.exe

Uygulama varsayılanı: `AppRuntimeConfig.sellerDesktopWindowsDownloadUrl` (`ibul_app/lib/core/config/runtime_config.dart`). Sabit `ibul-public-downloads` tag'i kullanıldığı için URL bump gerekmez; yeni sürüm çıkarmak = installer'ı build edip **aynı tag'e aynı asset adıyla yeniden upload etmek** (`gh release upload ibul-public-downloads ... --clobber`). `releases/latest/download` KULLANMAYIN — eski tag karışıklığına yol açıyordu ve build scriptleri bu kalıbı hata sayar.

Build installer:

```powershell
pwsh scripts/build_seller_desktop_windows.ps1
```

Upload `build/windows/installer/IbulSellerSetup.exe` (ve macOS için `scripts/package_seller_desktop_macos.sh` çıktısı `IbulSellerDesktop.dmg`) to a new GitHub Release tag. Asset adları sabit kalmalı: `IbulSellerSetup.exe`, `IbulSellerDesktop.dmg`.

Legacy Firebase Hosting path (artık müşteri indirmesi için kullanılmıyor):

- `/downloads/IbulSellerSetup.exe`

Internal backup (not promoted to customers):

- `IbulPrintBridgeSetup.exe` — bridge-only installer from `local_print_bridge/windows/build_windows_installer.ps1`
