# Local Print Bridge

Tek yazıcılı ilk sürüm için önerilen akış:

`Web app -> http://127.0.0.1:19001 -> CUPS queue -> USB termal yazıcı`

Bu tasarımda uygulama USB'ye doğrudan dokunmaz. macOS zaten yazıcıyı gördüğü için, transport katmanını CUPS yönetir; Python servis ise sadece:

- payload doğrular
- ESC/POS raw fiş üretir
- `lp -d <queue> -o raw` ile CUPS kuyruğuna teslim eder

Bu yaklaşım Node `usb` katmanındaki kararsızlıktan kaçınır ve ilk hedef olan tek yazıcıya düzgün adisyon basmayı sadeleştirir.

## Neden bu yol?

- USB sürücü/claim işini uygulama yerine macOS+CUPS üstlenir.
- ESC/POS render katmanı saf Python olduğu için `escpos-usb` benzeri kırılgan bağımlılıklar yoktur.
- Aynı servis daha sonra mutfak routing veya çoklu queue desteği eklenerek büyütülebilir.

## Minimum API

### `GET /health`

Servisin ayakta olup olmadığını ve hedef CUPS kuyruğunun kontrol sonucunu döner.

### `POST /print/test`

Body istemez. Dahili örnek adisyonu hedef yazıcıya gönderir.

### `POST /print/receipt`

Önerilen body:

```json
{
  "store_name": "IBUL RESTAURANT",
  "branch": "MERKEZ SUBE",
  "phone": "0326 000 00 00",
  "table_no": "12",
  "datetime": "2026-04-08T14:35:00+03:00",
  "items": [
    {
      "name": "Izgara Kofte",
      "qty": 2,
      "price": "195.00",
      "total": "390.00"
    }
  ],
  "subtotal": "390.00",
  "discount": "0.00",
  "grand_total": "390.00",
  "currency": "TRY",
  "footer_note": "Tesekkur ederiz"
}
```

Alanlar:

- `store_name`
- `branch`
- `phone`
- `table_no`
- `datetime`
- `items[]`
- `subtotal`
- `discount`
- `grand_total`

Notlar:

- `items[].quantity` yerine `qty` da kabul edilir.
- `items[].unit_price` yerine `price` da kabul edilir.
- `items[].line_total` yerine `total` da kabul edilir.
- `date_time`, `datetime`, `dateTime` alanları kabul edilir.
- Nested `totals` objesi de halen kabul edilir.
- `subtotal` gelmezse kalem toplamlarından hesaplanır.
- `grand_total` gelmezse `subtotal - discount + service_charge` olarak hesaplanır.

## Kurulum

### 1. CUPS queue adını öğren

```bash
lpstat -p -d
```

Mümkünse termal yazıcı için ayrı bir queue kullan. ESC/POS raw iş akışı için düz/raw bir queue en temiz seçenek olur.

### 2. Ortam değişkenlerini ayarla

```bash
cp local_print_bridge/.env.example local_print_bridge/.env
```

`.env` içindeki en kritik alan:

- `PRINT_BRIDGE_PRINTER_QUEUE`

### 3. Servisi başlat

Bu klasör bilinçli olarak third-party Python paketi kullanmaz. `requirements.txt` vardır ama ilk sürüm için runtime bağımlılığı yoktur.

İstersen sanal ortamla:

```bash
cd local_print_bridge
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd ..
```

Servis `.env` dosyasını otomatik okur; ayrıca shell'e `export` etmen gerekmez:

```bash
python3 -m local_print_bridge
```

Servis varsayılan olarak `127.0.0.1:19001` üzerinde dinler.

## Test

Sağlık kontrolü:

```bash
curl http://127.0.0.1:19001/health
```

Test fişi:

```bash
curl -X POST http://127.0.0.1:19001/print/test
```

Gerçek payload ile:

```bash
curl -X POST http://127.0.0.1:19001/print/receipt \
  -H 'Content-Type: application/json' \
  --data @local_print_bridge/sample_receipt_payload.json
```

## CORS ve localhost

Servis varsayılan olarak sadece `127.0.0.1` üzerinde çalışır. Bu önemli:

- Aynı makinedeki browser erişebilir
- Ağdaki başka cihazlar doğrudan erişemez
- Browser tarafında CORS için sadece izinli origin'ler kabul edilir

`PRINT_BRIDGE_ALLOWED_ORIGINS` içinde varsayılan olarak:

- `https://ibul-ecommerce.web.app`
- `http://localhost`
- `http://localhost:3000`
- `http://127.0.0.1`
- `http://127.0.0.1:3000`

vardır.

Canlı `https://ibul-ecommerce.web.app` sayfasından `http://127.0.0.1:19001` çağrısı yapılırken bazı browser'lar Private Network Access preflight gönderir. Servis bu ilk sürümde `Access-Control-Allow-Private-Network: true` cevabını da verir.

## Web App entegrasyon planı

İlk hedef sadece adisyon:

1. Web app içinde mevcut `Adisyon` aksiyonunun receipt payload'ını üret.
2. Browser'dan `POST http://127.0.0.1:19001/print/receipt` çağrısı yap.
3. Başarılıysa UI'da "Adisyon yazdırıldı" toast göster.
4. Başarısızsa kullanıcıya net hata ver:
   - servis kapalı
   - CORS reddi
   - queue yok
   - print job submit hatası
5. Daha sonra istersen aynı anda Supabase `print_log` kaydı da bırak.

Önerilen client akışı:

```ts
await fetch("http://127.0.0.1:19001/print/receipt", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(receiptPayload),
});
```

## Mevcut Flutter web akışına uyarlama

`ibul_app/lib/screens/seller_panel_page.dart` içinde `_printGarsonAdisyon(...)` şu anda HTML açıp browser print akışına gidiyor. Bu fonksiyonu iki katmana ayırmak daha temiz olur:

1. `buildGarsonReceiptPayload(...)`
2. `sendReceiptToLocalBridge(...)`

Bu sayede mevcut masa/sipariş toplam hesapları korunur, sadece çıktı hedefi browser yerine localhost bridge olur.

Repo içine örnek bir Dart client dosyası eklendi:

- `ibul_app/lib/services/local_print_bridge_service.dart`

Örnek kullanım:

```dart
final bridge = LocalPrintBridgeService();

await bridge.printReceipt(
  LocalPrintReceiptPayload(
    storeName: storeName,
    branch: branchLabel,
    phone: phone,
    tableNo: '$tableNumber',
    dateTime: DateTime.now(),
    items: [
      LocalPrintReceiptItem(
        name: 'Izgara Kofte',
        qty: 2,
        price: 195,
        total: 390,
      ),
    ],
    subtotal: 390,
    discount: 0,
    grandTotal: 390,
  ),
);
```

## Sonraki adımlar

Bu ilk sürüm özellikle tek receipt printer içindir. Sonraki genişletmeler:

- mutfak fişi endpoint'i
- station/alan bazlı routing
- retry queue
- LaunchAgent ile otomatik açılış
- print log / job id eşleme

## Kaynak mantığı

Bu servis, ESC/POS'u uygulama tarafında raw byte olarak üretip taşıma işini CUPS'a bırakır. Böylece USB discovery/claim/endpoint karmaşası ilk sürümden çıkarılmış olur.
