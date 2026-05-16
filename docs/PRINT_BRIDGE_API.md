# Print Bridge API

Local bridge base URL:

```text
http://127.0.0.1:3001
```

## GET /printers

Returns all printers visible to the local service.

```bash
curl http://127.0.0.1:3001/printers
```

Example response:

```json
{
  "ok": true,
  "count": 1,
  "printers": [
    {
      "id": "cups:Thermal58",
      "name": "Thermal58",
      "vendorId": null,
      "productId": null,
      "connectionType": "usb",
      "backend": "cups",
      "queue": "Thermal58",
      "status": "online"
    }
  ]
}
```

## POST /print

Generic print endpoint. Use one of these payload modes.

### Raw ESC/POS bytes

```bash
curl -X POST http://127.0.0.1:3001/print \
  -H 'Content-Type: application/json' \
  -d '{
    "printer_id": "cups:Thermal58",
    "job_name": "raw-test",
    "raw_base64": "G0BA"
  }'
```

### Structured document

```bash
curl -X POST http://127.0.0.1:3001/print \
  -H 'Content-Type: application/json' \
  -d '{
    "printer_id": "cups:Thermal58",
    "job_name": "adisyon-12",
    "document": {
      "lines": [
        {"type": "text", "value": "ADISYON", "align": "center", "bold": true, "width": 2, "height": 2},
        {"type": "separator"},
        {"type": "text", "value": "Masa 12"},
        {"type": "text", "value": "2 x Ayran"}
      ]
    }
  }'
```

### Structured receipt payload

```bash
curl -X POST http://127.0.0.1:3001/print \
  -H 'Content-Type: application/json' \
  -d @local_print_bridge/sample_receipt_payload.json
```

You can also wrap the receipt as:

```json
{
  "printer_id": "windows:USB POS-80",
  "receipt": {
    "store_name": "IBUL RESTAURANT",
    "table_no": "12",
    "items": [
      {"name": "Corba", "qty": 1, "price": "95.00", "total": "95.00"}
    ],
    "subtotal": "95.00",
    "discount": "0.00",
    "grand_total": "95.00"
  }
}
```

## POST /print/receipt

Backward-compatible receipt endpoint used by the current waiter flow.

## POST /print/kitchen

Backward-compatible kitchen ticket endpoint.

## GET /health

Readiness endpoint for the desktop hub and UI status bar.

## Frontend Integration Pattern

```dart
final printService = LocalPrintService();
final printers = await printService.printers();
final printerList =
    (printers?['printers'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
    const <Map<String, dynamic>>[];

if (printerList.isEmpty) {
  throw Exception('No local printer found');
}

final printerId = printerList.first['id'] as String;

await printService.printJob({
  'printer_id': printerId,
  'document': {
    'lines': [
      {'type': 'text', 'value': 'MUTFAK', 'align': 'center', 'bold': true},
      {'type': 'separator'},
      {'type': 'text', 'value': '1 x Adana'},
    ],
  },
});
```

App-side rule:

1. Send the print request first.
2. Wait for success.
3. Mark the order as printed only after the bridge confirms success.
