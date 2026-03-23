import '../../models/product_model.dart';

class ProductDetailContentHelper {
  const ProductDetailContentHelper._();

  static List<Map<String, String>> buildSpecs(Product product) {
    final specs = <Map<String, String>>[];
    final specsText = product.getDisplaySpecs();
    final brand = product.brand;
    final name = product.name;
    final lowerBrand = brand.toLowerCase();
    final lowerName = name.toLowerCase();
    final lowerCategory = (product.category ?? '').toLowerCase();
    final lowerSubCategory = (product.subCategory ?? '').toLowerCase();
    final isPhone =
        lowerName.contains('iphone') ||
        lowerName.contains('galaxy') ||
        lowerName.contains('telefon') ||
        lowerSubCategory.contains('telefon') ||
        lowerCategory.contains('telefon') ||
        lowerSubCategory.contains('cep telefonu');

    // Parse specs text format: "Key: Value"
    final lines = specsText.split('\n');
    for (final line in lines) {
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final key = parts[0].trim();
      final value = parts.sublist(1).join(':').trim();
      if (key.isEmpty || value.isEmpty) continue;
      specs.add({'key': key, 'value': value});
    }

    // Include seller-provided attributes.
    final attrsRaw = product.attributes;
    if (attrsRaw != null) {
      for (final item in attrsRaw) {
        final text = item.trim();
        if (text.isEmpty) continue;
        final idx = text.indexOf(':');
        if (idx <= 0) continue;
        final key = text.substring(0, idx).trim();
        final value = text.substring(idx + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          _addIfMissing(specs, key, value);
        }
      }
    }

    // Category/brand defaults used by web detail view.
    if ((lowerBrand.contains('apple') && isPhone) ||
        lowerName.contains('iphone')) {
      _addIfMissing(specs, 'Garanti Tipi', 'Apple Türkiye Garantili');
      _addIfMissing(specs, 'Kamera Çözünürlüğü', '12 MP + 12 MP');
      _addIfMissing(specs, 'Dahili Hafıza', '128 GB');
      _addIfMissing(specs, 'Ekran Boyutu', '6,1 inç');
      _addIfMissing(specs, 'Pil Gücü (mAh)', '3095');
      _addIfMissing(specs, 'Mobil Bağlantı Hızı', '5G');
      _addIfMissing(specs, 'CPU Aralık', '2.5-3.2 GHz');
      _addIfMissing(specs, 'Ekran Çözünürlüğü', 'FHD+');
      _addIfMissing(specs, 'Ana Kamera Çözünürlük', '10 - 15 MP');
      _addIfMissing(specs, 'Parmak İzi Okuyucu', 'Yok');
      _addIfMissing(specs, 'Suya/Toza Dayanıklılık', 'Var');
      _addIfMissing(specs, 'RAM Kapasitesi', '4 GB');
    } else if ((lowerBrand.contains('samsung') ||
            lowerName.contains('galaxy')) &&
        isPhone) {
      _addIfMissing(specs, 'Garanti Tipi', 'Samsung Türkiye Garantili');
      _addIfMissing(specs, 'Kamera Çözünürlüğü', '200 MP');
      _addIfMissing(specs, 'Dahili Hafıza', '256 GB');
      _addIfMissing(specs, 'Ekran Boyutu', '6,8 inç');
      _addIfMissing(specs, 'Pil Gücü (mAh)', '5000');
      _addIfMissing(specs, 'Mobil Bağlantı Hızı', '5G');
      _addIfMissing(specs, 'CPU Aralık', '3.36 GHz');
      _addIfMissing(specs, 'Ekran Çözünürlüğü', 'QHD+');
      _addIfMissing(specs, 'S Pen Desteği', 'Var');
      _addIfMissing(specs, 'Parmak İzi Okuyucu', 'Ekran Altı');
      _addIfMissing(specs, 'Suya/Toza Dayanıklılık', 'IP68');
      _addIfMissing(specs, 'RAM Kapasitesi', '12 GB');
    } else {
      _addIfMissing(specs, 'Marka', brand);
      final isFood = (product.category ?? '').toLowerCase() == 'yemek';
      if (!isFood) {
        _addIfMissing(specs, 'Garanti', '2 Yıl');
      }
      _addIfMissing(specs, 'Menşei', 'Türkiye');
    }

    return specs;
  }

  static List<String> buildAdditionalInfo(Product product) {
    final info = <String>[];
    final isFood = (product.category ?? '').toLowerCase() == 'yemek';

    if (product.additionalInfo != null && product.additionalInfo!.isNotEmpty) {
      info.addAll(
        product.additionalInfo!
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty),
      );
    }

    info.add(
      'Bu ürün ${product.store ?? "satıcı"} tarafından gönderilecektir.',
    );
    if (!isFood) {
      info.add(
        'Kampanya fiyatından satılmak üzere 5 adetten az stok bulunmaktadır.',
      );
    }
    info.add(
      'Bir ürün, birden fazla satıcı tarafından satılabilir. Birden fazla satıcı tarafından satışa sunulan ürünler için belirledikleri fiyata, satıcı puanlarına, teslimat statülerine, ürünlerdeki promosyonlara ve kargonun bedava olup olmamasına göre sıralanmaktadır.',
    );
    if (!isFood) {
      info.add('Bu üründen en fazla 1 adet sipariş verilebilir.');
      info.add('15 gün içinde ücretsiz iade.');
    }

    final seen = <String>{};
    return info.where((line) {
      if (seen.contains(line)) return false;
      seen.add(line);
      return true;
    }).toList();
  }

  static void _addIfMissing(
    List<Map<String, String>> specs,
    String key,
    String value,
  ) {
    if (value.trim().isEmpty) return;
    if (!specs.any((s) => s['key'] == key)) {
      specs.add({'key': key, 'value': value});
    }
  }
}
