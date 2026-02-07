#!/usr/bin/env python3
"""
iOS App Icon Generator
Bu script, 1024x1024 ana görselden tüm gerekli iOS ikon boyutlarını oluşturur.
"""

from PIL import Image
import os

# Ana icon dosya yolu - bu görseli manuel olarak buraya koyun
SOURCE_IMAGE = "app_icon_1024.png"

# iOS ikon boyutları
IOS_ICON_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

# iOS AppIcon klasör yolu
OUTPUT_DIR = "ios/Runner/Assets.xcassets/AppIcon.appiconset"

def create_icons():
    """Ana görselden tüm boyutları oluştur"""
    
    # Ana görseli aç
    if not os.path.exists(SOURCE_IMAGE):
        print(f"❌ Hata: {SOURCE_IMAGE} bulunamadı!")
        print(f"Lütfen 1024x1024 PNG görseli '{SOURCE_IMAGE}' olarak kaydedin.")
        return False
    
    print(f"📸 Ana görsel yükleniyor: {SOURCE_IMAGE}")
    source_img = Image.open(SOURCE_IMAGE)
    
    # Görsel boyutunu kontrol et
    if source_img.size != (1024, 1024):
        print(f"⚠️  Uyarı: Görsel boyutu {source_img.size}, beklenen: (1024, 1024)")
        print("Görsel 1024x1024'e yeniden boyutlandırılıyor...")
        source_img = source_img.resize((1024, 1024), Image.LANCZOS)
    
    # RGB'ye çevir (şeffaflık olmamalı)
    if source_img.mode == 'RGBA':
        print("🔄 RGBA'dan RGB'ye çeviriliyor (arka plan beyaz)...")
        rgb_img = Image.new('RGB', source_img.size, (255, 255, 255))
        rgb_img.paste(source_img, mask=source_img.split()[3])
        source_img = rgb_img
    
    # Çıktı klasörünü oluştur
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Her boyut için ikon oluştur
    print(f"\n🎨 {len(IOS_ICON_SIZES)} farklı boyutta ikon oluşturuluyor...\n")
    
    for filename, size in IOS_ICON_SIZES.items():
        output_path = os.path.join(OUTPUT_DIR, filename)
        
        # Boyutlandır ve kaydet
        resized_img = source_img.resize((size, size), Image.LANCZOS)
        resized_img.save(output_path, 'PNG')
        
        print(f"✅ {filename:30s} ({size}x{size} px)")
    
    print(f"\n🎉 Tüm ikonlar başarıyla oluşturuldu!")
    print(f"📁 Klasör: {OUTPUT_DIR}")
    return True

if __name__ == "__main__":
    print("=" * 60)
    print("iOS App Icon Generator")
    print("=" * 60)
    create_icons()
