# Windows Geliştirme Kurulumu ve Repo Taşıma Rehberi

Bu belge, ~13 GB görünen yerel klasörü **elle kopyalamadan** GitHub private repo üzerinden Mac ↔ Windows sürdürülebilir akışa geçirmek içindir.

---

## 1. Boyut analizi (Mac’te ölçülen özet)

| Konum | Yaklaşık boyut | Git’e girmeli mi? |
|--------|----------------|-------------------|
| `build/` (kök seller desktop) | **~10 GB** | Hayır |
| `.dart_tool/` (kök) | **~1.1 GB** | Hayır |
| `ibul_app/` (kaynak + küçük build) | ~532 MB | Evet (kaynak) |
| `restaurant-ops-web/node_modules/` | ~359 MB | Hayır |
| `ios/Pods/` | ~185 MB | Hayır |
| `ihiz_web/build/` | ~119 MB | Hayır |
| `local_print_bridge/windows/dist/` | ~21 MB | Hayır |
| **Git takip edilen toplam** | **~31 MB** (1092 dosya) | Evet |
| **`.git/` klasörü** | **~75 MB** | — |

**Sonuç:** 13 GB’ın neredeyse tamamı yeniden üretilebilir derleme/cache. Repo zaten büyük ikili dosyaları taşımıyor; sorun çoğunlukla USB/kopya ile tüm klasörü taşımaya çalışmak.

`git clone` sonrası tipik disk kullanımı (tahmini):

- Clone: **~30–80 MB**
- `flutter pub get` (kök + `ibul_app` + `ihiz_web`): **~500 MB–1.5 GB**
- `npm install` (restaurant-ops-web): **~350 MB**
- Python venv: **~50–150 MB**
- İlk `flutter build windows`: **+1–3 GB** `build/`

Toplam geliştirme ortamı genelde **2–5 GB**; 13 GB değil.

---

## 2. Git’e girmesi gerekenler

| Kategori | Örnekler |
|----------|----------|
| Dart/Flutter kaynak | `lib/`, `ibul_app/lib/`, `ihiz_web/lib/`, `pubspec.yaml`, `pubspec.lock` |
| Platform projeleri | `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/` (kaynak; `Pods/`/`build/` hariç) |
| Supabase | `supabase/migrations/`, `*.sql` şema dosyaları |
| Python bridge kaynak | `local_print_bridge/*.py`, `requirements.txt`, `windows/*.ps1`, `*.iss` |
| Next.js kaynak | `restaurant-ops-web/app/`, `package.json`, `package-lock.json` |
| Scriptler | `scripts/`, `docs/` |
| Örnek env | `.env.example`, `local_print_bridge/.env.example` |
| Küçük asset’ler | `assets/`, banner PNG’ler (<2 MB), ikon setleri |

---

## 3. Git’e girmemesi gerekenler

| Kategori | Örnekler |
|----------|----------|
| Flutter build/cache | `build/`, `.dart_tool/`, `*.dill` |
| Node | `node_modules/`, `.next/`, `out/` |
| Python | `.venv/`, `__pycache__/`, `local_print_bridge/.deps/`, `windows/dist/*.exe` |
| Native cache | `ios/Pods/`, `**/.gradle/` |
| Gizliler | `.env`, `google-services.json`, keystore |
| Installer çıktıları | `*.exe`, `*.dmg`, `*.msi`, `*.apk` |
| OS/IDE | `.DS_Store`, `Thumbs.db`, `.idea/` (isteğe bağlı `.vscode/` yerel ayarları) |

Kök `.gitignore` bu kuralları tek yerde toplar.

---

## 4. Mac’te taşımadan önce temizlik (opsiyonel, önerilir)

Yerel diskten silinir; Git geçmişini etkilemez:

```bash
cd "/path/to/ibul2026"

# Flutter
flutter clean
(cd ibul_app && flutter clean)
(cd ihiz_web && flutter clean)

# Node
rm -rf restaurant-ops-web/node_modules restaurant-ops-web/.next

# Python
rm -rf .venv local_print_bridge/.venv local_print_bridge/.deps

# Büyük build klasörü (en büyük kazanç)
rm -rf build ibul_app/build ihiz_web/build

# iOS pods (Mac’te yeniden: cd ios && pod install)
rm -rf ios/Pods ibul_app/ios/Pods

# Android gradle cache
rm -rf android/.gradle ibul_app/android/.gradle
```

Sonra yalnızca Git durumunu kontrol edin:

```bash
git status
du -sh . .git
```

---

## 5. Git geçmişinden yanlışlıkla eklenen dosyaları temizleme

Şu an `.git` ~75 MB; büyük ikili geçmiş yok. Yine de **`.DS_Store` indekslenmiş** — kaldırın:

```bash
# İndeksten çıkar (dosyayı diskten silmez)
git rm -r --cached .DS_Store 2>/dev/null || true
find . -name .DS_Store -print0 | xargs -0 git rm --cached -f 2>/dev/null || true

git add .gitignore
git commit -m "chore: tighten gitignore and stop tracking .DS_Store"
```

