# Ürün Varyant Sistemi Kullanım Kılavuzu

## Genel Bakış

Ürün varyant sistemi, aynı ürünün farklı seçeneklerini (renk, depolama, boyut, vb.) tek bir ürün sayfasında göstermenizi sağlar. Bu, e-ticaret sitelerinde yaygın olarak kullanılan bir özelliktir.

### Örnek Kullanım Senaryoları

- **iPhone 15 Pro Max**: 3 renk (Titanyum Mavi, Siyah, Beyaz) × 3 depolama (256GB, 512GB, 1TB) = 9 varyant
- **Samsung Galaxy S24 Ultra**: 4 renk × 2 depolama = 8 varyant  
- **Nike Ayakkabı**: 5 renk × 10 beden = 50 varyant
- **Elektrikli Ürün**: 2 voltaj seçeneği (110V, 220V)

---

## CSV Format ve Kullanımı

### Varyant Kolonları

CSV dosyanızda 2 yeni kolon bulunur:

1. **varyant_grup_id**: Aynı ürünün tüm varyantlarını gruplandıran benzersiz kimlik
2. **varyant_secenekler**: Varyant özelliklerini içeren pipe-separated (|) string

### Format Kuralları

```
varyant_secenekler formatı: Anahtar:Değer|Anahtar:Değer|...

Örnekler:
- Renk:Siyah|Depolama:512GB
- Renk:Kırmızı|Beden:42
- Volt:220V|Güç:1200W
- Boyut:L|Renk:Mavi|Kumaş:Pamuk
```

### CSV Örneği

```csv
isim,marka,magaza,fiyat,varyant_grup_id,varyant_secenekler,gorsel_1
iPhone 15 Pro Max,Apple,Teknosa,64999,IPHONE15-TEKNOSA,Renk:Titanyum Mavi|Depolama:256GB,blue_256.jpg
iPhone 15 Pro Max,Apple,Teknosa,74999,IPHONE15-TEKNOSA,Renk:Titanyum Mavi|Depolama:512GB,blue_512.jpg
iPhone 15 Pro Max,Apple,Teknosa,64999,IPHONE15-TEKNOSA,Renk:Titanyum Siyah|Depolama:256GB,black_256.jpg
iPhone 15 Pro Max,Apple,Teknosa,74999,IPHONE15-TEKNOSA,Renk:Titanyum Siyah|Depolama:512GB,black_512.jpg
```

### Varyant Grup ID Oluşturma Kuralları

Format: `ÜRÜN-MAĞAZA` (büyük harf, tire ile ayrılmış)

Örnekler:
- `IPHONE15-TEKNOSA`
- `SAMSUNG-S24-QUEEN`
- `NIKE-AIRMAX90-FLO`
- `DYSON-V15-ARCELIK`

---

## Database (SQLite) Yapısı

### products Tablosu

```sql
CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  brand TEXT NOT NULL,
  -- ... diğer alanlar ...
  variantGroupId TEXT,              -- Varyant grup ID
  variantOptions TEXT,               -- "Renk:Siyah|Depolama:512GB"
  stock INTEGER DEFAULT 0,
  isActive BOOLEAN NOT NULL
);
```

### Varyant Sorguları

```dart
// 1. Varyant grubundaki tüm ürünleri getir
List<DBProduct> variants = await dbHelper.getProductVariantsByGroupId('IPHONE15-TEKNOSA');

// 2. Varyant seçenek anahtarlarını getir (örn: ["Renk", "Depolama"])
Set<String> keys = await dbHelper.getVariantOptionKeys('IPHONE15-TEKNOSA');

// 3. Bir seçenek için mevcut değerleri getir
Set<String> colors = await dbHelper.getVariantValues('IPHONE15-TEKNOSA', 'Renk');
// Sonuç: {"Titanyum Mavi", "Titanyum Siyah", "Titanyum Beyaz"}

// 4. Seçilen opsiyonlara göre ürün bul
DBProduct? product = await dbHelper.getProductByVariantOptions(
  'IPHONE15-TEKNOSA',
  {'Renk': 'Titanyum Siyah', 'Depolama': '512GB'}
);
```

