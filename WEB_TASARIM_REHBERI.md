# IBUL Web Tasarım Rehberi

**Son Güncelleme:** 8 Şubat 2026

## 📋 Proje Özeti

IBUL, Flutter ile geliştirilmiş responsive bir e-ticaret platformudur. Web, mobil ve masaüstü platformlarını desteklemektedir.

### Teknoloji Stack
- **Framework:** Flutter 3.10.7+
- **Backend:** Firebase (Firestore, Authentication, Storage)
- **State Management:** Provider
- **Localization:** Flutter Localizations (Turkish/English)
- **Maps:** flutter_map, latlong2
- **UI Components:** Material 3 Design System

---

## 🎯 Web Tasarım Stratejisi

### 1. **Responsive Breakpoints**

```
Mobile:      0px - 599px   (Telefon)
Tablet:      600px - 1199px  (Tablet)
Desktop:     1200px+       (Bilgisayar)
```

### 2. **Desktop Layout Özellikleri**

#### Header/Navigation
- [ ] Horizontal navigation bar (sabit veya sticky)
- [ ] Logo + arama çubuğu + kategoriler + kullanıcı menüsü
- [ ] Desktop mega menu (kategoriler için)
- [ ] Arama otomatik tamamlama (autocomplete)

#### Sidebar (Sol Panel)
- [ ] Kategoriler hiyerarşisi
- [ ] Filtreleme seçenekleri
- [ ] Fiyat aralığı seçici
- [ ] İşletmelere göre filtre

#### Ana İçerik Alanı
- [ ] Ürün grid layout (3-4 sütun)
- [ ] Banner carousel (otomatik slide)
- [ ] Öne çıkan işletmeler
- [ ] Trending ürünler

#### Footer
- [ ] Hakkında
- [ ] Yardım ve İletişim
- [ ] Sosyal medya bağlantıları
- [ ] Gizlilik Politikası ve Şartlar

### 3. **Mobil Layout Özellikleri**

#### Header
- [ ] Hamburger menu
- [ ] Bottom navigation bar (sabit)
- [ ] Logo ortalı

#### Navigation
- [ ] Alt kısımda navigation (5-6 tab)
- [ ] Kategoriler drawer menüde

#### İçerik
- [ ] Full-width ürün cards
- [ ] Single column layout
- [ ] Swipe gesture desteği

---

## 📁 Dosya Yapısı (Önerilen)

```
ibul_app/lib/
├── responsive/
│   ├── responsive_layout.dart      # Ana responsive wrapper
│   ├── breakpoints.dart            # Breakpoint sabitleri
│   └── responsive_builder.dart     # Responsive builder widgets
├── layouts/
│   ├── desktop_layout.dart         # Desktop ana layout
│   ├── tablet_layout.dart          # Tablet ana layout
│   ├── mobile_layout.dart          # Mobil ana layout
│   ├── widgets/
│   │   ├── desktop_header.dart
│   │   ├── desktop_sidebar.dart
│   │   ├── desktop_footer.dart
│   │   ├── mobile_bottom_nav.dart
│   │   └── mobile_header.dart
│   └── components/
│       ├── product_grid.dart
│       ├── filters_panel.dart
│       ├── banner_carousel.dart
│       └── category_menu.dart
└── screens/
    └── [Mevcut screens]
```

---

## 🎨 Design System

### Renkler
- **Primary:** `AppColors.primary` (Ana brand rengi)
- **Background:** `AppColors.background`
- **Success:** Yeşil
- **Error:** Kırmızı
- **Warning:** Turuncu

### Responsive Padding/Margin
```dart
// Desktop
padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24)

// Tablet
padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16)

// Mobile
padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)
```

### Typography (Material 3)
- **Headings:** displayLarge, displayMedium, headlineLarge, headlineMedium
- **Body:** bodyLarge, bodyMedium, bodySmall
- **Labels:** labelLarge, labelMedium

---

## ✅ Web Build Kontrol Listesi

### Başlangıç (Week 1)
- [ ] Responsive layout framework oluştur
- [ ] Desktop header/footer componentleri
- [ ] Breakpoint sistemini kur
- [ ] Navigation mantığını responsive hale getir

### Tasarım (Week 2)
- [ ] Desktop ana sayfa tasarımı
- [ ] Ürün grid ve filtreleme
- [ ] Kategoriler mega menu
- [ ] Banner ve carousel

### Optimizasyon (Week 3)
- [ ] Web-specific performans optimizasyonları
- [ ] SEO meta tags
- [ ] Progressive Web App (PWA) setup
- [ ] Lazy loading görseller

