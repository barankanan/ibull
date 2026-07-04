import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/product_load_trace.dart';
import 'package:ibul_app/core/runtime_diagnostic_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Product load messages', () {
    test('offline shows internet message', () {
      expect(
        resolveProductLoadUserMessage(
          Exception('network'),
          isOnline: false,
        ),
        'İnternet bağlantınızı kontrol edin.',
      );
    });

    test('timeout shows retry message', () {
      expect(
        resolveProductLoadUserMessage(
          TimeoutException('slow'),
          isOnline: true,
        ),
        contains('Bağlantınızı'),
      );
    });

    test('PostgrestException shows server message', () {
      expect(
        resolveProductLoadUserMessage(
          PostgrestException(message: 'RLS'),
          isOnline: true,
        ),
        contains('sunucu sorgu hatası'),
      );
    });

    test('empty state does not treat load notice as error by default', () {
      expect(productEmptyStateMessage(), 'Henüz ürün bulunmuyor.');
      expect(
        productEmptyStateMessage(loadNotice: 'offline cache', isError: false),
        'offline cache',
      );
    });

    test('filter empty message explains approval drop', () {
      expect(
        productFilterEmptyUserMessage(
          rawCount: 10,
          afterActiveCount: 8,
          afterApprovalCount: 0,
        ),
        contains('onay'),
      );
    });
  });

  group('ProductLoadTraceNotifier', () {
    test('persists stage updates in snapshot', () {
      final trace = ProductLoadTraceNotifier();
      trace.update(
        stage: ProductLoadTraceStage.fetchStarted,
        table: 'products',
        rawCount: 5,
      );
      expect(trace.snapshot.stage, ProductLoadTraceStage.fetchStarted);
      expect(trace.snapshot.rawCount, 5);
    });
  });

  group('formatProductLoadDebugDetail', () {
    test('includes table query and counts', () {
      final detail = formatProductLoadDebugDetail(
        table: 'products',
        query: 'products.select(...)',
        rawCount: 12,
        filteredCount: 0,
        afterActiveCount: 12,
        afterApprovalCount: 0,
        error: PostgrestException(message: 'test'),
      );
      expect(detail, contains('table: products'));
      expect(detail, contains('rawCount: 12'));
      expect(detail, contains('filteredCount: 0'));
      expect(detail, contains('PostgrestException'));
    });
  });
}
