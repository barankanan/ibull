# Local Print Hardening Report

Last updated: 21 Nisan 2026

## Summary

This report documents the current hardening status of the seller-panel printer setup system and the local print bridge, based on code inspection and the implementation already present in the repository.

This session produced:

- a QA checklist for manual validation
- one UI hardening fix to prevent raw exception text from appearing to operators in the wizard
- a prioritized issue list
- a packaging and installer strategy proposal
- a performance measurement approach grounded in existing telemetry

## What Is Already In Place

The current implementation already provides strong validation hooks:

- `/print/logs` and `/print/logs/recent` exist and expose structured print logs.
- Queue instrumentation exists through `PrintQueueManager`, including `queue_wait_ms`, retry count, and recent queue activity.
- Print responses include `printer_write_started_at` and `printer_write_completed_at`.
- `/diagnostics` already reports dependency status, platform details, queue state, and printer inventory.
- `/warmup` exists to reduce cold-start penalty.
- The setup wizard blocks final progression until test print succeeds.

## Discovered Issues

## Fixed in this session

### HR-01 Raw exception leakage in wizard UI

- Severity: High
- Area: Operator UX
- Status: Fixed
- Finding:
  - The setup wizard previously assigned `error.toString()` directly to operator-visible fields for system check, setup, printer detection, test print, and final save failures.
  - This could expose exception types, network wording, or technical stack-like messages to restaurant staff.
- Fix applied:
  - Operator-facing messages are now sanitized.
  - Raw exception strings are kept only inside `Teknik Detaylar`.

## Open issues

### HR-02 No packaged operator installation path yet

- Severity: High
- Area: Deployment
- Status: Open
- Finding:
  - Current autostart and setup logic still assumes a Python runtime by generating launch/startup entries that execute `python -m local_print_bridge`.
  - This is not operator-safe for restaurant rollout.

### HR-03 Service reachability and setup-state architecture are split

- Severity: Medium
- Area: Validation model
- Status: Open
- Finding:
  - `/setup/status` is only available when the bridge is already running.
  - The app correctly falls back to an offline state when unreachable, but “bridge not running” is represented by app fallback rather than a direct backend response.
  - QA documentation and support workflows must treat these as two different detection modes.

### HR-04 Diagnostics endpoint is technical by design

- Severity: Medium
- Area: UX boundary
- Status: Open
- Finding:
  - `/diagnostics` returns developer-facing dependency names such as `pywin32`, `pyusb`, and CUPS command availability.
  - This is acceptable only if the main UI never surfaces the raw data to operators outside `Teknik Detaylar`.

### HR-05 No packaged installer verification yet

- Severity: Medium
- Area: Release readiness
- Status: Open
- Finding:
  - There is no verified `.exe` or `.app` distribution flow yet.
  - Real restaurant deployment still depends on development-style runtime assumptions.

### HR-06 Performance SLA not yet proven on real hardware

- Severity: Medium
- Area: Runtime performance
- Status: Open
- Finding:
  - Instrumentation exists, but no p50/p95 hardware measurements were collected in this session.
  - The less-than-2-second target remains unverified until field runs are executed.

## Recommended Fixes

### Priority 1

1. Package the bridge as a native operator installable.
2. Validate the complete checklist in `docs/local_print_qa_checklist.md` on real Windows and macOS machines.
3. Capture real latency metrics for USB and network printers.

### Priority 2

1. Add a lightweight support screen or export flow for diagnostics and recent logs.
2. Add an explicit “service not reachable” support action in the app for bridge restart guidance.
3. Add runtime smoke tests for `/diagnostics`, `/print/logs`, and `/printers` in CI where possible.

### Priority 3

1. Add packaged installer telemetry or version reporting.
2. Add a release checklist for printer-driver validation per supported hardware family.

## Performance Metrics Plan

## Existing measurement fields

The bridge already exposes the fields needed for real latency analysis:

