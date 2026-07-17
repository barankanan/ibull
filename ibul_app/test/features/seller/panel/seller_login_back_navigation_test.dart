import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_navigation.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_exit_destination.dart';
import 'package:ibul_app/screens/seller_login_page.dart';

void main() {
  group('SellerLoginBackNavigation', () {
    test('fallback resolves to guest home when no customer session', () {
      final destination = SellerExitDestination.resolve(
        customerSessionActive: false,
        hasSupabaseSession: false,
      );
      expect(destination.route, HomeNavigation.routeName);
      expect(
        (destination.arguments! as HomeRouteArgs).initialIndex,
        0,
      );
    });

    testWidgets('back button pops when canPop=true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SellerLoginPage(),
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  });
}
