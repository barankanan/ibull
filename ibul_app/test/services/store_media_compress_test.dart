import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/store_media_service.dart';
import 'package:ibul_app/utils/product_create_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StoreMediaService.compressBytes', () {
    late StoreMediaService service;

    setUp(() {
      service = StoreMediaService(
        supabase: SupabaseClient('https://example.supabase.co', 'test-anon-key'),
        currentUserIdResolver: () => 'test-user',
      );
    });

    test('returns original bytes when native compressor is unavailable', () async {
      final input = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00, 0x10]);
      final output = await service.compressBytes(input);
      expect(output, input);
    });
  });

  group('productCreateErrorMessage', () {
    test('maps UnimplementedError to user-friendly text', () {
      expect(
        productCreateErrorMessage(UnimplementedError()),
        'Ürün kaydedilemedi. Lütfen tekrar deneyin.',
      );
      expect(
        productCreateErrorMessage(UnimplementedError(), imagePhase: true),
        'Görsel yüklenemedi. Lütfen tekrar deneyin.',
      );
    });
  });
}