### Testing (Week 4)
- [ ] Desktop tarayıcı uyumluluğu
- [ ] Responsiveness testing
- [ ] Performance testing
- [ ] Firebase integration test

---

## 🚀 Web-Specific Optimizasyonlar

### 1. **Web Build Komutu**
```bash
flutter build web --release
```

### 2. **Tarayıcı Uyumluluğu**
- Chrome/Chromium ✓
- Firefox ✓
- Safari ✓
- Edge ✓

### 3. **Meta Tags (index.html)**
```html
<meta name="theme-color" content="#006b5b">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="description" content="IBUL - Alışveriş Platformu">
<meta property="og:title" content="IBUL">
<meta property="og:description" content="En iyi fiyatlarla ürün bulun">
<meta property="og:image" content="logo.png">
```

### 4. **PWA Configuration**
- Web app manifest yapılandır
- Service worker kur
- Offline desteği ekle

---

## 📊 Sayfa Tasarımı Detayları

### Ana Sayfa (Home)
```
┌─────────────────────────────────┐
│      Header + Navigation        │
├──────────────┬──────────────────┤
│              │                  │
│ Kategoriler  │  Banner Carousel │
│ (Sidebar)    │  + Featured      │
│              │                  │
│              ├──────────────────┤
│              │ Trending         │
│              │ Products Grid    │
│              │ (3-4 sütun)      │
│              │                  │
└──────────────┴──────────────────┘
│      Footer                     │
└─────────────────────────────────┘
```

### Ürün İçeriği Sayfası
```
┌─────────────────────────────────┐
│      Header + Navigation        │
├──────────────┬──────────────────┤
│              │                  │
│ Filtreleme   │  Product Image   │
│ Paneli       │  + Details       │
│              │  + Reviews       │
│              │  + Related       │
└──────────────┴──────────────────┘
```

---

## 🔗 Firebase Web Configuration

Mevcut Firebase entegrasyonu web platformunda çalışacak şekilde kurulmuştur:
- `firebase_options.dart` web konfigürasyonunu içerir
- Cloud Firestore bağlantısı aktif
- Authentication sistem hazır
- Storage yükleme işlevsel

### Web-Specific Kuralları
```
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Web tarayıcısından okuma izni
    match /products/{document=**} {
      allow read: if request.auth != null || true;
      allow write: if request.auth.uid == resource.data.userId;
    }
  }
}
```

---

## 📱 Responsive Components Örnekleri

### ResponsiveBuilder Widget
```dart
ResponsiveLayout(
  mobile: MobileLayout(),
  tablet: TabletLayout(),
  desktop: DesktopLayout(),
)
```

### Dinamik Grid
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 :
                     MediaQuery.of(context).size.width > 600 ? 2 : 1,
  ),
  itemCount: products.length,
  itemBuilder: (context, index) => ProductCard(products[index]),
)
```

---

## ⚙️ Geliştirme Workflow

### Local Development
```bash
# Web sunucusu ile çalıştır
flutter run -d web-server

# Android emülatörde test et
flutter run -d emulator-5554

# iOS simulatörde test et
flutter run -d iphone
```

### Desktop Preview
```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

---

## 🐛 Bilinen Sorunlar ve Çözümler

| Sorun | Çözüm |
|-------|------|
| Web'de harita yüklenmezse | Web API key kontrol et |
| Google Fonts yüklenmezse | pubspec.yaml'de font paketi kontrol et |
| Responsive tasarım kırılırsa | Breakpoint değerlerini MediaQuery ile test et |
| Firebase bağlantı hatası | firebaseOptions.dart konfigürasyonunu kontrol et |

---

## 📚 İlgili Dosyalar

- [Flutter Web Documentation](https://flutter.dev/web)
- [Firebase Web Setup](https://firebase.flutter.dev/docs/overview/)
- [Material 3 Design](https://m3.material.io/)
- Firebase Configuration: `ibul_app/lib/firebase_options.dart`
- Constants: `ibul_app/lib/core/constants.dart`

---

## 👥 Takım Notları

**Şu an hazır olan:**
- ✅ Firebase backend
- ✅ Localization (Turkish/English)
- ✅ State management (Provider)
- ✅ Mevcut screen öğeleri
- ✅ Asset yönetimi

**Yapılması gereken:**
- [ ] Responsive layout wrapper
- [ ] Desktop-specific components
- [ ] Web navigation pattern
- [ ] Mobile-optimized layouts
- [ ] Performance optimizasyonları

---

**Soruların varsa veya eklemeler gerekiyorsa, bu dosyayı güncelleyelim!**
