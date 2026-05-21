# Windows seller installer download

**Customer download (web + Satıcı Panel):** GitHub Release asset (Firebase Spark `.exe` hosting yok):

- https://github.com/barankanan/ibull/releases/download/v1.0.2-windows-seller/IbulSellerSetup.exe

Uygulama varsayılanı: `AppRuntimeConfig.sellerDesktopWindowsDownloadUrl` (`ibul_app/lib/core/config/runtime_config.dart`).

Build installer:

```powershell
pwsh scripts/build_seller_desktop_windows.ps1
```

Upload `build/windows/installer/IbulSellerSetup.exe` to a new GitHub Release tag, then bump `IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL` / `runtime_config.dart` if the tag changes.

Legacy Firebase Hosting path (artık müşteri indirmesi için kullanılmıyor):

- `/downloads/IbulSellerSetup.exe`

Internal backup (not promoted to customers):

- `IbulPrintBridgeSetup.exe` — bridge-only installer from `local_print_bridge/windows/build_windows_installer.ps1`
