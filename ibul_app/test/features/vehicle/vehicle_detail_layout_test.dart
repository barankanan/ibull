import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_catalog.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_detail_adapter.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_detail_center_card.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_detail_sections.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_listing_detail_view.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_seller_stock_tile.dart';
import 'package:ibul_app/widgets/catalog_detail/catalog_sidebar_cards.dart';

VehicleListing _listing({
  String vehicleClass = 'automobile',
  String? description,
  List<String> features = const ['abs', 'esp'],
  Map<String, String>? damage,
  double? salePrice = 1200212,
  VehicleSpecs? specs,
  bool preview = false,
  VehicleListingType listingType = VehicleListingType.sale,
  String? coverUrl,
  List<VehicleMedia> media = const [],
}) {
  return VehicleListing(
    id: 'listing-1',
    sellerId: 'seller-1',
    listingType: listingType,
    status: preview ? VehicleListingStatus.draft : VehicleListingStatus.active,
    specs:
        specs ??
        const VehicleSpecs(
          brand: 'Toyota',
          model: 'Corolla',
          version: '1.5 Dream',
          year: 2021,
          mileageKm: 65000,
          fuel: 'Benzin',
          transmission: 'Otomatik',
          powerHp: 125,
          engineCc: 1490,
          bodyType: 'Sedan',
          color: 'Beyaz',
          drive: 'Önden',
          tramerAmount: 12000,
          hasExpertise: true,
        ),
    salePrice: salePrice,
    description: description ?? 'Bakımlı araç. Galeri çıkışlı.',
    city: 'Hatay',
    district: 'Arsuz',
    coverUrl: coverUrl,
    media: media,
    gallery: const VehicleGallerySummary(
      sellerId: 'seller-1',
      name: 'SECO Otomotiv',
      city: 'Hatay',
      district: 'Arsuz',
      verified: true,
      vehicleCount: 12,
      rating: 4.8,
    ),
    extras: {
      'title': 'Toyota Corolla 1.5 Dream',
      'vehicle_class': vehicleClass,
      'features': features,
      'damage_parts': ?damage,
    },
  );
}

Future<List<String>> _pumpDetail(
  WidgetTester tester, {
  required Size size,
  bool preview = true,
  bool wizardChrome = false,
  VehicleListing? listing,
  List<VehicleListing> related = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final overflows = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = '${details.exceptionAsString()}\n${details.stack}';
    if (text.contains('overflowed') || text.contains('OVERFLOWED')) {
      overflows.add(text);
    }
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);

  final data =
      listing ?? _listing(damage: {'hood': 'painted', 'trunk': 'replaced'});
  final view = VehicleListingDetailView(
    listing: data,
    previewMode: preview,
    related: related,
    onMessage: () {},
    onShare: () {},
    onFavorite: () {},
    onFollow: () {},
    onOpenGallery: () {},
    onVideo: () {},
    onNearby: () {},
  );
  Widget body = RepaintBoundary(
    key: const ValueKey('vehicle-detail-capture'),
    child: view,
  );
  if (wizardChrome) {
    body = Column(
      children: [
        const SizedBox(height: 96),
        Expanded(child: body),
        const SizedBox(height: 64),
      ],
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: body,
        bottomNavigationBar: size.width > 1100
            ? null
            : VehicleDetailStickyBar(
                listing: data,
                previewMode: preview,
                onPrimary: () {},
                onSecondary: () {},
              ),
      ),
    ),
  );
  await tester.pump();
  final caught = tester.takeException();
  if (caught != null) {
    overflows.add(caught.toString());
  }
  return overflows;
}

