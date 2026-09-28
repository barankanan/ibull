import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller/seller_forgot_password_page.dart';

void main() {
  testWidgets('seller forgot password is a dedicated page with three methods', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SellerForgotPasswordPage(initialEmail: 'galeri@gmail.com'),
      ),
    );

    expect(find.text('Şifrenizi sıfırlayın'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('Mağaza'), findsOneWidget);
    expect(find.text('Sıfırlama bağlantısı gönder'), findsOneWidget);
    expect(find.text('Giriş ekranına dön'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('galeri@gmail.com'), findsOneWidget);

    await tester.tap(find.text('Telefon'));
    await tester.pump();
    expect(find.text('SMS kodu gönder'), findsOneWidget);
  });

  testWidgets('forgot password stacks on the login screen instead of home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SellerForgotPasswordPage.open(
                context,
                initialEmail: 'barangaleri@gmail.com',
              ),
              child: const Text('Şifremi unuttum'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Şifremi unuttum'));
    await tester.pumpAndSettle();

    expect(find.text('Şifrenizi sıfırlayın'), findsOneWidget);
    expect(find.byType(SellerForgotPasswordPage), findsOneWidget);
  });
}
