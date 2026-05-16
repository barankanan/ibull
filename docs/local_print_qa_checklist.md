# Local Print Bridge QA Checklist

Last updated: 21 Nisan 2026

## Scope

This checklist validates the seller-panel printer setup wizard, the local print bridge, and real print delivery behavior on Windows and macOS in restaurant-like conditions.

Target SLA:

- `siparis gonder` to `printer_write_started_at` should be less than 2000 ms.
- Test print step must block progress until a successful print is confirmed.
- UI text shown to operators must avoid Python, pip, localhost, stack traces, exception class names, and raw dependency names.

## Test Environments

Prepare these environments before execution:

1. Fresh Windows machine with no bridge, no Python, no pywin32, no pyusb, no printer driver.
2. Fresh macOS machine with no bridge packaging installed.
3. Windows machine with driver installed but printer powered off.
4. Windows machine with multiple printers: USB receipt printer and network kitchen printer.
5. macOS machine with one USB printer and one network/CUPS printer.
6. One environment with active order traffic to test simultaneous adisyon and mutfak prints.

## Core End-To-End Wizard Flow

### WF-01 Full happy path

- Platform: Windows
- Preconditions: Bridge installed, printer driver installed, one ready printer
- Steps:
  1. Open Seller Panel > Sistem > Yazici Ayarlari > Yazicilar.
  2. Click `Sistem Kur`.
  3. Complete all 7 steps.
  4. Send test print.
  5. Assign Adisyon Yazicisi and Mutfak Yazicisi.
- Expected:
  - All steps understandable by non-technical staff.
  - `Devam Et` blocked on test step until successful test print.
  - Final save persists printer roles correctly.
  - No technical jargon shown outside `Teknik Detaylar`.

### WF-02 Full happy path

- Platform: macOS
- Preconditions: Bridge installed, printer visible in system, one ready printer
- Steps: same as WF-01
- Expected:
  - macOS-specific guidance is shown.
  - CUPS/system printer visibility is reflected in detection step.
  - Final role assignment is saved correctly.

## Failure-State Validation Matrix

For every case below, validate three things:

1. Backend or printer inventory reports the correct `statusLevel`.
2. UI shows a clear operator-safe `statusMessage`.
3. No raw technical text appears outside `Teknik Detaylar`.

### FS-01 Fresh Windows machine, no dependencies installed

- Preconditions: No bridge package, no Python tooling, no printer driver, no printer installed in Windows.
- Expected backend/result:
  - Wizard should fall back to bridge-unreachable state.
  - UI should indicate service is not reachable or not installed.
  - If diagnostics can be run from a packaged bridge build later, dependency state should show missing items in technical outputs only.
- Expected operator text:
  - `Yazici servisine ulasilamadi.`
  - No `pip`, `pywin32`, `localhost`, `socket`, or exception text shown.

### FS-02 Missing printer driver

- Preconditions: Bridge reachable, Windows printer object exists but driver missing or mismatched.
- Expected backend/result:
  - Printer `statusLevel = error`
  - `errorCode = driver_missing`
  - Setup status `status = driver_missing`
- Expected operator text:
  - `Windows yazici surucusu eksik. Yazici once isletim sistemine kurulmalidir.`
  - Driver help box shown.

### FS-03 Printer offline

- Preconditions: Driver installed, printer registered, power or cable removed.
- Expected backend/result:
  - Printer `statusLevel = error` or `warning`, depending on platform-reported state.
  - Setup status should not show `ready`.
- Expected operator text:
  - `Yazici cevrimdisi veya hazir degil.`
  - No Windows spooler or CUPS jargon in main UI.

### FS-04 Bridge not installed

- Preconditions: No packaged bridge present.
- Expected backend/result:
  - From app perspective, bridge endpoint unreachable.
  - Wizard should show install/start guidance, not low-level connection failures.
- Expected operator text:
  - `Yazici servisi kurulmali.` or equivalent plain-language install guidance.

### FS-05 Bridge installed but not running

- Preconditions: Bridge package exists, process is stopped.
- Expected backend/result:
  - App should hit offline fallback state.
  - Operator sees `Bridge Calismiyor` / service unavailable state.
- Expected operator text:
  - `Yazici servisi kapali veya yanit vermiyor.`

### FS-06 Multiple printers detected

- Preconditions: At least two printers detected.
- Expected backend/result:
  - `/printers` returns both devices with distinct IDs.
  - One printer can be selected for test, roles can be split at final step.