### Geçmişte büyük dosya varsa (ileride `git count-objects -vH` >500MB ise)

**Uyarı:** Geçmiş yeniden yazılır; tüm klonlar `force push` + yeniden clone gerektirir.

```bash
# 1) Büyük blob’ları bul
git rev-list --objects --all | \
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
  awk '/^blob/ {if ($3>5000000) print $3/1024/1024 " MB", $4}' | sort -rn | head -30

# 2) git-filter-repo ile temizle (kur: brew install git-filter-repo)
git filter-repo --path build/ --invert-paths
git filter-repo --path-glob '**/*.exe' --invert-paths
git filter-repo --path-glob '**/node_modules/**' --invert-paths

# 3) Uzak repoya (ekip onayından sonra)
git push origin --force --all
git push origin --force --tags
```

Alternatif (BFG):

```bash
bfg --delete-folders build --delete-folders node_modules .
bfg --delete-files '{*.exe,*.dmg,*.DS_Store}' .
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

---

## 6. GitHub private repo kurulumu

### Mac (ilk push)

```bash
cd "/path/to/ibul2026"
git remote add origin git@github.com:ORG/ibul2026.git   # veya HTTPS
git branch -M main
git push -u origin main
```

### Windows (ilk clone)

```powershell
cd $env:USERPROFILE\dev
git clone git@github.com:ORG/ibul2026.git
cd ibul2026
```

SSH anahtarı: [GitHub SSH docs](https://docs.github.com/en/authentication/connecting-to-github-with-ssh).

---

## 7. Windows ön koşullar

| Araç | Sürüm | Not |
|------|--------|-----|
| [Git for Windows](https://git-scm.com/download/win) | son | |
| [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) | stable, SDK ^3.10.7 | `flutter doctor` |
| [Visual Studio 2022](https://visualstudio.microsoft.com/) | Desktop C++ workload | Windows desktop build |
| [Python](https://www.python.org/downloads/) | 3.11+ | “Add to PATH” |
| [Node.js LTS](https://nodejs.org/) | 20+ | restaurant-ops-web için |
| (Opsiyonel) Inno Setup 6 | | Installer derlemek için |

```powershell
flutter doctor -v
python --version
node --version
git --version
```

---

## 8. Ortam değişkenleri

```powershell
cd $env:USERPROFILE\dev\ibul2026
Copy-Item .env.example .env
# .env içini doldur: IBUL_SUPABASE_URL, IBUL_SUPABASE_ANON_KEY, Firebase anahtarları, vb.

Copy-Item local_print_bridge\.env.example local_print_bridge\.env
# Windows’ta PRINT_BRIDGE_PRINTER_QUEUE = Yazıcılar listesindeki tam ad
```

Gizliler **asla** commit edilmez; Mac ve Windows’ta ayrı `.env` kopyaları tutulur (1Password / güvenli not).

---

## 9. Flutter kurulumu

Monorepo’da üç Flutter kökü var:

| Klasör | Amaç |
|--------|------|
| `/` (kök) | **Seller Desktop** — `lib/main_seller.dart` |
| `ibul_app/` | Ana mobil/web uygulama |
| `ihiz_web/` | İhiz web modülü |

```powershell
# Kök — Seller Desktop (Windows’ta asıl test hedefi)
cd $env:USERPROFILE\dev\ibul2026
flutter pub get

# ibul_app
cd ibul_app
flutter pub get
cd ..

# ihiz_web (gerekirse)
cd ihiz_web
flutter pub get
cd ..
```

### Seller Desktop çalıştırma

`.env` yüklendikten sonra:

```powershell
cd $env:USERPROFILE\dev\ibul2026
.\scripts\build_seller_desktop_windows.ps1 -BuildOnly
```

Veya doğrudan (`.env` içindeki değişkenlerle):

```powershell
flutter run -d windows --target lib/main_seller.dart `
  --dart-define=IBUL_SUPABASE_URL=$env:IBUL_SUPABASE_URL `
  --dart-define=IBUL_SUPABASE_ANON_KEY=$env:IBUL_SUPABASE_ANON_KEY
```

`scripts/build_seller_desktop_windows.ps1` kök `.env` dosyasını okur.

### ibul_app (mobil/web)

```powershell
cd ibul_app
flutter run -d chrome
# veya
flutter run -d windows
```

---

## 10. Python print bridge

### Geliştirme modu (venv)

```powershell
cd $env:USERPROFILE\dev\ibul2026\local_print_bridge
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
# Windows yazdırma için:
pip install pywin32

Copy-Item .env.example .env
# .env düzenle

cd ..
python -m local_print_bridge
```

Sağlık kontrolü: `http://127.0.0.1:3001/health`

### Installer derleme (yalnızca Windows’ta)

```powershell
cd local_print_bridge\windows
.\build_windows_installer.ps1 -AppVersion 1.0.0
```

