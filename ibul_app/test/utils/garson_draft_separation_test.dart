import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_draft_separation.dart';

void main() {
  const payload = '[{"product_id":"ordovr","quantity":1,"line_total":320}]';

  test('a second order of the same product stays in the new draft', () {
    final sent = <Map<String, dynamic>>[
      {
        'product_id': 'ordovr',
        'name': 'ORDÖVR TABAĞI',
        'quantity': 2,
        'line_total': 640,
        'notes': '',
      },
    ];
    final draft = <Map<String, dynamic>>[
      {
        'product_id': 'ordovr',
        'name': 'ORDÖVR TABAĞI',
        'quantity': 1,
        'line_total': 320,
        'notes': 'az acılı',
        'variant': 'büyük',
      },
    ];

    final lines = garsonNewOrderLines(draft);
    expect(garsonDraftHasNewOrder(draft), isTrue);
    expect(lines.single['quantity'], 1);
    expect(lines.single['line_total'], 320);
    expect(lines.single['notes'], 'az acılı');
    expect(lines.single['variant'], 'büyük');
    expect(lines.single['product_id'], sent.single['product_id']);
  });

  test('an empty draft does not create an order', () {
    expect(garsonNewOrderLines(const []), isEmpty);
    expect(garsonDraftHasNewOrder(const []), isFalse);
  });

  test('editing an open order does not store that order as a new draft', () {
    final sent = <Map<String, dynamic>>[
      {
        'product_id': 'ordovr',
        'name': 'ORDÖVR TABAĞI',
        'quantity': 2,
        'line_total': 640,
      },
    ];
    final unchanged = garsonDraftLinesBeyond(draft: sent, covered: sent);
    expect(unchanged, isEmpty);

    final increased = <Map<String, dynamic>>[
      {
        'product_id': 'ordovr',
        'name': 'ORDÖVR TABAĞI',
        'quantity': 3,
        'line_total': 960,
      },
    ];
    final extra = garsonDraftLinesBeyond(draft: increased, covered: sent);
    expect(extra.single['quantity'], 1);
    expect(extra.single['line_total'], 320);
  });

  test('one request keeps its key and the next order gets another', () {
    final first = resolveGarsonSubmitKey(
      requestPayload: payload,
      mintedKey: 'waiter-1',
    );
    expect(first.localOrderId, 'waiter-1');
    expect(first.reuse, isFalse);
    expect(first.blocked, isFalse);

    final retry = resolveGarsonSubmitKey(
      savedKey: first.localOrderId,
      savedPayload: payload,
      requestPayload: payload,
      mintedKey: 'waiter-should-not-be-used',
    );
    expect(retry.localOrderId, 'waiter-1');
    expect(retry.reuse, isTrue);

    final second = resolveGarsonSubmitKey(
      requestPayload: payload,
      mintedKey: 'waiter-2',
    );
    expect(second.localOrderId, 'waiter-2');
    expect(second.localOrderId, isNot(first.localOrderId));
    expect(second.reuse, isFalse);
  });

  test('the same cart keeps its key when the JSON field order changes', () {
    const reordered =
        '[{"quantity":1,"line_total":320,"product_id":"ordovr"}]';
    final retry = resolveGarsonSubmitKey(
      savedKey: 'waiter-1',
      savedPayload: payload,
      requestPayload: reordered,
      mintedKey: 'waiter-2',
    );
    expect(retry.blocked, isFalse);
    expect(retry.reuse, isTrue);
    expect(retry.localOrderId, 'waiter-1');
  });

  test('a different payload does not replace an unverified send', () {
    final blocked = resolveGarsonSubmitKey(
      savedKey: 'waiter-1',
      savedPayload: payload,
      requestPayload: '[{"product_id":"peynir","quantity":1}]',
      mintedKey: 'waiter-2',
    );
    expect(blocked.blocked, isTrue);
    expect(blocked.localOrderId, isNull);
  });
}