- Expected operator text:
  - Printer names clearly visible.
  - Status chip visible for each printer.

### FS-07 Simultaneous print jobs (adisyon + mutfak)

- Preconditions: Receipt and kitchen jobs sent at nearly the same time.
- Steps:
  1. Trigger receipt print.
  2. Immediately trigger kitchen print.
  3. Repeat against same printer and then separate printers.
- Expected backend/result:
  - Queue summary updates correctly.
  - Same-printer jobs serialize safely.
  - Separate-printer jobs execute without blocking each other more than transport overhead.
  - Logs recorded for both jobs.

### FS-08 USB vs network printers

- Preconditions: One USB printer and one network printer available.
- Expected backend/result:
  - `connectionType` and `backend` reflect the actual transport.
  - USB printer can be selected and tested.
  - Network host/port routing works when configured.

## Endpoint Validation

### EV-01 `/setup/status`

- Validate response fields:
  - `ok`
  - `step`
  - `status`
  - `message`
  - `errorCode`
  - `platform`
  - `actionRequired`
- Validate `checks`, `printers`, `autostart`, and `technicalDetails` shape.

### EV-02 `/setup/install`

- Run with reachable USB printer.
- Run with reachable Windows spool printer.
- Run with no printers.
- Run with driver missing.
- Validate operator-safe messages for each branch.

### EV-03 `/setup/start`

- Validate warmup result is successful when service is alive.
- Confirm technical warmup failure detail is not surfaced to operators.

### EV-04 `/setup/enable-autostart` and `/setup/disable-autostart`

- Validate toggle behavior on Windows and macOS.
- Confirm reported path/mode matches actual installed autostart artifact.

### EV-05 `/printers`

- Validate printer IDs are stable across refreshes.
- Validate `statusLevel`, `statusMessage`, `backend`, and `connectionType` are accurate.

### EV-06 `/print/logs` and `/print/logs/recent`

- Confirm every print attempt creates a log entry, including failures.
- Validate these fields exist and are meaningful:
  - `timestamp`
  - `printer_id`
  - `printer_name`
  - `transport_type`
  - `document_type`
  - `success`
  - `duration_ms`
  - `queue_wait_ms`
  - `retry_count`
  - `job_name`
  - `backend_job_id`
  - `error_details`

### EV-07 `/diagnostics`

- Validate actual machine state matches response.
- Specifically test:
  - Missing `pywin32`
  - Missing `pyusb`
  - Missing CUPS commands (`lp`, `lpstat`)
  - Printer inventory count
  - Queue summary and recent jobs

## Performance Validation

## PV-01 Receipt latency

- Measure from UI order submit action to response field `printer_write_started_at`.
- Repeat 20 times for:
  - Windows USB
  - Windows network
  - macOS USB
  - macOS network/CUPS
- Record:
  - total request time
  - render time
  - queue wait time

## Unified Printer Orchestrator Regression

### UPO-01 Single backend wiring

- Open each of these surfaces and confirm they all use the same printer list, same role selections, and same success/failure wording:
  - `Yazicilar` tab
  - `Yazici Merkezi`
  - `Sistem Kur`
  - `Rol Atama`
  - `Adisyon test`
  - `Mutfak test`
- Expected:
  - No screen shows a different printer inventory from another screen after refresh.
  - All test buttons return the same friendly result family:
    - `Hazir`
    - `Yazici bulunamadi`
    - `Test basarisiz`
    - `Yazici cevrimdisi`
    - `Bridge calismiyor`
  - No raw JSON, `lp`, Python, stack trace, or terminal text appears in normal UI.

### UPO-02 macOS real setup

- Preconditions: USB POS58 attached, bridge running.
- Steps:
  1. Open `Sistem Kur`.
  2. Click `Yazicilari Tara`.
  3. Select adisyon and mutfak printers.
  4. Send both test fisleri.
  5. Complete setup.
  6. Restart the desktop app.
- Expected:
  - USB direct printers sort ahead of CUPS queues when both are available.
  - If USB direct is unavailable, CUPS queues are offered.
  - If CUPS is unavailable, the UI shows a safe operator message instead of raw command errors.
  - Role selections survive restart.

### UPO-03 Windows real setup

- Preconditions: Windows spool printer installed, printer online.
- Steps:
  1. Open `Yazici Merkezi`.
  2. Click `Yazicilari Tara`.
  3. Select the Windows printer for adisyon and mutfak.
  4. Send both test fisleri.
  5. Save setup.
  6. Restart the desktop app.