Çıktı: `local_print_bridge\windows\dist\` (Git’e **girmez**).

---

## 11. Next.js — restaurant-ops-web

```powershell
cd $env:USERPROFILE\dev\ibul2026\restaurant-ops-web
Copy-Item .env.example .env.local   # varsa
npm ci
npm run dev
```

Tarayıcı: `http://localhost:3000`

---

## 12. Windows test komutları özeti

```powershell
# Print bridge
curl http://127.0.0.1:3001/health

# Seller desktop
cd $env:USERPROFILE\dev\ibul2026
flutter test
flutter analyze
flutter run -d windows --target lib/main_seller.dart

# ibul_app
cd ibul_app
flutter analyze

# Next.js
cd ..\restaurant-ops-web
npm run typecheck
```

Yazıcı testi: Seller Desktop → Yazıcı kurulumu → “Yazıcıları Tara” → Test fişi (bridge açık olmalı).

---

## 13. Mac ↔ Windows Git akışı

```
Mac: feature branch → commit → push
        ↓
GitHub (private)
        ↓
Windows: git pull → test → (fix varsa) commit → push
        ↓
Mac: git pull → merge/review
```

### Kurallar

1. **Asla** `build/`, `node_modules/`, `.venv/`, `.env` commit etmeyin.
2. `pubspec.lock` ve `package-lock.json` **commit edin** (deterministik kurulum).
3. Büyük SQL migration’lar normal Git ile kalır.
4. Conflict’te lock dosyalarında dikkatli merge; şüphede `flutter pub get` / `npm ci` yeniden çalıştırın.
5. Platforma özel değişiklikler aynı branch’te olabilir; mümkünse `feature/windows-print-fix` gibi açıklayıcı isimler.

### Örnek günlük akış

**Mac’te:**

```bash
git checkout -b feature/seller-image-fix
# ... kod ...
git add -A && git status   # build/node_modules görünmemeli
git commit -m "fix: seller image upload on desktop"
git push -u origin feature/seller-image-fix
```

**Windows’ta:**

```powershell
git fetch origin
git checkout feature/seller-image-fix
git pull
flutter pub get
# test ...
git push
```

---

## 14. Büyük dosyalar: Git LFS vs Drive vs GitHub Release

| İçerik | Öneri | Neden |
|--------|--------|--------|
| Kaynak kod, SQL, küçük PNG | **Normal Git** | Diff, review, clone hızlı |
| 1–5 MB banner/asset | Git (şimdiki gibi) veya sıkıştırma | Repo ~31 MB seviyesinde OK |
| **>10 MB** video, ham PSD, dataset | **Git LFS** veya hiç repo dışı | Git şişer |
| **Installer** (`IbulPrintBridgeSetup.exe`, Seller Setup) | **GitHub Release** veya Firebase Hosting | Zaten `build/web/downloads/` modeli var |
| Ekip arası geçici büyük dosya | **Google Drive / shared folder** | Versiyon kontrolü gerekmez |
| Müşteriye dağıtım | Release + indirme URL (`IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL`) | Uygulama içi indirme linki |

### Git LFS (yalnızca gerçekten gerekirse)

```bash
git lfs install
git lfs track "*.mp4" "*.mov" "*.psd"
git add .gitattributes
```

LFS kotası ve bant genişliği için GitHub planınızı kontrol edin. Installer’lar için LFS yerine **Release asset** tercih edin.

---

## 15. İlk Windows kurulum kontrol listesi

- [ ] `git clone` tamamlandı (~31 MB kaynak)
- [ ] `.env` ve `local_print_bridge/.env` oluşturuldu
- [ ] `flutter doctor` yeşil (Windows desktop)
- [ ] Kök + `ibul_app` → `flutter pub get`
- [ ] `local_print_bridge` venv + `pip install -r requirements.txt` + `pywin32`
- [ ] Bridge `http://127.0.0.1:3001/health` OK
- [ ] `flutter run -d windows --target lib/main_seller.dart` açılıyor
- [ ] (Opsiyonel) `restaurant-ops-web` → `npm ci` → `npm run dev`
- [ ] `.DS_Store` commit edilmiyor (`git status` temiz)

---

## 16. Sorun giderme

| Belirti | Çözüm |
|---------|--------|
| Clone sonrası proje yine çok büyük | Yanlışlıkla `build/` veya `node_modules` kopyalanmış; silin, `.gitignore` güncel olsun |
| `flutter pub get` ibul_app bulamıyor | Kök `pubspec.yaml` içinde `path: ./ibul_app`; önce kökten `pub get` |
| Bridge bağlanmıyor | `python -m local_print_bridge`, firewall, port 3001 |
| Windows yazdırmıyor | Yazıcı adı `.env` `PRINT_BRIDGE_PRINTER_QUEUE` ile birebir aynı; `pywin32` kurulu |
| PowerShell script çalışmıyor | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |

İlgili belgeler: `docs/SELLER_DESKTOP_SETUP.md`, `local_print_bridge/windows/README.md`, `SECURITY_HARDENING.md`.