- `printer_write_started_at`
- `printer_write_completed_at`
- `duration_ms`
- `queue_wait_ms`
- `retry_count`
- `render_ms` for kitchen bitmap rendering paths
- queue summary via `/health` and `/diagnostics`

## Required production measurements

Collect these metrics for each platform and printer type:

| Platform | Printer Type | Job Type | Runs | p50 Submit-to-Start | p95 Submit-to-Start | p95 Queue Wait | p95 Total Write | SLA Pass |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Windows | USB | Adisyon | 20 |  |  |  |  |  |
| Windows | Network | Mutfak | 20 |  |  |  |  |  |
| macOS | USB | Adisyon | 20 |  |  |  |  |  |
| macOS | CUPS/Network | Mutfak | 20 |  |  |  |  |  |

## Bottleneck interpretation

- High queue wait: same-printer contention or queue saturation
- High render time: image rendering and rasterization overhead
- Low render time with late write start: spooler, USB, TCP, or OS transport delay
- High retries: flaky hardware, network instability, or intermittent device readiness

## Installation Strategy Proposal

## Windows

Recommended packaging:

- Build the bridge into a single packaged `.exe`.
- Install via MSI or a simple signed installer.
- Register autostart via Task Scheduler or a Startup entry owned by the installer.

Recommended implementation:

1. Package Python runtime and dependencies inside the installer artifact.
2. Launch the bridge as a background process or tray-less local service app.
3. Store logs under an installer-owned runtime folder, not developer paths.
4. Ship version metadata so support can identify installed build quickly.

Do not require operators to:

- install Python
- run `pip`
- open terminals
- run manual commands

## macOS

Recommended packaging:

- Build the bridge into a signed `.app` bundle.
- Install to `/Applications` or an app-owned support folder.
- Register autostart with a LaunchAgent installed by the app or installer.

Recommended implementation:

1. Bundle Python runtime and dependencies inside the app.
2. Keep the local HTTP bridge behavior, but hide implementation details from users.
3. Write logs to `~/Library/Application Support/...` or another app-owned location.
4. Notarize/sign the build before restaurant deployment.

## Packaging Recommendation

Preferred direction:

- Windows: single-file or installer-based `.exe`
- macOS: signed `.app`

Candidate toolchains:

- PyInstaller for first packaging milestone
- Briefcase or another app-bundling approach if native packaging quality becomes a priority

Decision rule:

- Use the fastest packaging path that removes Python and pip from operator experience.

## Logging Validation Status

Code inspection confirms:

- every successful print path builds a log entry
- failure logging is present in byte submission paths
- queue timing and retry data are captured
- `/print/logs` and `/print/logs/recent` are available for support workflows

Open runtime validation tasks:

1. Confirm every failure scenario writes a log entry in practice.
2. Confirm `error_details` is actionable for support.
3. Confirm log retention behavior is acceptable for restaurant devices.

## Diagnostics Validation Status

Code inspection confirms `/diagnostics` reports:

- OS and Python details
- transport mode and available transports
- dependency checks for Pillow, pyusb, pywin32
- CUPS command availability
- printer inventory
- queue summary

Open runtime validation tasks:

1. Validate actual machine state matches endpoint output.
2. Validate missing dependency cases on real Windows and macOS environments.
3. Confirm support staff can interpret endpoint output consistently.

## UX Validation Status

Code inspection confirms:

- the wizard is step-based and operator-directed
- test print gating exists
- technical details are isolated behind `Teknik Detaylar`

Remaining UX validation tasks:

1. Run end-to-end moderated tests with non-technical restaurant staff.
2. Validate terminology comprehension for every step.
3. Confirm the revised plain-language error handling is sufficient in real failures.

## Recommended Execution Order

1. Build or package the bridge into operator-safe Windows and macOS artifacts.
2. Run the checklist in `docs/local_print_qa_checklist.md` on fresh machines.
3. Capture the performance table using real receipt and kitchen jobs.
4. Triage issues by severity and update installer, logging, or transport behavior accordingly.