- Expected:
  - Dropdown stores the real Windows spool queue name, not only display text.
  - Warning or offline printers cannot be marked ready without a successful test.
  - Role selections survive restart.

### UPO-04 Offline cloud fallback

- Preconditions: Supabase unavailable or invalid key.
- Steps:
  1. Select adisyon and mutfak printers.
  2. Save setup.
  3. Send local test print.
- Expected:
  - Save succeeds locally.
  - UI shows `Buluta kaydedilemedi, yerel kayit yapildi`.
  - Local test printing still works.
  - Cloud failure does not block `Kurulumu Tamamla`.

### UPO-05 Cross-device print station

- Preconditions: Desktop app configured as active print station.
- Steps:
  1. Confirm heartbeat is online.
  2. Send an order from web or phone.
  3. Verify adisyon and mutfak jobs are consumed by the desktop app.
  4. Force one failed print and retry it safely.
- Expected:
  - Pending job becomes `claimed`, then `completed` or `failed`.
  - Successful jobs update to `printed/completed`.
  - Failed jobs can retry without duplicate unsafe output.
  - backend write start time
  - backend write complete time
- Pass criteria:
  - p95 of submit-to-start less than 2000 ms

## PV-02 Kitchen latency

- Same procedure as PV-01 using `/print/kitchen`.
- Capture `render_ms`, `chunk_count`, and total request time where available.

## PV-03 Cold start vs warm start

- First print after launch without warmup
- First print after `/warmup`
- Next 10 prints
- Expected:
  - warm start materially faster than cold start
  - cold-start penalty documented and acceptable

## Bottleneck Diagnosis Guide

When SLA is missed, classify root cause using these signals:

- High `queue_wait_ms`: queue saturation or same-printer serialization
- High `render_ms`: bitmap/rendering overhead
- Low render time but slow print start: transport or OS spool bottleneck
- High total time with repeated retries: device availability or flaky connection

## Logging Validation

### LV-01 Success path logging

- Send receipt print.
- Send kitchen print.
- Confirm logs written for each.

### LV-02 Failure path logging

- Trigger offline printer failure.
- Trigger driver-missing failure.
- Trigger invalid target printer selection.
- Confirm failed attempts still appear in logs with useful `error_details`.

### LV-03 Queue visibility

- Send multiple same-printer jobs quickly.
- Validate queue wait metrics are non-zero and realistic.

## Diagnostics Validation

### DV-01 Missing pywin32

- Windows only.
- Remove or package-build without `pywin32`.
- Validate diagnostics reports dependency missing.
- Ensure operator UI does not expose `pywin32` terminology directly.

### DV-02 Missing pyusb

- Remove USB dependency support.
- Validate diagnostics reports `pyusb` missing.
- Validate USB transport health degrades cleanly.

### DV-03 Missing CUPS

- macOS test with missing `lp` or `lpstat` visibility.
- Validate diagnostics reflects missing CUPS tooling.
- Validate operator guidance remains plain-language.

## UX Validation

### UX-01 Non-technical readability

- Ask a restaurant operator or non-developer tester to complete the wizard without assistance.
- Record where they hesitate or misinterpret a step.

### UX-02 Blocking behavior

- Confirm the flow does not allow progression from test step without successful test print.

### UX-03 Error copy

- Trigger connectivity failure.
- Trigger printer failure.
- Trigger missing driver.
- Confirm visible text is operational, not technical.

## Execution Log Template

Use this table during manual QA:

| ID | Platform | Scenario | Expected | Actual | Pass/Fail | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| FS-01 | Windows | Fresh machine no dependencies | Bridge unreachable guidance |  |  |  |
| FS-02 | Windows | Missing driver | Error + driver help |  |  |  |
| FS-03 | Windows/macOS | Printer offline | Warning or error, operator-safe message |  |  |  |
| FS-04 | Windows/macOS | Bridge not installed | Install guidance |  |  |  |
| FS-05 | Windows/macOS | Bridge stopped | Service unavailable guidance |  |  |  |
| FS-06 | Windows/macOS | Multiple printers | Correct detection and assignment |  |  |  |
| FS-07 | Windows/macOS | Simultaneous jobs | Safe queueing and logs |  |  |  |
| FS-08 | Windows/macOS | USB vs network | Correct transport mapping |  |  |  |
