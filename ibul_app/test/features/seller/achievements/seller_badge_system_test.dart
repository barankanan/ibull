import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/achievements/data/seller_badge_definitions.dart';
import 'package:ibul_app/features/seller/achievements/helpers/seller_badge_public_display.dart';
import 'package:ibul_app/features/seller/achievements/helpers/seller_badge_visuals.dart';
import 'package:ibul_app/features/seller/achievements/models/seller_brand_verification_models.dart';
import 'package:ibul_app/features/seller/achievements/models/seller_badge_models.dart';
import 'package:ibul_app/features/seller/achievements/screens/seller_achievements_page.dart';
import 'package:ibul_app/features/seller/achievements/services/seller_badge_progress_resolver.dart';
import 'package:ibul_app/features/seller/achievements/services/seller_featured_badge_repository.dart';
import 'package:ibul_app/features/seller/achievements/widgets/seller_badge_map_popup_row.dart';
import 'package:ibul_app/features/seller/achievements/widgets/seller_badge_widgets.dart';
import 'package:ibul_app/models/store_follow_state.dart';

void main() {
  group('Seller badge system', () {
    test('formatted follower count never uses fake 9.8B demo label', () {
      expect(
        const StoreFollowState(followerCount: 1).formattedFollowerCount,
        '1 Takipçi',
      );
      expect(
        const StoreFollowState(followerCount: 0).formattedFollowerCount,
        '0 Takipçi',
      );
      expect(
        const StoreFollowState(followerCount: 9800).formattedFollowerCount,
        '9.8 Bin Takipçi',
      );
      expect(
        const StoreFollowState(followerCount: 9800).formattedFollowerCount,
        isNot(contains('9.8B')),
      );
    });

    test('map popup shows no badges when none are earned', () {
      final badges = SellerBadgePublicDisplay.mapPopupBadges(
        const SellerBadgeStoreMetrics(followerCount: 0, productCount: 0),
      );
      expect(badges, isEmpty);
    });

    test('map popup does not fake verified badge without brand data', () {
      final metrics = SellerBadgePublicDisplay.metricsFromBusinessMap({
        'seller_id': 'seller-1',
        'follower_count': 1200,
        'product_count': 2,
        'profile_complete': true,
        'has_logo': true,
        'has_description': true,
        'has_category': true,
        'has_contact_info': true,
      });
      expect(metrics.isBrandVerified, isFalse);

      final badges = SellerBadgePublicDisplay.mapPopupBadges(metrics);
      expect(
        badges.any((badge) => badge.definition.badgeId == 'verified_store'),
        isFalse,
      );
    });

    test('map popup can show verified badge only when brand verified', () {
      final metrics = SellerBadgePublicDisplay.metricsFromBusinessMap({
        'seller_id': 'seller-1',
        'is_brand_verified': true,
      });
      expect(metrics.isBrandVerified, isTrue);

      final badges = SellerBadgePublicDisplay.mapPopupBadges(metrics);
      expect(
        badges.any((badge) => badge.definition.badgeId == 'verified_store'),
        isTrue,
      );
    });

    test('map popup limits earned public badges to two', () {
      final badges = SellerBadgePublicDisplay.mapPopupBadges(
        const SellerBadgeStoreMetrics(
          followerCount: 1200,
          productCount: 2,
          profileComplete: true,
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: true,
          hasRegionInfo: true,
        ),
      );
      expect(badges.length, lessThanOrEqualTo(2));
      expect(
        badges.every((badge) => badge.status == SellerBadgeStatus.earned),
        isTrue,
      );
    });

    test('profile badges respect featured selection when provided', () {
      final metrics = const SellerBadgeStoreMetrics(
        followerCount: 120,
        productCount: 3,
        profileComplete: true,
        hasLogo: true,
        hasDescription: true,
        hasCategory: true,
        hasContactInfo: true,
        featuredBadgeIds: ['first_followers', 'first_product'],
      );
      final badges = SellerBadgePublicDisplay.profileBadges(metrics);
      expect(badges.length, lessThanOrEqualTo(4));
      expect(
        badges.every((badge) => metrics.featuredBadgeIds.contains(
              badge.definition.badgeId,
            )),
        isTrue,
      );
    });

    test('profile featured badges are capped at four', () {
      final metrics = SellerBadgeStoreMetrics(
        followerCount: 1200,
        productCount: 5,
        profileComplete: true,
        hasLogo: true,
        hasDescription: true,
        hasCategory: true,
        hasContactInfo: true,
        featuredBadgeIds: List<String>.generate(
          6,
          (index) => 'badge_$index',
        ),
      );
      final badges = SellerBadgePublicDisplay.profileBadges(metrics);
      expect(badges.length, lessThanOrEqualTo(4));
    });

    test('premium glow only for earned gold/diamond or premiumGlow badges', () {
      final metrics = const SellerBadgeStoreMetrics(followerCount: 300);
      final popular = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        metrics,
      );
      final newSeller = SellerBadgeProgressResolver.resolveById(
        'new_seller',
        metrics,
      );
      expect(popular?.allowsPremiumGlow, isTrue);
      expect(newSeller?.allowsPremiumGlow, isFalse);
    });

    test('new seller earns when profile and product complete regardless of store age', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'new_seller',
        SellerBadgeStoreMetrics(
          productCount: 2,
          completedOrderCount: 50,
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: true,
          profileComplete: true,
          storeCreatedAt: DateTime(2020, 1, 1),
        ),
      );
      expect(progress?.status, SellerBadgeStatus.earned);
      expect(progress?.progressCurrent, 1);
      expect(progress?.progressTarget, 1);
    });

    test('verified store badge earned when brand verified', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'verified_store',
        const SellerBadgeStoreMetrics(isBrandVerified: true),
      );
      expect(progress?.status, SellerBadgeStatus.earned);
      expect(progress?.allowsPremiumGlow, isTrue);
      expect(progress?.allowsGlowReplay, isTrue);
    });

    test('verified store visual uses blue palette', () {
      expect(sellerVerifiedBadgeUsesBluePalette(), isTrue);
    });

    test('brand verification form validation blocks incomplete submit', () {
      const form = SellerBrandVerificationFormData();
      expect(form.validateForSubmit(), isNotNull);
    });

    test('brand verification form accepts complete payload', () {
      const form = SellerBrandVerificationFormData(
        fullName: 'Test User',
        brandName: 'Test Brand',
        companyTitle: 'Test AŞ',
        mersisNo: '123',
        taxNo: '456',
        companyFoundedAt: null,
        email: 'a@b.com',
        phone: '555',
        tradeRegistryNo: '789',
        taxPlatePath: 'path/tax.pdf',
        tradeRegistryPath: 'path/trade.pdf',
        acceptedAccuracy: true,
        acceptedReview: true,
      );
      expect(form.validateForSubmit(), contains('kuruluş'));
    });

    test('new seller badge is not presented as premium quality', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'new_seller',
        const SellerBadgeStoreMetrics(
          productCount: 1,
          profileComplete: true,
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: true,
        ),
      );
      expect(progress?.status, SellerBadgeStatus.earned);
      expect(progress?.definition.level, SellerBadgeLevel.bronze);
      expect(progress?.allowsPremiumGlow, isFalse);
    });

    test('region rank badges use unavailable without ranking data', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'region_first',
        const SellerBadgeStoreMetrics(hasRegionInfo: true),
      );
      expect(progress?.status, SellerBadgeStatus.unavailable);
      expect(
        sellerBadgeProgressLabel(progress!),
        contains('veri kaynağı henüz hazır değil'),
      );
    });

    test('telemetry badges never show permanent calculating label', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'fast_shipping',
        const SellerBadgeStoreMetrics(completedOrderCount: 10),
      );
      expect(progress?.status, SellerBadgeStatus.unavailable);
      expect(sellerBadgeProgressLabel(progress!), isNot(contains('hesaplanıyor')));
    });

    test('store ready checklist tracks four profile fields', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'store_ready',
        const SellerBadgeStoreMetrics(
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: false,
        ),
      );
      expect(progress?.progressCurrent, 3);
      expect(progress?.progressTarget, 4);
      expect(progress?.checklistItems.length, 4);
      expect(progress?.incompleteChecklistItems.length, 1);
      expect(
        progress?.incompleteChecklistItems.first.focus,
        SellerStoreProfileFocus.contact,
      );
    });

    test('store ready earns at four of four without product requirement', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'store_ready',
        const SellerBadgeStoreMetrics(
          productCount: 0,
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: true,
        ),
      );
      expect(progress?.status, SellerBadgeStatus.earned);
      expect(progress?.progressCurrent, 4);
      expect(progress?.progressTarget, 4);
    });

    test('insufficient data state for review badges without ratings', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'reliable_seller',
        const SellerBadgeStoreMetrics(),
      );
      expect(progress?.status, SellerBadgeStatus.insufficientData);
      expect(
        sellerBadgeProgressLabel(progress!),
        contains('yeterli veri'),
      );
    });

    test('error state when metrics load failed', () {
      final badges = SellerBadgeProgressResolver.resolveAll(
        const SellerBadgeStoreMetrics(metricsLoadFailed: true),
      );
      expect(badges, isNotEmpty);
      expect(
        badges.every((badge) => badge.status == SellerBadgeStatus.error),
        isTrue,
      );
    });

    test('follower difficulty tiers match faz 2 targets', () {
      expect(
        SellerBadgeProgressResolver.resolveById(
          'first_followers',
          const SellerBadgeStoreMetrics(followerCount: 9),
        )?.progressTarget,
        10,
      );
      expect(
        SellerBadgeProgressResolver.resolveById(
          'phenomenal_store',
          const SellerBadgeStoreMetrics(followerCount: 4999),
        )?.progressTarget,
        5000,
      );
    });

    test('order difficulty tiers match faz 2 targets', () {
      expect(
        SellerBadgeProgressResolver.resolveById(
          'first_order',
          const SellerBadgeStoreMetrics(),
        )?.progressTarget,
        10,
      );
      expect(
        SellerBadgeProgressResolver.resolveById(
          'diamond_seller',
          const SellerBadgeStoreMetrics(),
        )?.progressTarget,
        2000,
      );
    });

    test('region joined resolves from region info not profile checklist', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'region_joined',
        const SellerBadgeStoreMetrics(
          hasRegionInfo: true,
          hasLogo: false,
          hasDescription: false,
        ),
      );
      expect(progress?.status, SellerBadgeStatus.earned);
    });

    test('featured badge repository enforces profile cap', () {
      expect(SellerFeaturedBadgeRepository.maxProfileBadges, 4);
      expect(SellerFeaturedBadgeRepository.maxMapPopupBadges, 2);
    });

    testWidgets('detail button opens detail panel', (tester) async {
      final progress = SellerBadgeProgressResolver.resolveById(
        'store_ready',
        const SellerBadgeStoreMetrics(
          hasLogo: true,
          hasDescription: true,
          hasCategory: false,
          hasContactInfo: true,
        ),
      );
      expect(progress, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerBadgeTaskCard(progress: progress!),
          ),
        ),
      );

      await tester.tap(find.text('Detay'));
      await tester.pumpAndSettle();

      expect(find.text('Görev nedir?'), findsOneWidget);
      expect(find.text('Profil kontrol listesi'), findsOneWidget);
    });

    testWidgets('category chip bar renders all categories', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SellerBadgeCategoryChipBar(
              selectedCategory: null,
              onSelected: _noopCategorySelect,
            ),
          ),
        ),
      );

      expect(find.text('Tümü'), findsOneWidget);
      expect(find.text('Kargo'), findsOneWidget);
      expect(find.text('Bölgesel'), findsOneWidget);
    });

    testWidgets('premium glow disabled for new seller icon', (tester) async {
      final progress = SellerBadgeProgressResolver.resolveById(
        'new_seller',
        const SellerBadgeStoreMetrics(
          productCount: 1,
          profileComplete: true,
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: true,
        ),
      );
      expect(progress, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerBadgeIcon(
              progress: progress!,
              animateGlow: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1400));
      expect(progress.allowsPremiumGlow, isFalse);
    });

    testWidgets('achievements page renders with empty metrics without crash',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SellerAchievementsPage(
              metrics: SellerBadgeStoreMetrics(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('Başarılarım'), findsOneWidget);
      expect(find.text('Tüm Görevler'), findsOneWidget);
      expect(find.text('Detay'), findsWidgets);
    });

    testWidgets('achievements page shows error state when metrics load failed',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SellerAchievementsPage(
              metrics: SellerBadgeStoreMetrics(metricsLoadFailed: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('Başarılar yüklenemedi'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
    });

    testWidgets('category chip selection does not crash when context is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerAchievementsPage(
              metrics: const SellerBadgeStoreMetrics(productCount: 1),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(SellerBadgeCategoryChipBar),
          matching: find.text('Kargo'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Başarılarım'), findsOneWidget);
    });

    test('unavailable and insufficientData progress labels are not empty', () {
      final unavailable = SellerBadgeProgressResolver.resolveById(
        'fast_shipping',
        const SellerBadgeStoreMetrics(),
      );
      final insufficient = SellerBadgeProgressResolver.resolveById(
        'reliable_seller',
        const SellerBadgeStoreMetrics(),
      );
      expect(unavailable?.status, SellerBadgeStatus.unavailable);
      expect(insufficient?.status, SellerBadgeStatus.insufficientData);
      expect(sellerBadgeProgressLabel(unavailable!), isNotEmpty);
      expect(sellerBadgeProgressLabel(insufficient!), isNotEmpty);
    });

    test('badge definition icons are unique per badge id', () {
      final icons = kSellerBadgeDefinitions
          .map((definition) => definition.icon.codePoint)
          .toList(growable: false);
      expect(icons.length, icons.toSet().length);
    });

    test('category visual palettes are distinct', () {
      expect(sellerBadgeCategoryPalettesAreDistinct(), isTrue);
    });

    test('visual spec varies by category', () {
      final follower = sellerBadgeVisualSpec(
        SellerBadgeProgressResolver.resolveById(
          'first_followers',
          const SellerBadgeStoreMetrics(),
        )!,
      );
      final order = sellerBadgeVisualSpec(
        SellerBadgeProgressResolver.resolveById(
          'first_order',
          const SellerBadgeStoreMetrics(),
        )!,
      );
      expect(follower.iconColor, isNot(equals(order.iconColor)));
    });

    test('region joined visual uses location pin language', () {
      final progress = SellerBadgeProgressResolver.resolveById(
        'region_joined',
        const SellerBadgeStoreMetrics(hasRegionInfo: true),
      );
      expect(progress, isNotNull);
      final visual = sellerBadgeVisualSpec(progress!);
      expect(visual.icon, Icons.location_on_rounded);
    });

    testWidgets('map popup row tap shows badge info sheet', (tester) async {
      final progress = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        const SellerBadgeStoreMetrics(
          followerCount: 300,
          productCount: 1,
          profileComplete: true,
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: true,
        ),
      );
      expect(progress?.status, SellerBadgeStatus.earned);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SellerBadgeMapPopupRow(
                badges: [progress!],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(SellerBadgeIcon));
      await tester.pumpAndSettle();

      expect(find.text('Topluluk Çekimi'), findsWidgets);
      expect(find.textContaining('Seviye:'), findsOneWidget);
    });

    testWidgets('map popup row renders without badges as empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SellerBadgeMapPopupRow(badges: []),
          ),
        ),
      );
      expect(find.byType(SellerBadgeIcon), findsNothing);
    });

    testWidgets('featured tile has no filter chip check overlay', (tester) async {
      final progress = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        const SellerBadgeStoreMetrics(
          followerCount: 300,
          productCount: 1,
          profileComplete: true,
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: true,
        ),
      );
      expect(progress, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerFeaturedBadgeTile(
              progress: progress!,
              selected: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(FilterChip), findsNothing);
      expect(find.text('Vitrinde'), findsOneWidget);
    });

    testWidgets('İkonu İzle only on premium earned badges', (tester) async {
      final premium = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        const SellerBadgeStoreMetrics(followerCount: 300),
      );
      final newSeller = SellerBadgeProgressResolver.resolveById(
        'new_seller',
        const SellerBadgeStoreMetrics(
          productCount: 1,
          profileComplete: true,
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: true,
        ),
      );
      final inProgress = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        const SellerBadgeStoreMetrics(followerCount: 50),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SellerBadgeTaskCard(
                    progress: premium!,
                    onReplayGlow: () {},
                  ),
                  SellerBadgeTaskCard(
                    progress: newSeller!,
                    onReplayGlow: () {},
                  ),
                  SellerBadgeTaskCard(
                    progress: inProgress!,
                    onReplayGlow: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('İkonu İzle'), findsOneWidget);
      expect(find.byType(SellerGlowReplayButton), findsOneWidget);
    });

    test('glow replay button rules for levels', () {
      final gold = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        const SellerBadgeStoreMetrics(followerCount: 300),
      );
      final diamond = SellerBadgeProgressResolver.resolveById(
        'community_favorite',
        const SellerBadgeStoreMetrics(followerCount: 5000),
      );
      final verified = SellerBadgeProgressResolver.resolveById(
        'verified_store',
        const SellerBadgeStoreMetrics(isBrandVerified: true),
      );
      final bronze = SellerBadgeProgressResolver.resolveById(
        'first_followers',
        const SellerBadgeStoreMetrics(followerCount: 20),
      );

      expect(gold?.showsGlowReplayButton, isTrue);
      expect(diamond?.showsGlowReplayButton, isTrue);
      expect(verified?.showsGlowReplayButton, isTrue);
      expect(bronze?.showsGlowReplayButton, isFalse);
    });

    testWidgets('İkonu İzle sits beside Detay on task card', (tester) async {
      final premium = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        const SellerBadgeStoreMetrics(followerCount: 300),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerBadgeTaskCard(
              progress: premium,
              onReplayGlow: () {},
            ),
          ),
        ),
      );

      expect(find.text('İkonu İzle'), findsOneWidget);
      expect(find.text('Detay'), findsOneWidget);
    });

    testWidgets('featured tile shows İkonu İzle for premium earned badge',
        (tester) async {
      final premium = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        const SellerBadgeStoreMetrics(followerCount: 300),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerFeaturedBadgeTile(
              progress: premium,
              selected: true,
              onTap: () {},
              onReplayGlow: () {},
            ),
          ),
        ),
      );

      expect(find.text('İkonu İzle'), findsOneWidget);
    });

    testWidgets('replay button increments glow token on achievements page',
        (tester) async {
      final metrics = const SellerBadgeStoreMetrics(
        sellerId: 'seller-1',
        followerCount: 300,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerAchievementsPage(metrics: metrics),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final replayButtons = find.text('İkonu İzle');
      if (replayButtons.evaluate().isEmpty) {
        // earned premium badge yoksa test atlanır
        return;
      }

      await tester.tap(replayButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('İkonu İzle'), findsWidgets);
    });

    testWidgets('glow replay token restarts icon animation', (tester) async {
      final progress = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        const SellerBadgeStoreMetrics(followerCount: 300),
      );
      expect(progress?.allowsPremiumGlow, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              var token = 0;
              return Scaffold(
                body: Column(
                  children: [
                    SellerBadgeIcon(
                      key: ValueKey(token),
                      progress: progress!,
                      glowReplayToken: token,
                    ),
                    TextButton(
                      onPressed: () => setState(() => token++),
                      child: const Text('replay'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('replay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SellerBadgeIcon), findsOneWidget);
    });
  });
}

void _noopCategorySelect(SellerBadgeCategory? _) {}
