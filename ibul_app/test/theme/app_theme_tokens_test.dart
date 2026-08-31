import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/app_bootstrap.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/widgets/ibul_page_state.dart';

void main() {
  test('AppColors exposes 24+ semantic roles aliased to live hex', () {
    expect(AppColors.primary, const Color(0xFF7A2FF4));
    expect(AppColors.surface, const Color(0xFFFFFFFF));
    expect(AppColors.onSurface, AppColors.textDark);
    expect(AppColors.onSurfaceMuted, AppColors.textGrey);
    expect(AppColors.surfaceMuted, AppColors.background);
    expect(AppColors.warning, AppColors.orangeDark);
    expect(AppColors.ink, const Color(0xFF222222));
    expect(AppColors.border, const Color(0xFFEEEEEE));

    const colorFields = [
      AppColors.primary,
      AppColors.background,
      AppColors.textDark,
      AppColors.textGrey,
      AppColors.softPurple,
      AppColors.popupLavender,
      AppColors.popupLavenderStrong,
      AppColors.orangeLight,
      AppColors.orangeDark,
      AppColors.surface,
      AppColors.surfaceMuted,
      AppColors.onSurface,
      AppColors.onSurfaceMuted,
      AppColors.onPrimary,
      AppColors.ink,
      AppColors.border,
      AppColors.borderStrong,
      AppColors.iconMuted,
      AppColors.iconFaint,
      AppColors.danger,
      AppColors.dangerSoft,
      AppColors.success,
      AppColors.successSoft,
      AppColors.warning,
      AppColors.warningSoft,
      AppColors.accentContainer,
      AppColors.overlay,
      AppColors.scrim,
    ];
    expect(colorFields.length, greaterThanOrEqualTo(24));
  });

  testWidgets('buildAppTheme keeps primary and registers IbulColorTokens',
      (tester) async {
    late ColorScheme scheme;
    late IbulColorTokens tokens;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            tokens = IbulColorTokens.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(scheme.primary, AppColors.primary);
    expect(tokens.primary, AppColors.primary);
    expect(tokens.surface, AppColors.surface);
  });

  test('product MaterialApps lock locale to Turkish only', () {
    for (final path in [
      'lib/app/customer_app.dart',
      'lib/app/full_app.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('kIbulLocale'));
      expect(source, contains('kIbulSupportedLocales'));
      expect(source, isNot(contains("Locale('en')")));
    }
  });

  testWidgets('IbulPageState empty and error render shared copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: IbulPageState.empty(
            icon: Icons.search_off,
            title: 'Aramana uygun ürün bulunamadı.',
          ),
        ),
      ),
    );
    expect(find.text('Aramana uygun ürün bulunamadı.'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: IbulPageState.error(
            title: 'Siparişler yüklenemedi',
            onAction: () {},
          ),
        ),
      ),
    );
    expect(find.text('Siparişler yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });

  testWidgets('IbulPageState loading is announced', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: IbulPageState.loading(loadingMessage: 'Sepet yükleniyor'),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Sepet yükleniyor'), findsOneWidget);
    handle.dispose();
  });

  test('marketplace empty states share IbulPageState', () {
    const files = [
      'lib/screens/addresses_page.dart',
      'lib/screens/lists_page.dart',
      'lib/screens/my_chats_page.dart',
      'lib/screens/notifications_page.dart',
      'lib/screens/orders_page.dart',
      'lib/screens/followed_stores_page.dart',
      'lib/screens/category_products_page.dart',
      'lib/screens/favorites_page.dart',
      'lib/screens/cart_page.dart',
    ];
    for (final path in files) {
      expect(
        File(path).readAsStringSync(),
        contains('ibul_page_state.dart'),
        reason: path,
      );
    }
  });
}