---

## Kod Kullanımı

### 1. DBProduct Model

```dart
class DBProduct {
  final int? id;
  final String name;
  final String? variantGroupId;    // Varyant grup ID
  final String? variantOptions;     // "Renk:Siyah|Depolama:512GB"
  
  // Varyant seçeneklerini Map'e dönüştür
  Map<String, String> getVariantOptionsMap() {
    if (variantOptions == null || variantOptions!.isEmpty) {
      return {};
    }
    
    final Map<String, String> result = {};
    final pairs = variantOptions!.split('|');
    
    for (var pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        result[parts[0].trim()] = parts[1].trim();
      }
    }
    
    return result;
  }
}
```

### 2. UI Widget Kullanımı

```dart
import 'package:ibul_app/widgets/product_variant_selector.dart';

class ProductDetailScreen extends StatefulWidget {
  final DBProduct product;
  
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late DBProduct _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Ürün görseli
          Image.asset(_currentProduct.imageUrl),
          
          // Ürün bilgileri
          Text(_currentProduct.name),
          Text('${_currentProduct.price} ₺'),
          
          // VARYANT SEÇİCİ WIDGET
          if (_currentProduct.variantGroupId != null)
            ProductVariantSelector(
              currentProduct: _currentProduct,
              onVariantSelected: (newProduct) {
                setState(() {
                  _currentProduct = newProduct;
                });
              },
            ),
          
          // Sepete ekle butonu
          ElevatedButton(
            onPressed: () => _addToCart(_currentProduct),
            child: Text('Sepete Ekle'),
          ),
        ],
      ),
    );
  }
}
```

---

## Ekran Görünümü

### Varyant Seçici Görünümü

```
┌─────────────────────────────────────┐
│  🎛 Seçenekler                      │
│                                      │
│  Renk                                │
│  [Titanyum Mavi] [Siyah] [Beyaz]   │
│                                      │
│  Depolama                            │
│  [256GB] [512GB] [1TB]              │
└─────────────────────────────────────┘
```

- Seçili opsiyon: **Mavi arka plan, beyaz yazı**
- Seçili olmayan: **Beyaz arka plan, gri çerçeve**
- Tıklandığında: Yeni varyant otomatik yüklenir

---

## Varyant CSV Verileri Ekleme Adımları

### 1. Varyant Grup ID Belirle

Ürün + Mağaza kombinasyonuna benzersiz bir ID ver:
```
IPHONE15-TEKNOSA
SAMSUNG-S24-QUEEN
```

### 2. Varyant Kombinasyonlarını Oluştur

Örnek: iPhone 15 Pro Max

**Renkler**: Titanyum Mavi, Titanyum Siyah, Titanyum Beyaz  
**Depolama**: 256GB, 512GB, 1TB

**Toplam 9 varyant** (3 renk × 3 depolama)

### 3. Her Varyant İçin CSV Satırı Ekle

```csv
iPhone 15 Pro Max,Apple,Teknosa,64999,IPHONE15-TEKNOSA,Renk:Titanyum Mavi|Depolama:256GB
iPhone 15 Pro Max,Apple,Teknosa,74999,IPHONE15-TEKNOSA,Renk:Titanyum Mavi|Depolama:512GB
iPhone 15 Pro Max,Apple,Teknosa,84999,IPHONE15-TEKNOSA,Renk:Titanyum Mavi|Depolama:1TB
iPhone 15 Pro Max,Apple,Teknosa,64999,IPHONE15-TEKNOSA,Renk:Titanyum Siyah|Depolama:256GB
...
```

### 4. Her Varyant İçin Özel Değerler

Her varyantın kendine özgü olabilir:
- **fiyat**: Farklı depolama = farklı fiyat
- **stok**: Her renk/beden için ayrı stok
- **gorsel_1, gorsel_2, gorsel_3**: Her renk için farklı görseller

---

## Önemli Notlar

### ✅ Yapılması Gerekenler

1. Aynı varyant grubundaki tüm ürünlerin **isim**, **marka** ve **magaza** değerleri aynı olmalı
2. Her varyant için **benzersiz varyant_secenekler** kombinasyonu kullan
3. Varyant grup ID'leri büyük harf ve tire ile oluştur
4. Her varyant için ayrı görseller kullan (renk farklıysa)

