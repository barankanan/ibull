# Windows Release Execution (Final)

Run this on a real Windows build/test machine in PowerShell.

## 0) Preconditions

- Python + `py` launcher installed
- Inno Setup 6 installed
- Firebase CLI authenticated for project `ibul-ecommerce`
- Repo checked out and up to date

## 1) Build installer

```powershell
cd <repo-root>\local_print_bridge\windows
.\build_windows_installer.ps1 *>&1 | Tee-Object build_windows_installer.log
```

## 2) Verify required outputs

```powershell
cd <repo-root>
$installer = "local_print_bridge\\windows\\dist\\installer\\IbulPrintBridgeSetup.exe"
$hosted = "build\\web\\downloads\\IbulPrintBridgeSetup.exe"

if (!(Test-Path $installer)) { throw "Missing: $installer" }
if (!(Test-Path $hosted)) { throw "Missing: $hosted" }

Get-Item $installer | Format-List FullName,Length,LastWriteTime
Get-Item $hosted | Format-List FullName,Length,LastWriteTime
```

## 3) Run release gate (hosting + headers)

If using Git Bash / WSL:

```bash
cd <repo-root>
./scripts/release_windows_installer_gate.sh | tee release_gate.log
```

If PowerShell only (fallback):

```powershell
cd <repo-root>
firebase deploy --only hosting *>&1 | Tee-Object release_gate.log
curl.exe -I https://ibul-ecommerce.web.app/downloads/IbulPrintBridgeSetup.exe | Tee-Object -Append release_gate.log
```

Gate must satisfy:
- HTTP status 200
- content-type is NOT `text/html`
- content-length is non-trivial

## 4) Run Windows validation script

```powershell
cd <repo-root>\local_print_bridge\windows
.\validate_release_flow.ps1 *>&1 | Tee-Object validate_release_flow.log
```

## 5) Complete release checklist

File:
- `local_print_bridge/windows/RELEASE_VALIDATION_CHECKLIST.md`

Mark all sections A-H and attach evidence screenshots.

## 6) Final Seller Panel real-user flow (manual)

On fresh Windows operator machine:

1. Download installer via Seller Panel button
2. Install
3. Click `Tekrar Kontrol Et`
4. Printer discovery
5. Test receipt
6. Role assignment (adisyon + mutfak)
7. Real order print

Capture notes/screenshots and append to checklist.

## 7) Deliverables package

Share these files/logs back:

- `local_print_bridge/windows/build_windows_installer.log`
- `release_gate.log`
- `local_print_bridge/windows/validate_release_flow.log`
- completed `local_print_bridge/windows/RELEASE_VALIDATION_CHECKLIST.md`

## Final status rule

- PASS: all gate + validation + manual flow steps complete
- FAIL: any required check fails or is missing evidence
