import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/mall/widgets/mall_application_presentation.dart';

void main() {
  testWidgets('local logo bytes replace the placeholder', (tester) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MallImageFrame(
          bytes: bytes,
          url: null,
          aspectRatio: 1,
          logTag: 'LOGO_PREVIEW',
          placeholder: const Text('LOGO_PLACEHOLDER'),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('LOGO_PLACEHOLDER'), findsNothing);
  });

  testWidgets('network failure falls back without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MallImageFrame(
          bytes: null,
          url: 'https://example.invalid/logo.jpg',
          aspectRatio: 1,
          logTag: 'LOGO_PREVIEW',
          placeholder: Text('LOGO_PLACEHOLDER'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('LOGO_PLACEHOLDER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty media shows the placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MallImageFrame(
          bytes: null,
          url: null,
          aspectRatio: 16 / 6,
          logTag: 'COVER_PREVIEW',
          placeholder: Text('COVER_PLACEHOLDER'),
        ),
      ),
    );
    expect(find.text('COVER_PLACEHOLDER'), findsOneWidget);
  });
}
