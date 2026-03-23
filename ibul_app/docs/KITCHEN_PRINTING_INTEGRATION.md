# Kitchen Printing Integration Strategy

## Current architecture (implemented)
- Garson sipariş akışı, fiziksel yazdırma yerine `print_jobs` kuyruğu üretir.
- Backend transaction fonksiyonu: `public.create_table_order_with_print_jobs(...)`
  - `orders` + `order_items` oluşturur
  - `station` bazlı ayırır
  - `printer` eşlemesini bulur
  - `print_jobs` + `print_job_items` üretir
- Flutter tarafı sadece bu kuyruğu tetikler ve log ekranında izler.

## Why queue-first design
- Flutter UI ve yazıcı donanımı birbirine sıkı bağlı olmaz.
- Yazdırma başarısız olsa bile sipariş kaydı korunur; job retry ile toparlanır.
- Aynı queue farklı worker tipleriyle tüketilebilir.

## Next step: local print agent
1. Yerel ağda çalışan bir agent (Node/Python/Go) kur.
2. Agent `print_jobs` tablosunda `pending` kayıtları poll etsin veya websocket ile dinlesin.
3. İşi `printing` durumuna çeksin (optimistic lock önerilir).
4. ESC/POS raw komutlarını yazıcıya gönderip sonucu `printed` / `failed` olarak geri yazsın.

## Edge Function / webhook option
- Edge Function, `print_jobs` insert eventlerini webhook ile bir agent gateway’e iletebilir.
- Güvenlik için:
  - signed secret
  - restaurant bazlı token
  - replay protection

## ESC/POS notes
- Ağ yazıcıları için genelde TCP `9100` portu kullanılır.
- Kağıt genişliği (`paper_width_mm`) 58/80mm formatına göre şablon seçimi yapılmalıdır.
- Türkçe karakter desteği için codepage ayarı agent tarafında yönetilmelidir.

## Flutter side alternatives
- Network printer paketleri ile doğrudan yazdırma mümkün olsa da,
  production senaryoda queue + agent modeli daha güvenli ve ölçeklenebilir.
- Bluetooth/USB senaryolarında da aynı queue korunup agent cihazı köprü olarak kullanılabilir.

## Operational recommendations
- `print_jobs(status='failed')` için otomatik retry policy eklenmeli.
- `retry_count` eşiği sonrası manuel müdahale alarmı üretilmeli.
- Log ekranında order/station/printer bazlı filtreler aktif tutulmalı.
