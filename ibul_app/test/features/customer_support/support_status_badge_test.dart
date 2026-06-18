import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/customer_support/models/customer_support_models.dart';
import 'package:ibul_app/features/customer_support/widgets/support_status_badge.dart';

void main() {
  testWidgets('support status badge renders localized label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SupportStatusBadge(status: CustomerSupportStatus.answered),
        ),
      ),
    );
    expect(find.text('Cevaplandı'), findsOneWidget);
  });
}
