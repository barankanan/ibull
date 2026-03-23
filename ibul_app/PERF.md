# Uygulama Hızı ve Görsel Optimizasyon Rehberi

## Yapılan / Uygulanabilir İyileştirmeler

### 1. Görsel optimizasyonu
- **Ağ görselleri:** `Image.network` yerine `CachedNetworkImage` kullanımı (diskte önbellek, tekrar yüklemede hız).
- **Cache boyutları:** `cacheWidth` ve `cacheHeight` ile decode edilen piksel boyutunu sınırlama (bellek ve CPU tasarrufu).
- **Ortak widget:** `OptimizedImage` – URL için CachedNetworkImage + cache boyutları, asset için `Image.asset` + cache boyutları.
- **Sunucu tarafı:** Ürün görselleri CDN’den sunuluyorsa, URL parametreleri ile küçük boyutlu versiyon iste (örn. `?w=400&h=400`).

### 2. Görsel depolama (sunucu / Supabase)
- **Yüklemeden önce sıkıştırma:** Zaten `flutter_image_compress` ile yapılıyor; hedef boyutu (örn. max 800px genişlik) koruyun.
- **Format:** Web için JPEG, mobil için WebP tercih edilebilir (Storage’da alan tasarrufu).
- **Thumbnail üretimi:** Büyük görseller için ayrı küçük versiyonlar (thumbnail) oluşturup liste/kartlarda onları kullanın.

### 3. Liste ve grid performansı
- **ListView.builder / GridView.builder:** Uzun listelerde `ListView`/`GridView` yerine `builder` kullanın (lazy loading).
- **itemExtent / prototypeItem:** Mümkünse sabit yükseklik veya prototype ile scroll performansını artırın.
- **Gereksiz rebuild:** `const` constructor, `RepaintBoundary` (özellikle kartlar için) kullanın.

### 4. Sayfa ve navigasyon
- **Lazy load:** Ağır sayfaları ilk açılışta değil, sekme/ekran görünür olduğunda yükleyin.
- **Route’lar:** Gereksiz `Navigator.push` ile taşınan büyük veri yerine ID ile veri çekin.

### 5. Build ve bundle
- **Tree shaking:** Kullanılmayan import ve kodları kaldırın.
- **Split per platform:** Sadece gereken platform kodunu dahil edin.
- **Assets:** Kullanılmayan görselleri projeden çıkarın; büyük PNG’leri WebP/JPEG ile değiştirin.

### 6. Ağ ve veri
- **API yanıtları:** Gereksiz alanları döndürmeyin; sayfalama kullanın.
- **Supabase:** Select’te sadece ihtiyaç duyulan kolonları isteyin.

### 7. Genel
- **Debug modda yavaşlık:** Release modda (`flutter run --release` veya `flutter build apk`) test edin.
- **Profil:** `flutter run --profile` ve DevTools ile frame sürelerini ve belleği inceleyin.

---

## Öncelik sırası (kısa)

1. Tüm ağ görsellerinde **CachedNetworkImage + cacheWidth/cacheHeight**.
2. Liste/grid’lerde **builder** ve mümkünse **itemExtent / prototypeItem**.
3. **OptimizedImage** gibi ortak widget ile tutarlı cache boyutları.
4. Sunucuda/Storage’da **thumbnail** ve **sıkıştırılmış** görsel kullanımı.
5. **Release** build ile ölçüm; gerekiyorsa **RepaintBoundary** ve **const** artırımı.
