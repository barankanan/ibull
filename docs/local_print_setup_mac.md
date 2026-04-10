# macOS Yerel Yazıcı Servisi Kurulumu

## 1. Yazıcı servisi nedir

IBUL web paneli adisyon ve test fişini bu bilgisayarda çalışan yerel yazıcı servisine gönderir.

Bu servis repo kökündeki `app.py` dosyasını çalıştırır ve `http://127.0.0.1:3001` adresinde yanıt verir.

## 2. Nasıl kontrol edilir

- Garson ekranındaki `Yazıcı Servisi` kartına bakın.
- `Yazıcı bağlı` görünüyorsa servis hazırdır.
- `Yenile` ile durumu tekrar kontrol edin.
- İsterseniz tarayıcıda `http://127.0.0.1:3001/health` adresini açın. `ok: true` benzeri bir yanıt görünmelidir.

## 3. macOS'ta tek seferlik otomatik başlatma kurulumu

1. `~/Library/LaunchAgents` klasörünü açın.
2. Aşağıdaki içeriği `~/Library/LaunchAgents/com.ibul.localprint.plist` olarak kaydedin.
3. Plist içindeki `app.py` yolunu kendi bilgisayarınızdaki gerçek repo yoluna göre güncelleyin.
4. Terminalde bu iki komutu bir kez çalıştırın:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ibul.localprint.plist
launchctl kickstart -k gui/$(id -u)/com.ibul.localprint
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.ibul.localprint</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/python3</string>
    <string>/Users/USERNAME/Desktop/ibul2026 kopyası 9/app.py</string>
  </array>
  <key>WorkingDirectory</key>
  <string>/Users/USERNAME/Desktop/ibul2026 kopyası 9</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/ibul-local-print.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/ibul-local-print.error.log</string>
</dict>
</plist>
```

Bu kurulumdan sonra bilgisayar açıldığında yazıcı servisi otomatik başlar.

## 4. Health kontrolü

- Web panelindeki `Yenile` butonunu kullanın.
- `Test Yazdır` ile örnek fiş gönderin.
- Tarayıcıda `http://127.0.0.1:3001/health` açılmıyorsa servis çalışmıyordur.

## 5. Sorun giderme

- Panelde `Yazıcı servisi kapalı` görünüyorsa önce bilgisayarı yeniden başlatıp tekrar deneyin.
- Sorun devam ederse plist içindeki `python3` ve `app.py` yollarını kontrol edin.
- Gerekirse loglara bakın: `/tmp/ibul-local-print.log` ve `/tmp/ibul-local-print.error.log`.
- Yazıcı açık değilse veya USB bağlı değilse test fişi yazdırılamayabilir.
