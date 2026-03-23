# İhız Web

`ihiz_web`, iBul'dan ayrı çalışan ama aynı operasyon mantığına bağlanacak kurye sitesidir.

## Local deneme

`ihiz_web` uygulamasını ayrı portta açın:

```bash
cd ihiz_web
./scripts/run_local_web.sh
```

Bu uygulama artık `IHIZ_SUPABASE_URL` ve `IHIZ_SUPABASE_ANON_KEY`
değerlerini `--dart-define` ile bekler. Detaylar için `../SECURITY_HARDENING.md`
ve repo kökündeki `.env.example` dosyasına bakın.

Notlar:

- Script, `8083`'ten başlayarak boş portu otomatik seçer (port dolu hatası vermez).
- `flutter run` foreground çalıştığı için terminalde `r`, `R`, `q` tuşları aktif kalır.
- Sabit port istersen: `./scripts/run_local_web.sh --port 8083`

Ardından iBul uygulamasını ayrı portta açın:

```bash
cd ibul_app
flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1
```

Bu düzenle:

- `http://127.0.0.1:8080` = iBul
- `http://127.0.0.1:8083` (veya scriptin seçtiği boş port) = İhız

`iBul` içindeki footer `İhız` bağlantısı sabit porta bağlıysa, footer linkini aynı porta göre güncelleyin.

## Sonraki aşama

Canlıya geçerken aynı yapı şu adreslere taşınabilir:

- `ibul.com`
- `ihiz.com`

İki site ayrı kalır; sipariş, kurye rolü ve görev havuzu aynı backend üzerinden bağlanır.
