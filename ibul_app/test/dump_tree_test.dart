import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ibul_app/app/app_bootstrap.dart';
import 'package:ibul_app/screens/home/home_initial_page.dart';

void main() {
  testWidgets('Dump home initial page widget tree', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: HomeInitialPage()),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    debugDumpApp();
  });
}
