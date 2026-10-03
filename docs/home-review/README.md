# Ana sayfa düzeltmesi — 1 Ekim 2026

Mevcut çalışma ağacı korunarak Flutter kodu değiştirildi. Supabase şeması, RLS, ödeme ve kimlik doğrulama politikaları değiştirilmedi; production deploy yapılmadı.

## Doğrulanan nedenler

- Header'daki `Expanded` arama alanı ve `Flexible` harita alanı kalan genişliği birlikte paylaşıyordu. Harita alanı büyük bir boşluk oluşturuyor; üst menü ve içerik farklı yatay sınırlar kullanıyordu.
- Alt kategori yerine sabit kısayol etiketleri gösteriliyordu ve bu satır teslimat adresinden sonra geliyordu. Alt kategori seçimi üst kategori seçimini değiştiriyordu. `HomeViewportSection` ilk widget'ı saklayarak sonraki filtre değerlerini çocuğa iletmiyordu.
- Web kampanya satırı 412 px, kısayol satırı 140 px yüksekliğindeydi. Banner `BoxFit.cover` kullanıyordu; masaüstünde mobil banner yolu tercih ediliyordu.
- Anonim, salt okunur canlı araç sorgusunda `PGRST200` alındı: `vehicle_listings` ile `vehicle_galleries` arasında PostgREST ilişkisi yok. Ayrıca galerinin istenen `id/name/avatar_url/slug` alanları yerel şemayla uyuşmuyordu. Geçerli `vehicle_specs`, `vehicle_rental_settings` ve `vehicle_media` ilişkileriyle aynı canlı sorgu iki aktif ve reddedilmemiş ilan döndürdü. İkisinde de kapak fotoğrafı ve kiralama verisi mevcut. Eski yükleyici hatayı boş listeye dönüştürüyordu.
- Canlı `list_daily_deal_products(p_limit)` çağrısı `PGRST202` döndürdü: RPC şema önbelleğinde bulunmuyor. Tanımı `ibul_app/supabase/migrations/20260916_coupon_engine_wheel.sql` içinde mevcut. Veritabanına müdahale edilmedi. İstemci bunu kısa bir hata ve yeniden deneme olarak gösteriyor; teknik ayrıntı logda kalıyor.

## Değişen dosyalar

Aşağıdaki yollar `ibul_app/lib/` altındadır:

| Dosyalar | Düzeltme |
| --- | --- |
| `widgets/marketplace_content_frame.dart` (yeni), `widgets/web_header.dart`, `widgets/web_header_menu_items.dart` | Ortak 1400 px sınır ve responsive yatay padding; arama kalan genişliği alır; sağ bağlantılar doğal genişlikte kalır. Bildirim, kamera, logo ve mevcut bağlantı handler'ları korunur. |
| `screens/home/sections/home_category_navigation.dart` (yeni) | Aktif kategori verisi; `parent_id` ile gerçek alt kategoriler; ayrı seçim, 44 px dokunma alanı ve yatay kaydırma. Çocuğu olmayan kategoride ikinci bant yok. |
| `screens/home/home_initial_page.dart`, `screens/home/entries/home_commerce_entry.dart`, `screens/home/home_viewport_section.dart` | Menü → ana kategori → alt kategori → adres → içerik sırası; ana/alt kategori birlikte ürün sorgusuna geçer; ertelenen bölüm yeni filtreleri alır. Ana sayfa 1024 px'te masaüstü yerleşimini kullanır. |
| `core/home_navigation.dart`, `app/app_bootstrap.dart`, `app/shared_app_widgets.dart`, `app/app_route_table.dart`, `screens/home_screen_gate.dart` | `category` ve `subcategory` URL parametreleri açılışta/yenilemede aktarılır. Ana sayfanın `/` yolu query argümanlarını korur. |
| `core/home_quick_action.dart`, `screens/home/sections/ibul_opportunity_shortcuts_section.dart` | Kompakt kısayollar, 76 px satır; fırsat kısayolları mevcut filtre navigasyonuna bağlanır. |
| `screens/home/sections/ibul_hero_campaign_row.dart`, `screens/home/sections/home_section_hero_banner.dart`, `screens/home/sections/home_section_full_rail.dart` | 264 px banner, `BoxFit.contain`, dengeli yan sütun ve ürün hizalaması. |
| `features/vehicle/data/vehicle_listing_repository.dart`, `screens/home/home_discovery_loader.dart`, `screens/home/entries/home_vehicle_entry.dart`, `screens/home/sections/home_vehicle_rail_section.dart` | Geçerli araç sorgusu; moderasyon verisi, yayın tarihi ve günlük fiyat yüklenir. Aktif durum ve mevcut reddedilme filtresi korunur. Yükleniyor/dolu/boş/hata ayrı; tekrar deneme önceki hatayı temizler. Mevcut detay, favori ve karşılaştırma handler'ları kullanılır. |
| `features/coupon/data/coupon_repository.dart`, `screens/home/sections/home_section_coupon_deal_column.dart`, `screens/home/deferred/deferred_home_coupon_deal_column.dart` | Teknik hata kullanıcıya verilmez; kompakt retry; boş fırsat kartı gizlenir; kupon ve fırsat bağımsız yüklenir. |

Yeni test: `ibul_app/test/home/home_web_layout_test.dart` (9 kontrol).

## Çalıştırılan kontroller

- `flutter analyze`: başlangıçta 140, sonuçta 134 bildirim. Satır numaralarından bağımsız karşılaştırmada **yeni bildirim yok**, derleme hatası yok. Mevcut lint/uyarılar devam ediyor. [Önce](analyze-before.txt), [sonra](analyze-after.txt).
- Kategori, header genişliği, ertelenen filtre güncellemesi, araç önbelleği/sorgu/görünürlük/durumlar, kupon retry, kısayollar ve mevcut tasarım kontrolleri: **60 test geçti**. [Çıktı](tests.txt).
- `flutter build web --release --no-tree-shake-icons --output=/tmp/ibul-home-web-build`: başarılı; Wasm dry run da başarılı. Bu yerel doğrulama derlemesidir.
- Ek çalıştırılan mevcut `web_header_logo_home_test.dart`, değişmemiş router'da bulunmayan `path == marketplaceHome` metnini beklediği için başarısız. Mevcut `vehicle_card_actions_test.dart` karşılaştırma testinde navigasyon sonrası `Araç Karşılaştırma` başlığı bulunamıyor; tek başına tekrar çalıştırıldığında da aynı sonuç. Bu test ve karşılaştırma sayfası/navigasyonu bu çalışmada değiştirilmedi. Karşılaştırma mağazası testleri geçti; karşılaştırma akışını bütünüyle doğrulanmış saymıyorum.

## Kalan veri sınırları

- Fırsat RPC'sinin canlıda eksik olması giderilmedi. Mevcut migration'ın canlıya uygulanma ve şema önbelleği durumu ayrı bir veritabanı işi olarak incelenmeli.
- Canlı kategori tablosunda aktif ana kategori olarak yalnız `Erkek` ve `Kadın` var. Ürünlerde görünen diğer kategori başlıkları için ana kategori satırı uydurulmadı.
- İlk kampanya görselinin alt metni kaynak dosyada zaten kesilmiş. Widget ek kırpma/esnetme yapmıyor; kaynak görselin yenilenmesi ayrı bir içerik düzeltmesi.
