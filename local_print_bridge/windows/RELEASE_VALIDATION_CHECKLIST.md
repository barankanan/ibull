# Windows Installer Release Validation Checklist

Date: ____
Release Version: ____
Tester: ____
Machine: Fresh Windows 10/11 (no prior Ibul Print Bridge install)

## A. Build Artifact

- [ ] Build completed on Windows machine
- [ ] File exists:
  - `local_print_bridge/windows/dist/installer/IbulPrintBridgeSetup.exe`
- [ ] Installer launches with standard setup UX
- [ ] Publisher and app naming are correct

## B. Hosted Download URL

- [ ] `IbulPrintBridgeSetup.exe` copied to hosted static path
- [ ] URL responds with executable content type (not html):
  - `/downloads/IbulPrintBridgeSetup.exe`
- [ ] Download starts from Seller Panel button `Yazici Servisini Indir`

## C. Fresh Install Validation

- [ ] Installer finishes without error
- [ ] Bridge process starts automatically post-install
- [ ] `http://127.0.0.1:3001/health` returns `{ ok: true }`
- [ ] `http://127.0.0.1:3001/printers` responds
- [ ] `%LOCALAPPDATA%\IbulPrintBridge\logs\bridge.log` is created
- [ ] Seller Panel > `Tekrar Kontrol Et` becomes `Hazir`

## D. Auto-Start After Reboot

- [ ] Reboot machine
- [ ] Bridge process starts automatically after login
- [ ] `/health` responds without manual start
- [ ] Seller Panel remains ready

## E. Uninstall / Reinstall

- [ ] Uninstall from Apps & Features succeeds
- [ ] Bridge process no longer running
- [ ] `/health` no longer reachable
- [ ] Seller Panel returns to `not_installed`
- [ ] Reinstall succeeds immediately
- [ ] No leftover lock/runtime issue after reinstall

## F. Print Onboarding End-to-End

- [ ] Printer discovery list populates
- [ ] Test receipt succeeds
- [ ] Adisyon role saved
- [ ] Mutfak role saved
- [ ] Real order print reaches printer

## G. SmartScreen / Permissions Notes

- [ ] If SmartScreen warning appears, note exact message and bypass steps
- [ ] Confirm installer requests expected admin permission
- [ ] Verify no unexpected antivirus block

## H. Versioning / Update Notes

- [ ] Installer version bumped for release
- [ ] Upgrade over previous version tested
- [ ] Existing configuration preserved as expected
- [ ] Update/uninstall notes published for ops team

## Evidence Attachments

- [ ] Screenshot: installer success
- [ ] Screenshot: `/health` response
- [ ] Screenshot: Seller Panel ready state
- [ ] Screenshot: uninstall success
- [ ] Screenshot: real order printed output/log

## Optional Automation

Run script on Windows for baseline install/uninstall checks:

```powershell
cd local_print_bridge/windows
.\validate_release_flow.ps1
```
