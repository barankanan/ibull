import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/adisyon_payments_loader.dart';

void main() {
  const short = Duration(milliseconds: 50);

  test('server answered with no payments: readable zero, not unreadable', () async {
    final s = await loadAdisyonPayments(fetch: () async => []);
    expect(s, (paid: 0.0, readable: true, loading: false));
  });

  test('payments are summed', () async {
    final s = await loadAdisyonPayments(
      fetch: () async => [
        {'amount': 100, 'created_at': '2026-11-24T10:00:00Z'},
        {'amount': '25.5', 'created_at': '2026-11-24T10:05:00Z'},
      ],
    );
    expect(s.paid, 125.5);
    expect(s.readable, isTrue);
  });

  test('hung read ends as unreadable within the deadline', () async {
    final s = await loadAdisyonPayments(
      fetch: () => Completer<List<Map<String, dynamic>>>().future,
      deadline: short,
    );
    expect(s, adisyonPaymentsUnreadable);
  });

  test('error is unreadable, never zero paid', () async {
    Object? seen;
    final s = await loadAdisyonPayments(
      fetch: () async => throw Exception('net'),
      onError: (e) => seen = e,
    );
    expect(s.readable, isFalse);
    expect(s.loading, isFalse);
    expect(seen, isNotNull);
  });

  test('row with unreadable amount makes whole read unreadable', () async {
    final s = await loadAdisyonPayments(
      fetch: () async => [
        {'amount': null},
      ],
    );
    expect(s.readable, isFalse);
  });

  test('payments older than first order are ignored', () async {
    final s = await loadAdisyonPayments(
      fetch: () async => [
        {'amount': 50, 'created_at': '2026-11-01T10:00:00Z'},
        {'amount': 70, 'created_at': '2026-11-24T10:00:00Z'},
      ],
      earliestOrderAt: DateTime.parse('2026-11-24T09:00:00Z'),
    );
    expect(s.paid, 70);
  });
}
