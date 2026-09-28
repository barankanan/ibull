import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/auth/customer_login_completion.dart';

void main() {
  testWidgets('successful customer login pops a pushed login route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (loginContext) {
                      return Scaffold(
                        body: ElevatedButton(
                          onPressed: () {
                            CustomerLoginCompletion.finish(
                              loginContext,
                              sessionReady: true,
                            );
                          },
                          child: const Text('finish-login'),
                        ),
                      );
                    },
                  ),
                );
              },
              child: const Text('open-login'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open-login'));
    await tester.pumpAndSettle();
    expect(find.text('finish-login'), findsOneWidget);

    await tester.tap(find.text('finish-login'));
    await tester.pumpAndSettle();
    expect(find.text('finish-login'), findsNothing);
    expect(find.text('open-login'), findsOneWidget);
  });
}
