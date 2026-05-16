# Windows Packaging and Installer

This folder builds a no-code Windows installation flow for the local print bridge.

## Output Artifacts

- Standalone bridge executable:
  - `local_print_bridge/windows/dist/bridge/IbulPrintBridge.exe`
- Windows installer:
  - `local_print_bridge/windows/dist/installer/IbulPrintBridgeSetup.exe`

## What Is Included

- Python runtime and dependencies are bundled into the bridge executable.
- Windows installer installs into `Program Files\IbulPrintBridge`.
- Start Menu entry is created.
- Uninstaller is created.
- Optional desktop shortcut task is available.
- Auto-start on user login is configured through `HKCU\\...\\Run`.
- Bridge logs are written to `%LOCALAPPDATA%\IbulPrintBridge\logs`.

## Build Prerequisites (Windows Build Machine)

1. Python 3.11+ with `py` launcher
2. Inno Setup 6 (ISCC compiler)
3. Windows x64 machine (recommended for final build)

## Build Command

From PowerShell:

```powershell
cd local_print_bridge/windows
.\build_windows_installer.ps1 -AppVersion 1.0.0
```

The build script now also copies the final installer into hosted static output:

- `build/web/downloads/IbulPrintBridgeSetup.exe`

Then deploy hosting:

```powershell
cd <repo-root>
firebase deploy --only hosting
```

## Installer Behavior

1. User runs `IbulPrintBridgeSetup.exe`
2. Installer copies bridge to:
   - `%ProgramFiles%\\IbulPrintBridge`
3. Installer writes auto-start key:
   - `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\IbulLocalPrintBridge`
4. Installer starts bridge once after install
5. Bridge listens on `http://127.0.0.1:3001`
6. Runtime state and logs are stored under `%LOCALAPPDATA%\\IbulPrintBridge`

## Release Validation

Use the release checklist:

- `local_print_bridge/windows/RELEASE_VALIDATION_CHECKLIST.md`
- `local_print_bridge/windows/TROUBLESHOOTING.md`

Optional baseline automation on Windows:

```powershell
cd local_print_bridge/windows
.\validate_release_flow.ps1
```

## Duplicate Instance Prevention

The bridge process now prevents duplicate runs with:

- Localhost port check before startup
- Single-instance lock file under `%LOCALAPPDATA%\\IbulPrintBridge\\bridge.lock`
- Internal retry loop if the first startup attempt fails

## Update / Uninstall

- Update: run a newer `IbulPrintBridgeSetup.exe` over existing install.
- Uninstall: use Windows Apps/Programs uninstall entry (`Ibul Print Bridge`).

## Web Distribution Path

For Seller Panel download button, publish the installer as:

- `/downloads/IbulPrintBridgeSetup.exe`

If Firebase Hosting is used, ensure this file exists before deploy:

- `build/web/downloads/IbulPrintBridgeSetup.exe`

## Troubleshooting

Use:

- `local_print_bridge/windows/TROUBLESHOOTING.md`
