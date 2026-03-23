# Security Hardening

Bu repo public olacakmış gibi düzenlendi. Client kodunda gerçek Supabase/Firebase/Google değerleri tutulmuyor; değerler çalışma anında `--dart-define` ile veriliyor ve platform secret dosyaları Git dışı tutuluyor.

## Yerel dosyalar

- `.env` dosyanızı repo kökünde tutun.
- Android için yerel `key.properties` ve gerekiyorsa keystore dosyalarını Git dışı tutun.
- Firebase native dosyalarını yerelde üretin veya kopyalayın:
  - `ibul_app/android/app/google-services.json`
  - `ibul_app/ios/Runner/GoogleService-Info.plist`
  - `ibul_app/macos/Runner/GoogleService-Info.plist`
  - `ios/Runner/GoogleService-Info.plist`

## Zorunlu dart-define anahtarları

### ibul_app

- `IBUL_SUPABASE_URL`
- `IBUL_SUPABASE_ANON_KEY`
- `IBUL_GOOGLE_CLIENT_ID`
- `IBUL_GOOGLE_SERVER_CLIENT_ID`
- `IBUL_FIREBASE_PROJECT_ID`
- `IBUL_FIREBASE_MESSAGING_SENDER_ID`
- `IBUL_FIREBASE_AUTH_DOMAIN`
- `IBUL_FIREBASE_STORAGE_BUCKET`
- `IBUL_FIREBASE_WEB_API_KEY`
- `IBUL_FIREBASE_WEB_APP_ID`
- `IBUL_FIREBASE_ANDROID_API_KEY`
- `IBUL_FIREBASE_ANDROID_APP_ID`
- `IBUL_FIREBASE_IOS_API_KEY`
- `IBUL_FIREBASE_IOS_APP_ID`
- `IBUL_FIREBASE_IOS_BUNDLE_ID`
- `IBUL_FIREBASE_MACOS_API_KEY`
- `IBUL_FIREBASE_MACOS_APP_ID`
- `IBUL_FIREBASE_MACOS_BUNDLE_ID`

Opsiyonel:

- `IBUL_FIREBASE_WEB_MEASUREMENT_ID`

### ihiz_web

- `IHIZ_SUPABASE_URL`
- `IHIZ_SUPABASE_ANON_KEY`

## Güvenli çalışma örneği

1. `.env.example` dosyasını `.env` olarak kopyalayın ve gerçek değerleri sadece yerelde doldurun.
2. Gerekliyse FlutterFire ile yerel Firebase platform dosyalarını üretin.
3. Flutter komutlarını `--dart-define` ile çalıştırın veya `.env` içeriğini shell ortamına export ederek komuta geçin.

Örnek:

```bash
set -a
source ./.env
set +a

cd ibul_app
flutter run \
  --dart-define=IBUL_SUPABASE_URL="$IBUL_SUPABASE_URL" \
  --dart-define=IBUL_SUPABASE_ANON_KEY="$IBUL_SUPABASE_ANON_KEY" \
  --dart-define=IBUL_GOOGLE_CLIENT_ID="$IBUL_GOOGLE_CLIENT_ID" \
  --dart-define=IBUL_GOOGLE_SERVER_CLIENT_ID="$IBUL_GOOGLE_SERVER_CLIENT_ID"
```

`ihiz_web` için aynı mantıkla `IHIZ_*` değişkenlerini geçin.

## Push öncesi kontrol

1. `git status --short` çıktısında `.env`, `google-services.json`, `GoogleService-Info.plist`, `key.properties`, `*.jks`, `*.keystore`, `supabase/.temp/*`, `.firebase/*`, `.vercel/*` görünmemeli.
2. `git diff --cached` ile staged içerikte gerçek key/token/url olmadığını doğrulayın.
3. Service role, admin JWT veya yüksek yetkili herhangi bir anahtarın sadece server-side env içinde kaldığından emin olun.
4. CI/CD secret değerlerini GitHub Actions/Vercel/Firebase ortam değişkenlerinden yönetin; repoya yazmayın.
