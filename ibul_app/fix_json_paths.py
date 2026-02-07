#!/usr/bin/env python3
import json

# JSON dosyasını oku
with open('assets/urunler.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Her ürün için görselleri düzelt
for item in data:
    if 'gorseller' in item and item['gorseller']:
        fixed_images = []
        for img in item['gorseller']:
            # Eğer path yoksa ekle
            if img and not img.startswith('assets/'):
                fixed_images.append(f'assets/products/{img}')
            else:
                fixed_images.append(img)
        item['gorseller'] = fixed_images
        print(f"✅ {item['isim']}: {fixed_images}")

# Düzeltilmiş JSON'u kaydet
with open('assets/urunler.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("\n🎉 Tüm görsel path'leri düzeltildi!")
