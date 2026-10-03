import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/marketplace_paths.dart';

void main() {
  test('product and store paths keep a stable id and optional slug', () {
    expect(
      MarketplacePaths.product('abc-123', slug: 'Apple iPhone 15'),
      '/urun/abc-123/apple-iphone-15',
    );
    expect(MarketplacePaths.store('seller-1', slug: 'Cafe'), '/magaza/seller-1/cafe');
    expect(MarketplacePaths.vehicle('veh-9'), '/arac/veh-9');
    expect(
      MarketplacePaths.category(4, 12, slug: 'Elektronik Telefonlar'),
      '/kategori/4/12/elektronik-telefonlar',
    );
    expect(
      MarketplacePaths.idFrom('/urun/abc-123/apple-iphone-15', '/urun'),
      'abc-123',
    );
    expect(
      MarketplacePaths.idFrom('/arac/veh-9/renault-clio', '/arac'),
      'veh-9',
    );
  });

  test('account paths are protected', () {
    expect(MarketplacePaths.isAccountPath('/hesabim'), isTrue);
    expect(MarketplacePaths.isAccountPath('/hesabim/siparisler'), isTrue);
    expect(MarketplacePaths.isAccountPath('/hesabim/kiralamalar'), isTrue);
    expect(MarketplacePaths.isAccountPath('/hesabim/favoriler'), isTrue);
    expect(MarketplacePaths.isAccountPath('/hesabim/ayarlar'), isTrue);
    expect(MarketplacePaths.isAccountPath('/urun/1'), isFalse);
  });

  test('account section paths stay canonical', () {
    expect(MarketplacePaths.favorites, '/hesabim/favoriler');
    expect(MarketplacePaths.coupons, '/hesabim/kuponlar');
    expect(MarketplacePaths.following, '/hesabim/takip-ettiklerim');
    expect(MarketplacePaths.addresses, '/hesabim/adresler');
    expect(MarketplacePaths.cards, '/hesabim/kartlar');
    expect(MarketplacePaths.reviews, '/hesabim/degerlendirmeler');
    expect(MarketplacePaths.support, '/hesabim/musteri-hizmetleri');
    expect(MarketplacePaths.settings, '/hesabim/ayarlar');
    expect(MarketplacePaths.ai, '/hesabim/yapay-zeka');
  });

  test('share url never hardcodes the old firebase host', () {
    expect(MarketplacePaths.shareUrl('/urun/1'), isNot(contains('web.app')));
    expect(MarketplacePaths.shareUrl('/arac/2'), contains('/arac/2'));
  });
}