void main() {
  test('spec table hides car body fields for motorcycle', () {
    final car = VehicleDetailSpecBuilder.groups(_listing());
    final moto = VehicleDetailSpecBuilder.groups(
      _listing(vehicleClass: 'motorcycle'),
    );
    expect(car.any((g) => g.rows.any((r) => r.$1 == 'Kasa tipi')), isTrue);
    expect(moto.any((g) => g.rows.any((r) => r.$1 == 'Kasa tipi')), isFalse);
    expect(car.any((g) => g.rows.any((r) => r.$1 == 'Kilometre')), isTrue);
  });

  test('highlights stay compact and type-aware', () {
    final items = VehicleDetailSpecBuilder.highlights(_listing());
    expect(items.map((e) => e.$2), contains('65.000 km'));
    expect(items.map((e) => e.$2), contains('2021'));
    expect(items.map((e) => e.$2), contains('Benzin'));
    expect(
      VehicleDetailSpecBuilder.headlineMeta(_listing()),
      containsAll([
        '2021',
        '65.000 km',
        'Benzin',
        'Otomatik',
        '125 hp',
        'Sedan',
      ]),
    );
    final jet = VehicleDetailSpecBuilder.highlights(
      _listing(vehicleClass: 'jetski'),
    );
    expect(jet.map((e) => e.$2).any((v) => v.contains('km')), isFalse);
  });

  test('public statuses stay gated and empty values stay hidden', () {
    expect(VehicleListingStatus.draft.isPubliclyVisible, isFalse);
    expect(VehicleListingStatus.pendingReview.isPubliclyVisible, isFalse);
    expect(VehicleListingStatus.active.isPubliclyVisible, isTrue);
    expect(VehicleDetailDamageSection.visible(_listing()), isTrue);
    expect(
      VehicleDetailDamageSection.visible(
        _listing(
          specs: const VehicleSpecs(
            brand: 'Toyota',
            model: 'Corolla',
            year: 2021,
          ),
        ),
      ),
      isFalse,
    );
    expect(VehicleDetailSpecBuilder.priceOf(_listing()), '1.200.212 TL');
    expect(
      VehicleDetailSpecBuilder.priceOf(_listing(salePrice: 0)),
      'Fiyat sorulur',
    );
    expect(
      VehicleDetailSpecBuilder.compactRows(
        _listing(),
      ).any((r) => r.$2 == '1.490 cc'),
      isTrue,
    );
    expect(
      VehicleDetailSpecBuilder.sidebarRows(_listing()).map((r) => r.$1),
      containsAll(['Yıl', 'Kilometre', 'Yakıt', 'Vites']),
    );
    expect(
      VehicleDetailSpecBuilder.highlights(
        _listing(
          specs: const VehicleSpecs(
            brand: 'Toyota',
            model: 'Corolla',
            year: 2021,
            mileageKm: 0,
            fuel: 'Benzin',
          ),
        ),
      ).any((e) => e.$2.contains('km')),
      isFalse,
    );
    final led = VehicleDetailFeatureSection.dedupe(
      VehicleCatalog.featureGroupsFor('automobile'),
    ).fold<int>(0, (n, g) => n + g.items.where((i) => i.id == 'led').length);
    expect(led, 1);
  });

  test('vehicle adapter maps sale and rental CTAs from listing type', () {
    final sale = VehicleDetailAdapter.ctas(_listing());
    expect(sale.primaryLabel, 'GÖRÜŞME PLANLA');
    expect(sale.secondaryLabel, 'SATICIYA SOR');
    expect(sale.primaryAction, VehicleDetailCtaAction.bookAppointment);
    final rental = VehicleDetailAdapter.ctas(
      _listing(listingType: VehicleListingType.rental),
    );
    expect(rental.primaryLabel, 'KİRALAMA TARİHİ SEÇ');
    expect(rental.secondaryLabel, 'ŞİMDİ KİRALA');
    expect(
      VehicleDetailAdapter.breadcrumbParts(_listing()),
      containsAll(['iBul', 'Toyota', 'SECO Otomotiv', 'Araç']),
    );
    expect(VehicleDetailAdapter.tabs(_listing()), contains('Araç Açıklaması'));
    expect(
      VehicleDetailAdapter.tabs(
        _listing(listingType: VehicleListingType.rental),
      ),
      contains('Teslimat / Kiralama'),
    );
    final specs = VehicleDetailAdapter.quickSpecs(_listing());
    expect(specs.length, lessThanOrEqualTo(6));
    expect(
      specs.map((e) => e.label),
      containsAll(['Yıl', 'Kilometre', 'Yakıt']),
    );
    expect(specs.map((e) => e.label), isNot(contains('Marka')));
    expect(specs.map((e) => e.label), isNot(contains('Model')));
    final rentalListing = _listing(listingType: VehicleListingType.rental)
        .copyWith(
          rental: const VehicleRentalSettings(
            dailyPrice: 1166,
            deposit: 5000,
            minDays: 3,
            maxDays: 30,
            kmLimitPerDay: 1000,
            extraKmPrice: 500,
            galleryPickup: true,
            mapPointDelivery: true,
            homeDelivery: true,
          ),
        );
    final groups = VehicleDetailAdapter.rentalGroups(rentalListing);
    expect(
      groups.map((g) => g.title),
      containsAll(['Teslim Alma', 'Kiralama Koşulları', 'Ücretler & Güvence']),
    );
    expect(
      groups
          .expand((g) => g.rows)
          .where((r) => r.interactive)
          .map((r) => r.label),
      containsAll(['Teslimat noktası', 'Harita noktası', 'Evden teslim']),
    );
    expect(
      groups
          .expand((g) => g.rows)
          .where((r) => !r.interactive)
          .map((r) => r.label),
      containsAll(['Minimum gün', 'Depozito']),
    );
  });

  test('old pinned huge-gallery layout is not in the active view', () {
    final src = File(
      'lib/features/vehicle/widgets/vehicle_listing_detail_view.dart',
    ).readAsStringSync();
    expect(src, isNot(contains('_widePinned')));
    expect(src, isNot(contains('İLAN ÖZETİ')));
    expect(src, isNot(contains('height: 700')));
    expect(src, contains('vehicle-detail-hero-row'));
    expect(src, contains('SingleChildScrollView'));
    expect(src, contains('CatalogDetailBreadcrumb'));
    expect(src, contains('CatalogDetailTabs'));
    expect(src, isNot(contains('CustomScrollView')));
    expect(src, isNot(contains('VehicleDetailCtas')));
    expect(src, isNot(contains('Sepete Ekle')));
    expect(src, isNot(contains('Şimdi Al')));
    final center = File(
      'lib/features/vehicle/widgets/vehicle_detail_center_card.dart',
    ).readAsStringSync();
    expect(center, isNot(contains('VehicleDetailNearbyButton')));
    expect(center, isNot(contains('CatalogOptionFields')));
    expect(center, isNot(contains('Araç Bilgileri')));
    expect(center, contains('VehicleQuickSpecs'));
    expect(center, contains('CatalogDetailCtaBar'));
    expect(src, contains('VehicleDetailLocationTab'));
    expect(src, contains('VehicleRentalInfoPanel'));
    final spec = File(
      'lib/features/vehicle/widgets/vehicle_detail_spec_table.dart',
    ).readAsStringSync();
    expect(spec, isNot(contains('ARAÇ BİLGİLERİ')));
    expect(spec, isNot(contains('VehicleDetailInfoPanel')));
    final actions = File(
      'lib/features/vehicle/widgets/vehicle_detail_actions.dart',
    ).readAsStringSync();
    expect(actions, contains('YAKIN LOKASYON'));
    expect(actions, contains('Video'));
    expect(actions, contains('Ürün Videosu'));
    expect(actions, contains('Yakın Lokasyon'));
    expect(actions, isNot(contains('Sepete Ekle')));
    expect(actions, contains('vehicle-detail-favorite'));
    expect(actions, contains('vehicle-detail-share'));
    expect(actions, contains('vehicle-detail-compare'));
    expect(actions, contains('vehicle-detail-save'));
    expect(actions, contains('Kaydet'));
    expect(actions, isNot(contains("'İletişim'")));
    expect(actions, isNot(contains("'Teklif Ver'")));
    final gallery = File(
      'lib/features/vehicle/widgets/vehicle_detail_gallery.dart',
    ).readAsStringSync();
    expect(gallery, contains('VehicleDetailActionRail'));
    expect(gallery, contains('VehicleDetailVideoPill'));
    expect(gallery, contains('vehicle-detail-thumbnail-strip'));
    expect(gallery, contains('LayoutBuilder'));
    expect(gallery, contains('ClipRect'));
    final listStart = gallery.indexOf('ListView.separated');
    expect(listStart, greaterThan(0));
    expect(
      gallery.substring(listStart, listStart + 280),
      isNot(contains('Clip.none')),
    );
    final detailPage = File(
      'lib/features/vehicle/screens/vehicle_detail_page.dart',
    ).readAsStringSync();
    expect(detailPage, contains('HomeLazyRoutes.openMap'));
    expect(detailPage, contains("contentType: 'vehicle'"));
    expect(detailPage, contains('VehicleCompareFeedback.open'));
    expect(detailPage, contains('AddToListModal'));
    expect(detailPage, isNot(contains('VehicleCompareBar')));
    expect(detailPage, isNot(contains('IconButton')));
    final seller = File(
      'lib/features/vehicle/widgets/vehicle_detail_seller.dart',
    ).readAsStringSync();
    expect(seller, contains('Takip Et'));
    expect(seller, contains('Satıcıya Sor'));
    expect(seller, isNot(contains('Galeriyi Gör')));
    expect(seller, isNot(contains('Kirala')));
    expect(seller, isNot(contains('Teklif Ver')));
    expect(seller, isNot(contains("'İletişim'")));
    expect(seller, isNot(contains("'Ara'")));
  });

  testWidgets('desktop uses product-style gallery + info + seller', (
    tester,
  ) async {
    final overflows = await _pumpDetail(
      tester,
      size: const Size(1440, 900),
      listing: _listing(
        description: List.filled(40, 'Uzun açıklama satırı.').join(' '),
        damage: {
          'hood': 'painted',
          'trunk': 'replaced',
          'lf_fender': 'local_painted',
        },
      ),
    );
    expect(overflows, isEmpty);
    expect(find.text('İLAN ÖZETİ'), findsNothing);
    expect(find.text('Sepete Ekle'), findsNothing);
    expect(find.text('Şimdi Al'), findsNothing);
    expect(
      find.byKey(const ValueKey('vehicle-detail-hero-row')),
      findsOneWidget,
    );
    expect(find.text('Araç Bilgileri'), findsNothing);
    expect(find.text('Tüm Araç Özellikleri'), findsOneWidget);
    expect(find.text('Kilometre'), findsWidgets);
    expect(find.text('Önizleme'), findsOneWidget);
    expect(find.text('Araç Açıklaması'), findsWidgets);
    expect(find.text('Araç Özellikleri'), findsWidgets);
    expect(find.text('Donanım'), findsOneWidget);
    expect(find.text('Boya / Değişen / Tramer'), findsOneWidget);
    expect(find.text('DAHA FAZLA GÖSTER'), findsWidgets);
    expect(find.text('Tüm Özellikler'), findsNothing);
    expect(
      find.byKey(const ValueKey('vehicle-detail-all-features')),
      findsNothing,
    );
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Ürün Videosu'), findsNothing);
    expect(
      find.byKey(const ValueKey('vehicle-detail-compare')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vehicle-detail-favorite')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('vehicle-detail-share')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-detail-save')), findsOneWidget);
    expect(find.text('Yakın Lokasyon'), findsWidgets);
    expect(find.text('YAKIN LOKASYON'), findsNothing);
    await tester.tap(find.text('Yakın Lokasyon').first);
    await tester.pump();
    expect(find.byKey(const ValueKey('vehicle-detail-nearby')), findsOneWidget);
    expect(find.text('Yakında Arat'), findsOneWidget);
    expect(find.text('SECO Otomotiv'), findsWidgets);
    expect(find.text('Takip Et'), findsOneWidget);
    expect(find.text('Satıcıya Sor'), findsOneWidget);
    expect(find.text('GÖRÜŞME PLANLA'), findsOneWidget);
    expect(find.text('SATICIYA SOR'), findsOneWidget);
    expect(find.text('Galeriyi Gör'), findsNothing);
    expect(find.text('İletişim'), findsNothing);
    expect(find.text('Teklif Ver'), findsNothing);
    expect(find.text('Kirala'), findsNothing);
    expect(find.text('Sepete Ekle'), findsNothing);
    expect(find.text('Henüz değerlendirme yok'), findsWidgets);
    expect(find.text('Henüz soru sorulmadı'), findsOneWidget);
    expect(find.textContaining('Arsuz / Hatay'), findsWidgets);
    expect(find.text('2021'), findsWidgets);
    expect(find.text('65.000 km'), findsWidgets);
    expect(find.text('Sedan'), findsWidgets);
    await tester.ensureVisible(find.text('Boya / Değişen / Tramer'));
    await tester.pumpAndSettle();
    expect(find.text('Orijinal'), findsWidgets);
    expect(find.text('Değişen'), findsWidgets);
    expect(find.textContaining('Boyalı: Ön Kaput'), findsOneWidget);
    expect(find.textContaining('Değişen: Bagaj'), findsOneWidget);
    expect(
      find.textContaining('Lokal boyalı: Sol Ön Çamurluk'),
      findsOneWidget,
    );
    expect(find.textContaining('Tramer:'), findsWidgets);
    await tester.ensureVisible(find.text('Donanım'));
    await tester.pumpAndSettle();
    expect(find.text('Güvenlik'), findsOneWidget);
    expect(find.text('ABS'), findsWidgets);
    expect(find.text('Sürüş Destek'), findsOneWidget);
    expect(find.text('Park / Kamera'), findsOneWidget);
  });

  testWidgets('mobile detail keeps product flow and vehicle CTAs', (
    tester,
  ) async {
    final overflows = await _pumpDetail(tester, size: const Size(390, 844));
    expect(overflows, isEmpty);
    expect(find.byKey(const ValueKey('vehicle-detail-hero-row')), findsNothing);
    expect(
      find.byKey(const ValueKey('vehicle-detail-mobile-stack')),
      findsOneWidget,
    );
    expect(find.text('ARAÇ BİLGİLERİ'), findsNothing);
    expect(find.text('Araç Bilgileri'), findsNothing);
    expect(find.text('Tüm Araç Özellikleri'), findsOneWidget);
    expect(find.text('Sepete Ekle'), findsNothing);
    expect(find.text('Şimdi Al'), findsNothing);
    expect(find.text('GÖRÜŞME PLANLA'), findsOneWidget);
    expect(find.text('SATICIYA SOR'), findsOneWidget);
    expect(find.text('İletişim'), findsNothing);
    expect(find.text('Ara'), findsNothing);
    expect(find.text('Teklif Ver'), findsNothing);
    expect(find.text('Kirala'), findsNothing);
    expect(find.text('Takip Et'), findsOneWidget);
    expect(find.text('Satıcıya Sor'), findsOneWidget);
    expect(find.text('Galeriyi Gör'), findsNothing);
    expect(find.text('Ürün Videosu'), findsOneWidget);
    expect(find.text('Yakın Lokasyon'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vehicle-detail-compare')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vehicle-detail-favorite')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('vehicle-detail-share')), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-detail-save')), findsOneWidget);
    expect(find.text('SECO Otomotiv'), findsWidgets);
    expect(
      find.byKey(const ValueKey('vehicle-detail-all-features')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('vehicle-detail-all-features')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-detail-all-features')));
    await tester.pumpAndSettle();
    expect(find.text('Araç Özellikleri'), findsOneWidget);
  });

  testWidgets('rental listing shows rental CTAs instead of sale CTAs', (
    tester,
  ) async {
    final overflows = await _pumpDetail(
      tester,
      size: const Size(390, 844),
      listing: _listing(listingType: VehicleListingType.rental),
    );
    expect(overflows, isEmpty);
    expect(find.text('KİRALAMA TARİHİ SEÇ'), findsOneWidget);
    expect(find.text('ŞİMDİ KİRALA'), findsOneWidget);
    expect(find.text('GÖRÜŞME PLANLA'), findsNothing);
    expect(find.text('Teklif Ver'), findsNothing);
    expect(find.text('Sepete Ekle'), findsNothing);
    expect(find.text('Şimdi Al'), findsNothing);
  });

  testWidgets('rental facts render as grouped sections not stacked buttons', (
    tester,
  ) async {
    final overflows = await _pumpDetail(
      tester,
      size: const Size(1440, 900),
      listing: _listing(listingType: VehicleListingType.rental).copyWith(
        rental: const VehicleRentalSettings(
          dailyPrice: 1166,
          deposit: 5000,
          minDays: 3,
          maxDays: 30,
          kmLimitPerDay: 1000,
          extraKmPrice: 500,
          galleryPickup: true,
          mapPointDelivery: true,
          homeDelivery: true,
        ),
      ),
    );
    expect(overflows, isEmpty);
    expect(find.text('Teslim Alma'), findsOneWidget);
    expect(find.text('Kiralama Koşulları'), findsOneWidget);
    expect(find.text('Ücretler & Güvence'), findsOneWidget);
    expect(find.text('Kiralama Seçenekleri'), findsNothing);
    expect(find.text('Minimum 3 gün'), findsWidgets);
    expect(find.text('GÖRÜŞME PLANLA'), findsNothing);
  });

  testWidgets('layout overflow is zero at required breakpoints', (
    tester,
  ) async {
    const sizes = <String, Size>{
      'web-1920': Size(1920, 1080),
      'web-1600': Size(1600, 900),
      'web-1440': Size(1440, 900),
      'web-1366': Size(1366, 768),
      'web-1280': Size(1280, 800),
      'web-1024': Size(1024, 768),
      'tablet-768': Size(768, 1024),
      'mobile-430': Size(430, 932),
      'mobile-412': Size(412, 915),
      'mobile-390': Size(390, 844),
      'mobile-360': Size(360, 800),
      'mobile-320': Size(320, 700),
    };
    for (final entry in sizes.entries) {
      final overflows = await _pumpDetail(
        tester,
        size: entry.value,
        preview: entry.key.startsWith('web'),
      );
      expect(overflows, isEmpty, reason: 'overflow at ${entry.key}');
    }
    final wizard = await _pumpDetail(
      tester,
      size: const Size(1280, 720),
      preview: true,
      wizardChrome: true,
    );
    expect(wizard, isEmpty, reason: 'overflow in seller preview chrome');
  });

  testWidgets('thumbnail strip stays inside left gallery column', (
    tester,
  ) async {
    final media = List<VehicleMedia>.generate(
      10,
      (index) => VehicleMedia(
        id: 'photo-$index',
        slot: VehicleMediaSlot.other,
        url: 'https://cdn.example.com/vehicle-$index.jpg',
        sortOrder: index,
      ),
    );
    const sizes = <Size>[
      Size(1280, 800),
      Size(1366, 768),
      Size(1440, 900),
      Size(1600, 900),
      Size(1920, 1080),
    ];
    for (final size in sizes) {
      final overflows = await _pumpDetail(
        tester,
        size: size,
        listing: _listing(media: media),
      );
      expect(overflows, isEmpty, reason: 'overflow at ${size.width}');
      final strip = tester.getRect(
        find.byKey(const ValueKey('vehicle-detail-thumbnail-strip')),
      );
      final hero = tester.getRect(
        find.byKey(const ValueKey('vehicle-detail-hero-image')),
      );
      expect(strip.width, closeTo(hero.width, 1), reason: '${size.width}');
      expect(strip.left, closeTo(hero.left, 1), reason: '${size.width}');
      expect(strip.right, closeTo(hero.right, 1), reason: '${size.width}');
      final center = tester.getRect(find.byType(VehicleDetailCenterCard).first);
      expect(strip.right, lessThanOrEqualTo(center.left), reason: '${size.width}');
    }
  });

  testWidgets('mobile many photos do not widen the page', (tester) async {
    final media = List<VehicleMedia>.generate(
      8,
      (index) => VehicleMedia(
        id: 'photo-$index',
        slot: VehicleMediaSlot.other,
        url: 'https://cdn.example.com/vehicle-$index.jpg',
        sortOrder: index,
      ),
    );
    for (final size in const [
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ]) {
      final overflows = await _pumpDetail(
        tester,
        size: size,
        listing: _listing(media: media),
      );
      expect(overflows, isEmpty, reason: 'overflow at ${size.width}');
      expect(
        find.byKey(const ValueKey('vehicle-detail-thumbnail-strip')),
        findsNothing,
      );
    }
  });

  testWidgets('public mode hides preview badge', (tester) async {
    final overflows = await _pumpDetail(
      tester,
      size: const Size(1280, 800),
      preview: false,
    );
    expect(overflows, isEmpty);
    expect(find.text('Önizleme'), findsNothing);
    expect(find.text('Araç Özellikleri'), findsOneWidget);
    expect(find.text('Sepete Ekle'), findsNothing);
    expect(find.text('Şimdi Al'), findsNothing);
  });

  testWidgets('related listings rail renders at the bottom', (tester) async {
    final related = _listing().copyWith(
      extras: const {'title': 'Toyota Corolla 1.6'},
    );
    final overflows = await _pumpDetail(
      tester,
      size: const Size(390, 844),
      related: [related],
    );
    expect(overflows, isEmpty);
    expect(find.text('Benzer Araçlar'), findsOneWidget);
  });

  testWidgets('seller stock tile shows Yayında after admin approve', (
    tester,
  ) async {
    final listing = VehicleListing.fromMap({
      'id': 'live-1',
      'seller_id': 's1',
      'listing_type': 'sale',
      'status': 'active',
      'sale_price': 1200000,
      'vehicle_specs': {'brand': 'Toyota', 'model': 'Corolla', 'year': 2021},
      'ai_payload': {
        'title': 'Toyota Corolla',
        'moderation': {'status': 'approved'},
        'rejection_reason': 'eski not',
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleSellerStockTile(
            listing: listing,
            onEdit: () {},
            onPreview: () {},
            onPublish: () {},
            onUnpublish: () {},
            onSold: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
    expect(find.text('Yayında'), findsOneWidget);
    expect(find.text('Onaya Gönder'), findsNothing);
    expect(find.text('Yayından kaldır'), findsOneWidget);
    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Önizle'), findsOneWidget);
    expect(find.text('Satıldı'), findsOneWidget);
  });

  testWidgets('expand more button fits product 240px chrome', (tester) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) overflows.add(text);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogExpandMoreButton(expanded: false, onPressed: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(overflows, isEmpty);
    expect(find.text('DAHA FAZLA GÖSTER'), findsOneWidget);
  });

  testWidgets('capture layout screenshots for visual review', (tester) async {
    Future<void> shot(String name) async {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('vehicle-detail-capture')),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('test/features/vehicle/goldens/$name.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await _pumpDetail(tester, size: const Size(1440, 900));
    await shot('desktop-1440');
    await _pumpDetail(tester, size: const Size(390, 844));
    await shot('mobile-390');
    await _pumpDetail(
      tester,
      size: const Size(1280, 720),
      preview: true,
      wizardChrome: true,
    );
    await shot('preview-1280');
    expect(
      File('test/features/vehicle/goldens/desktop-1440.png').existsSync(),
      isTrue,
    );
  });
}
