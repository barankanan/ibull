# Local Print Bridge

Cross-platform local print service for the restaurant waiter system.

It runs on the same machine as the browser and gives the web app a native
`localhost` API for receipt and kitchen printing.

## What It Solves

- Flutter Web cannot access USB printers directly.
- macOS receipt printers usually work through CUPS.
- Windows receipt printers usually work through the native print spooler.
- This bridge hides those differences behind one local API.

## Supported Transports

- `macOS`: CUPS raw queue and optional direct USB (`pyusb`)
- `Windows`: native Windows spooler RAW printing (`pywin32`) and optional USB targeting
- `Network`: raw TCP (`9100`) for Ethernet/Wi-Fi ESC/POS printers

## Main API

- `GET /health`
- `GET /printers`
- `POST /print`
- `POST /print/receipt`
- `POST /print/kitchen`
- `POST /print/test`
- `POST /configure`
- `POST /setup`

Legacy `GET /discover` is still available for older Flutter screens.

## Printer Response Shape

`GET /printers`

```json
{
  "ok": true,
  "count": 2,
  "printers": [
    {
      "id": "windows:USB POS-80",
      "name": "USB POS-80",
      "vendorId": "0x0416",
      "productId": "0x5011",
      "connectionType": "usb",
      "backend": "windows-spool",
      "queue": "USB POS-80",
      "status": "online"
    }
  ]
}
```

Required fields from the project brief are covered by:

- `name`
- `vendorId`
- `productId`
- `connectionType`

## Generic Print Endpoint

### 1. Raw ESC/POS bytes

```json
{
  "printer_id": "windows:USB POS-80",
  "job_name": "adisyon-12",
  "raw_base64": "G0BB..."
}
```

You can also send `raw_hex`.

### 2. Structured ESC/POS document

```json
{
  "printer_id": "windows:USB POS-80",
  "job_name": "mutfak-42",
  "document": {
    "lines": [
      { "type": "text", "value": "MUTFAK", "align": "center", "bold": true, "width": 2, "height": 2 },
      { "type": "separator" },
      { "type": "text", "value": "Masa 12" },
      { "type": "text", "value": "1 x Adana" },
      { "type": "newline", "count": 1 }
    ],
    "feed": 3,
    "cut": true
  }
}
```

This supports:

- bold text
- left / center / right alignment
- separators
- explicit line breaks
- Turkish-safe ESC/POS encoding via `cp857` default

### 3. Existing receipt payload

`POST /print/receipt` still accepts the current structured receipt body.

`POST /print` can also receive:

```json
{
  "printer_id": "windows:USB POS-80",
  "receipt": {
    "store_name": "IBUL RESTAURANT",
    "table_no": "12",
    "items": [
      { "name": "Izgara Kofte", "qty": 2, "price": "195.00", "total": "390.00" }
    ],
    "subtotal": "390.00",
    "discount": "0.00",
    "grand_total": "390.00"
  }
}
```

## Installation

### Windows no-code installer (recommended for restaurant staff)

1. Download `IbulPrintBridgeSetup.exe`
2. Run installer with normal Windows setup flow
3. Finish install (bridge auto-start is configured)
4. Return to Seller Panel and click "Tekrar Kontrol Et"

Packaging/build files for this flow are under:

- `local_print_bridge/windows/README.md`
- `local_print_bridge/windows/build_windows_installer.ps1`
- `local_print_bridge/windows/IbulPrintBridge.spec`
- `local_print_bridge/windows/installer/IbulPrintBridgeSetup.iss`

### 1. Create a virtualenv

```bash
cd local_print_bridge
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cd ..
```

### 2. Configure

```bash
cp local_print_bridge/.env.example local_print_bridge/.env
```

Notes:

- `PRINT_BRIDGE_PRINTER_QUEUE` is the CUPS queue name on macOS.
- `PRINT_BRIDGE_PRINTER_QUEUE` is the installed Windows printer name on Windows.
- `PRINT_BRIDGE_PORT` defaults to `3001` to match the Flutter client.

### 3. Run

```bash
python3 -m local_print_bridge
```

## Windows Notes

- Install the USB receipt printer normally in Windows first.
- The bridge prints raw ESC/POS through the Windows spooler by printer name.
- `pywin32` is required for actual printing on Windows.
- Use `GET /printers` to see the printer name that should be selected in the admin UI.
- Duplicate bridge launches are prevented by lock file + localhost port checks.
- Packaged runtime state lives under `%LOCALAPPDATA%\IbulPrintBridge`.
- Bridge server logs and print logs are written under `%LOCALAPPDATA%\IbulPrintBridge\logs`.

## macOS Notes

- CUPS queues are supported out of the box.
- Direct USB transport via `pyusb` is optional.
- `POST /setup` still performs one-shot auto-configuration for quick local setup.

## Frontend Example

```dart
final service = LocalPrintService();

final printers = await service.printers();
final selectedPrinterId =
    (printers?['printers'] as List?)?.cast<Map<String, dynamic>>().first['id']
        as String;

await service.printJob({
  'printer_id': selectedPrinterId,
  'document': {
    'lines': [
      {
        'type': 'text',
        'value': 'ADISYON',
        'align': 'center',
        'bold': true,
        'width': 2,
        'height': 2,
      },
      {'type': 'separator'},
      {'type': 'text', 'value': 'Masa 12'},
      {'type': 'text', 'value': '2 x Corba'},
    ],
  },
});
```

Recommended app flow:

1. Web app calls the bridge.
2. Wait for `{ "ok": true }`.
3. Only then mark the order as printed.

## Verification

Run:

```bash
python3 -m unittest local_print_bridge.tests.test_server \
  local_print_bridge.tests.test_models \
  local_print_bridge.tests.test_receipt \
  local_print_bridge.tests.test_raster
```
