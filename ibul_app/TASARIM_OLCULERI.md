# 📐 IBUL App Tasarım Ölçüleri

## 1️⃣ YAKIN LOKASYON KARELERI (Feature Menu Items)

### Boyutlar:
- **Ekran Genişliği:** 390px (standart iPhone genişliği)
- **Padding (Yatay):** 12px (her iki taraftan)
- **Grid:** 4 sütun
- **Sütunlar Arası Boşluk:** 10px
- **Toplam Kullanılabilir Genişlik:** 390 - (12 × 2) = 366px
- **Tek Kare Genişliği:** (366 - (10 × 3)) / 4 = **81.5px** ≈ **82px**
- **Tek Kare Yüksekliği:** 82px (AspectRatio 1:1 - kare)
- **Border Radius:** 16px

### Tasarım İçin Önerilen Boyut:
```
🎨 Tek Kare İçin: 164px × 164px (@2x için)
🎨 Tek Kare İçin: 246px × 246px (@3x için)
```

**Not:** Görselde 32px çapında ikon alanı olmalı (merkeze yerleştirilecek)

---

## 2️⃣ REKLAM ALANI (Banner)

### Boyutlar:
- **Ekran Genişliği:** 390px
- **Padding (Yatay):** 16px (her iki taraftan)
- **Banner Genişliği:** 390 - (16 × 2) = **358px**
- **Banner Yüksekliği:** **110px**
- **Border Radius:** 12px

### Tasarım İçin Önerilen Boyut:
```
🎨 Banner İçin: 716px × 220px (@2x için)
🎨 Banner İçin: 1074px × 330px (@3x için)
```

**Aspect Ratio:** 3.25:1 (Yatay dikdörtgen)

---

## 📱 Farklı Ekran Boyutları İçin:

### Küçük Ekranlar (< 360px):
- **Feature Menu Kare:** ~73px × 73px
- **Banner:** ~328px × 110px

### Standart Ekranlar (360-414px):
- **Feature Menu Kare:** ~82px × 82px
- **Banner:** ~358px × 110px

### Büyük Ekranlar (> 414px):
- **Feature Menu Kare:** ~95px × 95px
- **Banner:** ~390px × 110px

---

## 🎯 Tasarım Önerileri:

### Feature Menu (Yakın Lokasyon vb.):
- ✅ Görseli kenarlara 8-12px boşluk bırakarak yerleştir
- ✅ Ana renk + ikon kombinasyonu kullan
- ✅ Merkeze odaklanmış minimalist tasarım
- ✅ Arka plan rengini JSON'a ekleyebiliriz

### Banner/Reklam Alanı:
- ✅ 3:1 aspect ratio'ya uy
- ✅ Önemli bilgileri merkeze yerleştir (kenarlar crop olabilir)
- ✅ Yatay düzende tasarla
- ✅ Mobil optimizasyonu düşün (yazılar okunabilir olmalı)

---

## 📂 Dosya Formatları:
- **Format:** PNG veya JPG
- **PNG:** Şeffaf arka plan gerekiyorsa
- **JPG:** Fotoğraf/gradient içeren tasarımlar için (daha küçük dosya boyutu)
- **WebP:** Modern tarayıcılar için optimize edilmiş (opsiyonel)

---

## 💾 Kaydetme Konumları:
- **Feature Menu Görselleri:** `assets/images/features/` (yeni klasör)
- **Banner Görselleri:** `assets/images/banners/` (mevcut klasör)

---

Hazırladığın görselleri bu ölçülerde verirsen mükemmel uyum sağlar! 🎨
