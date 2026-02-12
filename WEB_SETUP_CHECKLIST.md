# Web Setup Checklist ✅

**Proje:** IBUL 2026
**Tarih:** 8 Şubat 2026
**Platform:** Flutter Web

---

## 📋 Kurulum Durumu

### Mevcut Yapı
- ✅ Flutter framework kurulu
- ✅ Firebase entegrasyonu tamamlandı
- ✅ Localization (l10n) kurulu
- ✅ Provider state management
- ✅ Android/iOS/macOS/Windows/Linux platformları
- ✅ Web klasörü hazır

### Yeni Eklenen Dosyalar
- ✅ `WEB_TASARIM_REHBERI.md` - Web tasarım rehberi
- ✅ `ibul_app/lib/responsive/breakpoints.dart` - Breakpoint sabitleri
- ✅ `ibul_app/lib/responsive/responsive_layout.dart` - Responsive widgets
- ✅ `ibul_app/lib/layouts/desktop_layout.dart` - Desktop layout

---

## 🚀 Hemen Yapılması Gereken

### 1. Responsive Layout Entegrasyonu
```bash
# Terminal'de şu komutu çalıştır:
cd ibul_app
flutter pub get
```

**Kontrol Listesi:**
- [ ] pubspec.yaml dependencies güncellenmiş
- [ ] Responsive class'ları import test edilmiş
- [ ] Breakpoint değerleri kontrol edilmiş

### 2. Main Layout Yapısı
`ibul_app/lib/screens/home_screen.dart` dosyasında yapmak gereken:

```dart
// Mevcut
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: // ...
    );
  }
}

// Değiştirilecek
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: MobileHomeScreen(),
      tablet: TabletHomeScreen(),
      desktop: DesktopHomeScreen(),
    );
  }
}
```

**Dosyalar oluşturulacak:**
- [ ] `screens/mobile/mobile_home_screen.dart`
- [ ] `screens/tablet/tablet_home_screen.dart`
- [ ] `screens/desktop/desktop_home_screen.dart`

### 3. Web Meta Tags Güncellemesi
[web/index.html](web/index.html) dosyasını güncelle:

```html
<!-- Güncellenecek alan -->
<meta name="description" content="IBUL - En iyi fiyatlarla ürün bulun">
<meta name="theme-color" content="#006b5b">
<meta property="og:title" content="IBUL - Alışveriş Platformu">
<meta property="og:description" content="Elektronik, giyim, ev ve daha fazlası en uygun fiyatlarda">
<meta property="og:image" content="assets/logo.png">
<meta property="og:url" content="https://ibul.com">
<meta name="twitter:card" content="summary_large_image">
```

---

## 📱 Mobile Layout Gereksinimleri

### Alt Navigation Bar
- Home (Ana Sayfa)
- Categories (Kategoriler)
- Search (Arama)
- Favorites (Favoriler)
- Account (Hesap)

**Dosya:** `layouts/mobile/mobile_bottom_nav.dart` (Oluşturulacak)

### Mobile Header
- Hamburger menu
- Logo / Title
- Search icon
- Notifications

**Dosya:** `layouts/mobile/mobile_header.dart` (Oluşturulacak)

---

## 🖥️ Desktop Layout Gereksinimleri

### Header Components (Hazırlandı - desktop_layout.dart)
- ✅ Logo
- ✅ Search bar
- ✅ Navigation items
- ✅ User menu
- ✅ Cart icon

### Sidebar (Hazırlandı - desktop_layout.dart)
- ✅ Kategoriler listesi
- ✅ Fiyat filtresi
- ✅ Rating filtresi

### Footer (Hazırlandı - desktop_layout.dart)
- ✅ Hakkında section
- ✅ Yardım section
- ✅ Yasal section
- ✅ Sosyal medya
- ✅ Copyright

---

## 🎨 Responsive Components Checklist

### Hazırlanması Gereken
- [ ] ProductCard (responsive)
- [ ] ProductGrid (3-4 sütun)
- [ ] BannerCarousel (responsive)
- [ ] CategoriesMenu (mega menu for desktop)
- [ ] FilterPanel (responsive)
- [ ] NavigationBar (mobile vs desktop)

---

## 🔧 Teknik Gereksinimler

### Performance Optimizasyonları
- [ ] Image lazy loading
- [ ] Ülkenizin kurallarına göre pagination
- [ ] Cache stratejisi
- [ ] Web bundle optimization

### Browser Uyumluluğu
- [ ] Chrome/Chromium (test edilecek)
- [ ] Firefox (test edilecek)
- [ ] Safari (test edilecek)
- [ ] Edge (test edilecek)

### Firebase Web Setup
- [ ] firebaseOptions.dart kontrol
- [ ] CORS konfigürasyonu
- [ ] Authentication flow (web-specific)
- [ ] Firestore security rules

---

## 📝 Dosya Oluşturma Sırası

**Week 1 - Responsive Foundation**
1. ✅ breakpoints.dart
2. ✅ responsive_layout.dart
3. ✅ desktop_layout.dart
4. [ ] mobile_layout.dart
5. [ ] tablet_layout.dart

**Week 2 - Screen Adaptasyonları**
6. [ ] home_screen_responsive.dart
7. [ ] product_detail_responsive.dart
8. [ ] search_results_responsive.dart
9. [ ] categories_responsive.dart

**Week 3 - Components**
10. [ ] responsive_product_card.dart
11. [ ] responsive_product_grid.dart
12. [ ] responsive_filters.dart
13. [ ] responsive_navigation.dart

**Week 4 - Polish & Optimization**
14. [ ] Meta tags ve SEO
15. [ ] Performance optimization
16. [ ] Browser testing
17. [ ] Deployment configuration

---

## 🧪 Test Planı

### Manual Testing Checklist
- [ ] Chrome desktop (1920x1080)
- [ ] Chrome desktop (1366x768)
- [ ] Chrome desktop (1024x768)
- [ ] Chrome mobile (iPhone 12)
- [ ] Chrome mobile (Samsung Galaxy)
- [ ] Tablet view (iPad)
- [ ] Firefox desktop
- [ ] Safari desktop
- [ ] Edge desktop

### Automated Testing
- [ ] Unit tests for responsive builders
- [ ] Widget tests for adaptive layouts
- [ ] Golden tests for different screen sizes

---

## 🚀 Deployment Hazırlığı

### Production Build
```bash
# Web build for production
flutter build web --release

# Output location: build/web/
```

### Firebase Hosting (Önerilen)
```bash
# Firebase CLI kurulum
npm install -g firebase-tools

# Firebase init ve deploy
firebase init hosting
firebase deploy --only hosting
```

### Domain Configuration
- [ ] Domain SSL sertifikası
- [ ] DNS konfigürasyonu
- [ ] Firebase hosting config

---

## 📞 İletişim ve Destek

**Sorular veya İhtiyaçlar:**
- [ ] Tasarım değişiklikleri
- [ ] API entegrasyonları
- [ ] Performance problemleri
- [ ] Browser uyumluluk sorunları

---

## 📚 Referanslar

- [Flutter Responsive Design](https://flutter.dev/docs/development/ui/layout/responsive)
- [Firebase Web Documentation](https://firebase.flutter.dev/docs/overview/)
- [Material 3 Design System](https://m3.material.io/)
- [Web Performance Best Practices](https://web.dev/performance/)

---

**Son Güncelleme:** 8 Şubat 2026 ✏️
**Sonraki Gözden Geçirme:** -
