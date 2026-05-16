# Print Station Architecture

## Goal

Seller Panel artik yaziciyi acik olan tarayici cihazinda aramaz.
Tum cihazlar yalnizca Supabase uzerine print job yazar.
Restorandaki tek bir cihaz `Yazici Merkezi` olarak bridge'i arka planda
calistirir ve kuyruktaki isleri basar.

## Flow

1. Garson / Seller Panel siparisi veya adisyonu olusturur.
2. Flutter tarafi `print_jobs` kuyruğuna kayit yazar.
3. `Ibul Print Bridge` secilen Yazici Merkezi cihazinda Supabase'i poll eder.
4. Bridge `pending` job'u atomik olarak `claimed` yapar.
5. Bridge printer role'e gore yaziciyi secer:
   - `adisyon`
   - `mutfak`
6. Yazdirma sonucu job satirina geri yazilir:
   - `printing`
   - `completed`
   - `failed`
7. Bridge heartbeat gunceller; diger cihazlar Yazici Merkezi'nin cevrimici
   olup olmadigini buradan anlar.

## Config

`restaurant_print_station_configs`

- Hangi restoranin aktif print station cihazi oldugunu tutar.
- `last_seen_at` heartbeat alanidir.
- `adisyon_printer_name` ve `kitchen_printer_name` role mapping icindir.

## Retry

- Bridge yazdirma hatasinda `retry_count` artirir.
- Limit asilmadiysa job tekrar `pending` olur.
- Limit asildiysa `failed` kalir ve hata mesaji korunur.

## Offline Handling

- Yazici Merkezi cevrimdisiysa job `pending` kalir.
- Seller Panel:
  `Yazıcı merkezi çevrimdışı. Sipariş alındı ama fiş henüz basılmadı.`
- Print Station geri geldiginde bridge bekleyen queue'yu tekrar tuketir.
