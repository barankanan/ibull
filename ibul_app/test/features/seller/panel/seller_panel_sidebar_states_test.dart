import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/widgets/seller_panel_shell.dart';

double _lin(int c) {
  final v = c / 255;
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(Color c) =>
    0.2126 * _lin((c.r * 255).round()) +
    0.7152 * _lin((c.g * 255).round()) +
    0.0722 * _lin((c.b * 255).round());

Color _over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

double _contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

Widget _wrap(Widget child, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: width, child: Material(child: child))),
  ),
);

SellerPanelMenuEntry _locked(VoidCallback onTap) => SellerPanelMenuEntry(
  icon: Icons.receipt_long,
  label: 'Siparişler',
  isActive: false,
  state: SellerMenuItemState.lockedOffline,
  onTap: onTap,
);

void main() {
  test('locked text and icon colours meet WCAG AA on sidebar', () {
    final text = _over(kSellerMenuLockedTextColor, kSellerMenuSidebarColor);
    final icon = _over(kSellerMenuLockedIconColor, kSellerMenuSidebarColor);
    expect(_contrast(text, kSellerMenuSidebarColor), greaterThanOrEqualTo(4.5));
    expect(_contrast(icon, kSellerMenuSidebarColor), greaterThanOrEqualTo(4.5));
  });

  testWidgets('locked item: lock, hint, plain title, tap fires', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _wrap(SellerPanelSidebarItem(item: _locked(() => taps++))),
    );
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.text('İnternet gerekli'), findsOneWidget);
    expect(find.text('Siparişler'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    await t.tap(find.text('Siparişler'));
    expect(taps, 1);
  });

  testWidgets('open item has no lock or hint', (t) async {
    await t.pumpWidget(
      _wrap(
        SellerPanelSidebarItem(
          item: SellerPanelMenuEntry(
            icon: Icons.receipt_long,
            label: 'Siparişler',
            isActive: false,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.text('İnternet gerekli'), findsNothing);
  });

  testWidgets('collapsed locked item tooltip and badge', (t) async {
    await t.pumpWidget(
      _wrap(
        SellerPanelSidebarItem(item: _locked(() {}), collapsed: true),
        width: 56,
      ),
    );
    final tip = t.widget<Tooltip>(find.byType(Tooltip));
    expect(tip.message, 'Siparişler: İnternet gerekli');
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('320pt drawer renders without overflow', (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SellerPanelMobileDrawer(
            onLogoutTap: () {},
            items: [
              _locked(() {}),
              SellerPanelMenuEntry(
                icon: Icons.table_bar,
                label: 'Çok uzun bir sayfa adı örneği burada devam ediyor',
                isActive: true,
                onTap: () {},
              ),
              SellerPanelMenuEntry(
                icon: Icons.print,
                label: 'Yazıcılar ve mutfak yönlendirme ayarları',
                isActive: false,
                state: SellerMenuItemState.lockedOffline,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('İnternet gerekli'), findsNWidgets(2));
  });
}
