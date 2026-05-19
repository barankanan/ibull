# Hosted Windows downloads

Primary customer installer (Firebase Hosting `public/downloads/` after staging):

- `IbulSellerSetup.exe` — Ibul Satıcı Windows (desktop app + yazıcı servisi)

Build and stage:

```powershell
pwsh scripts/build_seller_desktop_windows.ps1
npm run stage:windows-installer
npm run check:windows-installer
```

Public URL example:

- `/downloads/IbulSellerSetup.exe`

Internal backup (not promoted to customers):

- `IbulPrintBridgeSetup.exe` — bridge-only installer from `local_print_bridge/windows/build_windows_installer.ps1`