### ❌ Yapılmaması Gerekenler

1. Aynı varyant grubu içinde aynı `varyant_secenekler` kombinasyonunu tekrarlama
2. Varyant grup ID'yi boş bırakma (varyant sistemi olmayan ürünler hariç)
3. Pipe (|) veya colon (:) karakterlerini değer içinde kullanma
4. Türkçe karakterli varyant grup ID kullanma (sadece İngilizce)

### 🔧 Hata Ayıklama

```dart
// Varyant seçeneklerini parse et ve kontrol et
final product = await dbHelper.getProduct(1);
final optionsMap = product.getVariantOptionsMap();
print(optionsMap); // {"Renk": "Siyah", "Depolama": "512GB"}

// Tüm varyantları listele
final variants = await dbHelper.getProductVariantsByGroupId('IPHONE15-TEKNOSA');
for (var v in variants) {
  print('${v.id}: ${v.variantOptions} - ${v.price} ₺');
}
```

---

## Örnek Varyant Tanımları

### Elektronik Ürünler

```csv
# Telefon
varyant_grup_id: IPHONE15-TEKNOSA
varyant_secenekler: Renk:Titanyum Mavi|Depolama:256GB

# Laptop
varyant_grup_id: MACBOOK-PRO-ARCELIK
varyant_secenekler: İşlemci:M3|RAM:16GB|Depolama:512GB
```

### Giyim Ürünleri

```csv
# Tişört
varyant_grup_id: NIKE-TSHIRT-FLO
varyant_secenekler: Renk:Siyah|Beden:L

# Ayakkabı
varyant_grup_id: ADIDAS-ULTRA-FLO
varyant_secenekler: Renk:Beyaz|Beden:42|Cinsiyet:Erkek
```

### Ev Aletleri

```csv
# Elektrikli Süpürge
varyant_grup_id: DYSON-V15-TEKNOSA
varyant_secenekler: Volt:220V|Renk:Mor

# Blender
varyant_grup_id: PHILIPS-BLENDER-ARCELIK
varyant_secenekler: Güç:1000W|Renk:Siyah
```

---

## Gelişmiş Özellikler

### Stok Takibi

Her varyant için ayrı stok yönetimi:

```dart
// Renk: Siyah, Depolama: 512GB için stok kontrolü
final product = await dbHelper.getProductByVariantOptions(
  'IPHONE15-TEKNOSA',
  {'Renk': 'Siyah', 'Depolama': '512GB'}
);

if (product != null && product.stock > 0) {
  print('Stokta var: ${product.stock} adet');
} else {
  print('Stokta yok');
}
```

### Fiyat Farklılıkları

Farklı varyantlar farklı fiyatlara sahip olabilir:

```csv
iPhone 15 Pro Max,Apple,Teknosa,64999,...,Renk:Mavi|Depolama:256GB
iPhone 15 Pro Max,Apple,Teknosa,74999,...,Renk:Mavi|Depolama:512GB
iPhone 15 Pro Max,Apple,Teknosa,84999,...,Renk:Mavi|Depolama:1TB
```

### Dinamik Görsel Değişimi

```dart
ProductVariantSelector(
  currentProduct: _currentProduct,
  onVariantSelected: (newProduct) {
    setState(() {
      _currentProduct = newProduct;
      // Görsel otomatik güncellenir (newProduct.imageUrl)
    });
  },
)
```

---

## Sonuç

Bu varyant sistemi ile:

✅ Aynı ürünün farklı seçeneklerini tek sayfada gösterebilirsiniz  
✅ Kullanıcı farklı renk/beden/depolama seçeneklerini görebilir  
✅ Her varyant için ayrı stok, fiyat ve görsel yönetebilirsiniz  
✅ CSV ile toplu varyant ekleme yapabilirsiniz  
✅ Veritabanı sorguları optimize edilmiştir

Sorularınız için: **database_helper.dart** ve **product_variant_selector.dart** dosyalarını inceleyin.
