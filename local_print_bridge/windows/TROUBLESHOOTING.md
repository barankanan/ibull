# Windows Print Bridge Troubleshooting

## Installer downloads HTML instead of EXE

- Confirm `build/web/downloads/IbulPrintBridgeSetup.exe` exists before deploy.
- Deploy hosting again after the file is copied.
- Verify `https://.../downloads/IbulPrintBridgeSetup.exe` returns status `200` and content type is not `text/html`.

## Installer finishes but Seller Panel still says bridge is missing

- On the Windows machine, open `http://127.0.0.1:3001/health`.
- If the page does not respond, inspect `%LOCALAPPDATA%\IbulPrintBridge\logs\bridge.log`.
- Confirm the Windows startup key exists at `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\IbulLocalPrintBridge`.

## Bridge starts but no printers appear

- Install the receipt printer normally in Windows first.
- Print a Windows test page outside Ibul to confirm the driver is healthy.
- Re-open Seller Panel and click `Tekrar Kontrol Et`, then `Yazıcıları Tara`.

## Test receipt fails

- Check `%LOCALAPPDATA%\IbulPrintBridge\logs\bridge.log` for transport errors.
- Check `%LOCALAPPDATA%\IbulPrintBridge\logs\print_logs.jsonl` for per-job failures.
- Confirm the printer is online, has paper, and is not paused in Windows printer settings.

## Duplicate instance or port conflict

- `http://127.0.0.1:3001/health` should respond from exactly one bridge instance.
- The bridge uses `%LOCALAPPDATA%\IbulPrintBridge\bridge.lock` plus a localhost port check to block duplicates.
- If another app is already using port `3001`, stop that app and relaunch the bridge.

## SmartScreen warning on first install

- Record the exact warning text in the release checklist.
- Use the signed release build when available.
- Do not instruct restaurant staff to use terminal commands as a workaround.
