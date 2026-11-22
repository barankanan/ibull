import 'package:flutter_test/flutter_test.dart';
import 'package:ihiz_web/src/util/ihiz_courier_error_text.dart';

void main() {
  group('ihizCourierSyncFailureHint', () {
    test('RLS reddi tablo/policy adı sızdırmadan yetki mesajına çevrilir', () {
      final hint = ihizCourierSyncFailureHint(
        'code=42501 | new row violates row-level security policy for table '
        '"order_items"',
      );

      expect(hint, contains('yetkisi yok'));
      expect(hint, contains('Hata kodu: 42501'));
      expect(hint.toLowerCase(), isNot(contains('order_items')));
      expect(hint.toLowerCase(), isNot(contains('rls')));
      expect(hint.toLowerCase(), isNot(contains('policy')));
      expect(hint.toLowerCase(), isNot(contains('row-level')));
    });

    test('ağ hatası bağlantı mesajına çevrilir', () {
      for (final raw in const [
        'ClientException: Failed host lookup: xyz.supabase.co',
        'SocketException: Connection refused',
        'TimeoutException after 0:00:10.000000',
        'ClientException: XMLHttpRequest error.',
        'TypeError: Failed to fetch',
      ]) {
        final hint = ihizCourierSyncFailureHint(raw);
        expect(hint, contains('İnternet bağlantınızı'), reason: raw);
        expect(hint, isNot(contains('supabase')), reason: raw);
      }
    });

    test('bilinmeyen teknik hata ham metni kuryeye göstermez', () {
      final hint = ihizCourierSyncFailureHint(
        'code=23514 | new row for relation "orders" violates check constraint '
        '"orders_status_check" | Failing row contains (secret-id, ...)',
      );

      expect(hint, contains('Beklenmeyen bir hata'));
      expect(hint, contains('Hata kodu: 23514'));
      expect(hint, isNot(contains('orders_status_check')));
      expect(hint, isNot(contains('secret-id')));
    });

    test('eksik sipariş kimliği yenileme önerir', () {
      expect(
        ihizCourierSyncFailureHint(ihizMissingOrderIdSyncError),
        contains('Görev listesini yenileyip'),
      );
    });

    test('boş veya bilinmeyen hata genel öneri döndürür', () {
      for (final raw in <String?>[null, '', '   ', 'unknown_delivery_error']) {
        final hint = ihizCourierSyncFailureHint(raw);
        expect(hint, contains('tekrar deneyin'), reason: '$raw');
        expect(hint, isNot(contains('unknown_delivery_error')));
      }
    });

    test('paket artık havuzda değilse yetki/bağlantı değil çakışma anlatılır', () {
      final hint = ihizCourierSyncFailureHint(
        ihizPickupNoLongerAvailableSyncError,
      );
      expect(hint, contains('başka bir kurye'));
      expect(hint, isNot(contains('yetki')));
      expect(hint, isNot(contains('pickup_no_longer_available')));
    });

    test('mesajlar Türkçe karakterlerle yazılır (ASCII kalıntısı yok)', () {
      final all = [
        ihizCourierSyncFailureHint(null),
        ihizCourierSyncFailureHint('permission denied'),
        ihizCourierSyncFailureHint('network'),
        ihizCourierSyncFailureHint('boom'),
        ihizCourierSyncFailureHint(ihizMissingOrderIdSyncError),
      ].join(' ');

      for (final ascii in const ['baglanti', 'saglanamadi', 'ayarini', 'Ag ']) {
        expect(all, isNot(contains(ascii)));
      }
    });
  });
}
