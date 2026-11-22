import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/station_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('stationSaveErrorMessage', () {
    test('a missing column is named, not swallowed', () {
      final message = stationSaveErrorMessage(
        const PostgrestException(
          message: "Could not find the 'color' column of 'stations'",
          code: 'PGRST204',
        ),
      );
      expect(message, contains('kaydedilemedi'));
      expect(message, contains("'color'"));
      expect(message, contains('Şema güncellemesi'));
    });

    test('a duplicate code asks for another code', () {
      final message = stationSaveErrorMessage(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      expect(message, contains('zaten kullanılıyor'));
    });

    test('a permission failure says so', () {
      final message = stationSaveErrorMessage(
        const PostgrestException(message: 'denied', code: '42501'),
      );
      expect(message, contains('yetkiniz yok'));
    });

    test('anything else still carries the real reason', () {
      expect(
        stationSaveErrorMessage(const PostgrestException(message: 'boom')),
        contains('boom'),
      );
      expect(stationSaveErrorMessage(StateError('offline')), contains('offline'));
      // Never a success-sounding text.
      expect(
        stationSaveErrorMessage(StateError('x')),
        isNot(contains('eklendi')),
      );
    });
  });

  test('a failed load is not worded as an empty list', () {
    final message = stationLoadErrorMessage(
      const PostgrestException(message: 'stream failed'),
    );
    expect(message, contains('yüklenemedi'));
    expect(message, isNot(contains('bulunamadı')));
  });
}
