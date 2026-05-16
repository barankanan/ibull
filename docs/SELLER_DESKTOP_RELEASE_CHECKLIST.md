# Seller Desktop Release Checklist

## 1. Config

- `IBUL_SUPABASE_URL` dogru
- `IBUL_SUPABASE_ANON_KEY` dogru
- Desktop download URL'leri release asset'lerine isaret ediyor

## 2. Desktop app build

### macOS

- `./scripts/build_seller_desktop.sh`
- `./scripts/package_seller_desktop_macos.sh`
- `IbulSellerDesktop.app` aciliyor
- `IbulSellerDesktop.dmg` mount oluyor

### Windows

- `.\scripts\build_seller_desktop_windows.ps1`
- `IbulSellerDesktop.exe` aciliyor
- `IbulSellerDesktopSetup.exe` kuruluyor

## 3. Printing

- App acilisinda bridge auto-start deneniyor
- `/health` 200 donuyor
- `Yazicilari Tara` yazici listesi getiriyor
- `Adisyon Yazicisi Sec` ve `Mutfak Yazicisi Sec` kaydoluyor
- Test fisleri basiliyor
- `Bu cihazi Yazici Merkezi yap` sonrasi config Supabase'e yaziliyor

## 4. Queue flow

- Baska cihazdan siparis gonder
- Supabase `print_jobs` satiri olusuyor
- Desktop app / bridge job'i tuketiyor
- Job `printed` oluyor

## 5. Web guidance

- Browser Seller Panel'de su mesaj gorunuyor:
  `Profesyonel yazdırma için Satıcı Uygulamasını indirin.`
- Windows ve MacBook download CTA'lari calisiyor

## 6. Release assets

- Windows installer `.exe`
- macOS `.dmg`
- version / changelog notu
- kurulum notu

## 7. Son kontrol

- Seller girisi calisiyor
- Waiter girisi bozulmadi
- Logout sonrasi desktop print hub duruyor
- Restore session sonrasi panel tekrar aciliyor
