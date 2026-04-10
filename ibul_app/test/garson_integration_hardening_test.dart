// ignore_for_file: lines_longer_than_80_chars
/// Garson Entegrasyon Sertleştirme Testleri
///
/// Kapsam (saf Dart, Supabase gerektirmez):
///
///   A.  KitchenPrintPolicy — shouldDispatchFullTicket + note constants
///   B.  validateTableOrderPayload — geçerli ve geçersiz senaryolar
///   C.  validateTablePaymentPayload — geçerli ve geçersiz senaryolar
///   D.  TablePaymentSession — kalan tutar hesabı, fazla ödeme, özet etiketi
///   E.  TableOrderHistoryRecord — fromMap, sessionDuration, revision eşiği
///   F.  GarsonOrderStatus.normalise() — alias + büyük harf + boşluk kenar durumları
///   G.  GarsonOperationRules delegasyon paritesi — eski switch ile equivalens
///   H.  KitchenPrintPolicy + GarsonOperationRules entegrasyon senaryoları
///   I.  TableLevelPolicy — canTransfer, canPay, subtitle sabitleri
///   J.  KitchenPrintPolicy.canReprint + TableLevelPolicy.canReprint
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ibul_app/models/garson_operation_rules.dart';
import 'package:ibul_app/models/restaurant_ops_models.dart';

// ─── Yardımcılar ──────────────────────────────────────────────────────────────

const _sellerId = 'test-seller-00000000-0000-0000-0000-000000000001';

TablePayment _pay({
  double amount = 100.0,
  String method = 'cash',
  bool isClosing = false,
}) =>
    TablePayment(
      id: 'pay-${amount.toStringAsFixed(0)}',
      sellerId: _sellerId,
      tableNumber: 3,
      sessionKey: 'sk-test',
      amount: amount,
      method: TablePaymentMethod.fromValue(method),
      isClosing: isClosing,
      createdAt: DateTime(2026, 4, 7, 12),
    );

Map<String, dynamic> _minimalOrderPayload({
  String? sellerId = _sellerId,
  dynamic tableNumber = 5,
  List<Map<String, dynamic>>? items,
}) =>
    {
      'seller_id': sellerId,
      'table_number': tableNumber,
      'items': items ??
          [
            {'name': 'Ciğer Şiş', 'price': 280.0, 'quantity': 1},
          ],
    };

Map<String, dynamic> _minimalPaymentPayload({
  String? sellerId = _sellerId,
  dynamic tableNumber = 5,
  dynamic amount = 280.0,
  String method = 'cash',
  String sessionKey = 'sk-test-001',
}) =>
    {
      'seller_id': sellerId,
      'table_number': tableNumber,
      'amount': amount,
      'method': method,
      'session_key': sessionKey,
    };

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // A. KitchenPrintPolicy
  // ══════════════════════════════════════════════════════════════════════════

  group('A. KitchenPrintPolicy', () {
    group('A1. shouldDispatchFullTicket — tam bilet statüleri', () {
      test('draft → tam bilet (mutfak hiç görmedi)', () {
        expect(KitchenPrintPolicy.shouldDispatchFullTicket('draft'), isTrue);
      });

      test('waiting → tam bilet (henüz iletilmedi)', () {
        expect(KitchenPrintPolicy.shouldDispatchFullTicket('waiting'), isTrue);
      });

      test("'new' → waiting alias → tam bilet", () {
        expect(KitchenPrintPolicy.shouldDispatchFullTicket('new'), isTrue);
      });
    });

    group('A2. shouldDispatchFullTicket — diff statüleri', () {
      for (final status in ['sent', 'preparing', 'ready', 'done', 'kitchen']) {
        test("'$status' → yalnızca diff (mutfak zaten gördü)", () {
          expect(
            KitchenPrintPolicy.shouldDispatchFullTicket(status),
            isFalse,
            reason: "'$status' durumunda mutfak siparişi zaten aldı",
          );
        });
      }

      test('served → diff (sipariş teslim edildi)', () {
        expect(KitchenPrintPolicy.shouldDispatchFullTicket('served'), isFalse);
      });

      test('closed → diff (masa kapalı)', () {
        expect(KitchenPrintPolicy.shouldDispatchFullTicket('closed'), isFalse);
      });

      test('null → default → diff (sent normalise edilir)', () {
        expect(KitchenPrintPolicy.shouldDispatchFullTicket(null), isFalse);
      });

      test('boş string → diff', () {
        expect(KitchenPrintPolicy.shouldDispatchFullTicket(''), isFalse);
      });
    });

    group('A3. Should be case/whitespace-insensitive', () {
      test("'DRAFT' → tam bilet", () {
        expect(KitchenPrintPolicy.shouldDispatchFullTicket('DRAFT'), isTrue);
      });

      test("'  Waiting  ' → tam bilet", () {
        expect(
          KitchenPrintPolicy.shouldDispatchFullTicket('  Waiting  '),
          isTrue,
        );
      });

      test("'SENT' → diff", () {
        expect(KitchenPrintPolicy.shouldDispatchFullTicket('SENT'), isFalse);
      });
    });

    group('A4. Note constants', () {
      test('addItemsNote Türkçe suffix doğru', () {
        expect(
          KitchenPrintPolicy.addItemsNote,
          'Sipariş revizyonu • eklenen kalemler',
        );
      });

      test('removeItemsNote Türkçe suffix doğru', () {
        expect(
          KitchenPrintPolicy.removeItemsNote,
          'Sipariş revizyonu • çıkarılan kalemler',
        );
      });

      test('reprintNote doğru', () {
        expect(KitchenPrintPolicy.reprintNote, 'Sipariş tekrar iletimi');
      });

      test('üç sabit birbirinden farklı', () {
        final notes = {
          KitchenPrintPolicy.addItemsNote,
          KitchenPrintPolicy.removeItemsNote,
          KitchenPrintPolicy.reprintNote,
        };
        expect(notes.length, 3, reason: 'Her sabit benzersiz olmalı');
      });
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // B. validateTableOrderPayload
  // ══════════════════════════════════════════════════════════════════════════

  group('B. validateTableOrderPayload', () {
    test('B1. geçerli payload → hata yok', () {
      final errors = validateTableOrderPayload(_minimalOrderPayload());
      expect(errors, isEmpty);
    });

    test('B2. seller_id boş → hata', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(sellerId: ''),
      );
      expect(errors, anyElement(contains('seller_id')));
    });

    test('B3. seller_id null → hata', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(sellerId: null),
      );
      expect(errors, anyElement(contains('seller_id')));
    });

    test('B4. table_number = 0 → hata', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(tableNumber: 0),
      );
      expect(errors, anyElement(contains('table_number')));
    });

    test('B5. table_number negatif → hata', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(tableNumber: -1),
      );
      expect(errors, anyElement(contains('table_number')));
    });

    test('B6. table_number string → geçerli int ise hata yok', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(tableNumber: '5'),
      );
      expect(errors, isEmpty);
    });

    test('B7. table_number harf string → hata', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(tableNumber: 'abc'),
      );
      expect(errors, anyElement(contains('table_number')));
    });

    test('B8. boş items listesi → hata', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(items: []),
      );
      expect(errors, anyElement(contains('items')));
    });

    test('B9. items null → hata', () {
      final payload = {
        'seller_id': _sellerId,
        'table_number': 5,
        'items': null,
      };
      final errors = validateTableOrderPayload(payload);
      expect(errors, anyElement(contains('items')));
    });

    test('B10. item name boş → hata', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(items: [
          {'name': '', 'price': 100.0, 'quantity': 1},
        ]),
      );
      expect(errors, anyElement(contains('name')));
    });

    test('B11. item price negatif → hata', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(items: [
          {'name': 'Test', 'price': -1.0, 'quantity': 1},
        ]),
      );
      expect(errors, anyElement(contains('price')));
    });

    test('B12. item price = 0 → geçerli (ücretsiz ürün mümkün)', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(items: [
          {'name': 'Test', 'price': 0, 'quantity': 1},
        ]),
      );
      expect(errors, isEmpty);
    });

    test('B13. item quantity = 0 → hata', () {
      final errors = validateTableOrderPayload(
        _minimalOrderPayload(items: [
          {'name': 'Test', 'price': 50.0, 'quantity': 0},
        ]),
      );
      expect(errors, anyElement(contains('quantity')));
    });

    test('B14. birden fazla hata aynı anda döner', () {
      final errors = validateTableOrderPayload({
        'seller_id': '',
        'table_number': 0,
        'items': [],
      });
      expect(errors.length, greaterThanOrEqualTo(3));
    });

    test('B15. hem kalem hatası hem de seller hatası → her ikisi listelenir', () {
      final errors = validateTableOrderPayload({
        'seller_id': '',
        'table_number': 3,
        'items': [
          {'name': '', 'price': -5.0, 'quantity': 0},
        ],
      });
      expect(errors, anyElement(contains('seller_id')));
      expect(errors, anyElement(contains('name')));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // C. validateTablePaymentPayload
  // ══════════════════════════════════════════════════════════════════════════

  group('C. validateTablePaymentPayload', () {
    test('C1. geçerli payload → hata yok', () {
      final errors = validateTablePaymentPayload(_minimalPaymentPayload());
      expect(errors, isEmpty);
    });

    test('C2. seller_id boş → hata', () {
      final errors = validateTablePaymentPayload(
        _minimalPaymentPayload(sellerId: ''),
      );
      expect(errors, anyElement(contains('seller_id')));
    });

    test('C3. amount = 0 → hata (sıfır ödeme geçersiz)', () {
      final errors = validateTablePaymentPayload(
        _minimalPaymentPayload(amount: 0.0),
      );
      expect(errors, anyElement(contains('amount')));
    });

    test('C4. amount negatif → hata', () {
      final errors = validateTablePaymentPayload(
        _minimalPaymentPayload(amount: -10.0),
      );
      expect(errors, anyElement(contains('amount')));
    });

    test('C5. amount string → hata (validator yalnızca num kabul eder)', () {
      final errors = validateTablePaymentPayload(
        _minimalPaymentPayload(amount: '150.50'),
      );
      expect(errors, anyElement(contains('amount')));
    });

    test('C6. table_number ≤ 0 → hata', () {
      final errors = validateTablePaymentPayload(
        _minimalPaymentPayload(tableNumber: 0),
      );
      expect(errors, anyElement(contains('table_number')));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // D. TablePaymentSession — ödeme hesabı
  // ══════════════════════════════════════════════════════════════════════════

  group('D. TablePaymentSession — kalan tutar ve özet', () {
    test('D1. ödeme yapılmadı → kalan = toplam', () {
      final session = TablePaymentSession(
        sessionKey: 'sk-1',
        tableNumber: 3,
        payments: const [],
        grandTotal: 500.0,
      );
      expect(session.remainingTotal, closeTo(500.0, 0.001));
      expect(session.isFullyPaid, isFalse);
      expect(session.paidTotal, closeTo(0.0, 0.001));
    });

    test('D2. tam ödeme → kalan = 0, isFullyPaid = true', () {
      final session = TablePaymentSession(
        sessionKey: 'sk-2',
        tableNumber: 3,
        payments: [_pay(amount: 500.0, isClosing: true)],
        grandTotal: 500.0,
      );
      expect(session.remainingTotal, closeTo(0.0, 0.001));
      expect(session.isFullyPaid, isTrue);
    });

    test('D3. kısmi ödeme → kalan = fark', () {
      final session = TablePaymentSession(
        sessionKey: 'sk-3',
        tableNumber: 3,
        payments: [_pay(amount: 200.0)],
        grandTotal: 500.0,
      );
      expect(session.remainingTotal, closeTo(300.0, 0.001));
      expect(session.isFullyPaid, isFalse);
    });

    test('D4. fazla ödeme → kalan 0 olarak sınırlandırılır (negatife düşmez)', () {
      final session = TablePaymentSession(
        sessionKey: 'sk-4',
        tableNumber: 3,
        payments: [_pay(amount: 600.0, isClosing: true)],
        grandTotal: 500.0,
      );
      expect(
        session.remainingTotal,
        closeTo(0.0, 0.001),
        reason: 'Fazla ödeme negatif kalan oluşturmamalı',
      );
      expect(session.isFullyPaid, isTrue);
    });

    test('D5. çoklu ödeme → toplamı doğru birleştirme', () {
      final session = TablePaymentSession(
        sessionKey: 'sk-5',
        tableNumber: 3,
        payments: [
          _pay(amount: 150.0),
          _pay(amount: 100.0),
          _pay(amount: 250.0, isClosing: true),
        ],
        grandTotal: 500.0,
      );
      expect(session.paidTotal, closeTo(500.0, 0.001));
      expect(session.isFullyPaid, isTrue);
    });

    test('D6. summaryLabel — ödeme yoksa', () {
      final session = TablePaymentSession(
        sessionKey: 'sk-6',
        tableNumber: 3,
        payments: const [],
        grandTotal: 200.0,
      );
      expect(session.summaryLabel, contains('Ödeme yapılmadı'));
    });

    test('D7. summaryLabel — tek ödeme var', () {
      final session = TablePaymentSession(
        sessionKey: 'sk-7',
        tableNumber: 3,
        payments: [_pay(amount: 200.0, isClosing: true)],
        grandTotal: 200.0,
      );
      expect(session.summaryLabel, contains('1'));
      expect(session.summaryLabel, contains('200'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // E. TableOrderHistoryRecord — fromMap + hesaplanan alanlar
  // ══════════════════════════════════════════════════════════════════════════

  group('E. TableOrderHistoryRecord', () {
    final openedAt = DateTime(2026, 4, 7, 12, 0);
    final closedAt = DateTime(2026, 4, 7, 13, 47);

    Map<String, dynamic> baseMap() => {
          'id': 'hr-001',
          'original_order_id': 'ord-001',
          'seller_id': _sellerId,
          'table_number': 7,
          'items': [
            {'name': 'Test', 'price': 100.0, 'quantity': 2},
          ],
          'status': 'closed',
          'revision': 1,
          'grand_total': 200.0,
          'closed_at': closedAt.toIso8601String(),
          'created_at': openedAt.toIso8601String(),
          'opened_at': openedAt.toIso8601String(),
          'payment_method': 'cash',
          'waiter_name': 'Ahmet',
        };

    test('E1. fromMap standart alanları doğru parse eder', () {
      final r = TableOrderHistoryRecord.fromMap(baseMap());
      expect(r.tableNumber, 7);
      expect(r.grandTotal, closeTo(200.0, 0.001));
      expect(r.revision, 1);
      expect(r.paymentMethod, 'cash');
      expect(r.waiterName, 'Ahmet');
      expect(r.items.length, 1);
    });

    test('E2. sessionDuration: openedAt → closedAt = 1sa 47dk', () {
      final r = TableOrderHistoryRecord.fromMap(baseMap());
      final d = r.sessionDuration;
      expect(d.inHours, 1, reason: '1 saat bekleniyor');
      expect(d.inMinutes % 60, 47, reason: '47 dakika bekleniyor');
    });

    test('E3. sessionDuration — openedAt null → createdAt kullanılır', () {
      final map = baseMap()
        ..remove('opened_at')
        ..['closed_at'] =
            DateTime(2026, 4, 7, 12, 30).toIso8601String();
      final r = TableOrderHistoryRecord.fromMap(map);
      expect(r.openedAt, isNull);
      expect(r.sessionDuration.inMinutes, 30);
    });

    test('E4. revision > 1 → revizyon rozeti gösterilmeli eşiği', () {
      final r1 = TableOrderHistoryRecord.fromMap({...baseMap(), 'revision': 1});
      final r2 = TableOrderHistoryRecord.fromMap({...baseMap(), 'revision': 3});
      expect(r1.revision > 1, isFalse, reason: 'revision=1 rozet yok');
      expect(r2.revision > 1, isTrue, reason: 'revision=3 rozet gösterilmeli');
    });

    test('E5. lastEditNote dolu → ekranda gösterilmeli eşiği', () {
      final map = baseMap()..['last_edit_note'] = 'Kuzu şişe ekleme yapıldı.';
      final r = TableOrderHistoryRecord.fromMap(map);
      expect(r.lastEditNote, isNotNull);
      expect(r.lastEditNote!.isNotEmpty, isTrue);
    });

    test('E6. lastEditNote null/yok → ekranda gizlenmeli eşiği', () {
      final r = TableOrderHistoryRecord.fromMap(baseMap());
      final showNote = r.lastEditNote != null && r.lastEditNote!.isNotEmpty;
      expect(showNote, isFalse);
    });

    test('E7. revision string "2" → int 2 olarak parse edilir', () {
      final r = TableOrderHistoryRecord.fromMap({...baseMap(), 'revision': '2'});
      expect(r.revision, 2);
    });

    test('E8. grand_total string → double olarak parse edilir', () {
      final r = TableOrderHistoryRecord.fromMap(
        {...baseMap(), 'grand_total': '350.75'},
      );
      expect(r.grandTotal, closeTo(350.75, 0.001));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // F. GarsonOrderStatus.normalise() — kenar durumlar
  // ══════════════════════════════════════════════════════════════════════════

  group('F. GarsonOrderStatus.normalise() — kapsamlı alias testi', () {
    test('F1. "done" → "sent"', () {
      expect(GarsonOrderStatus.normalise('done'), GarsonOrderStatus.sent);
    });

    test('F2. "kitchen" → "sent"', () {
      expect(GarsonOrderStatus.normalise('kitchen'), GarsonOrderStatus.sent);
    });

    test('F3. "new" → "waiting"', () {
      expect(GarsonOrderStatus.normalise('new'), GarsonOrderStatus.waiting);
    });

    test('F4. büyük harf "DRAFT" → "draft"', () {
      expect(GarsonOrderStatus.normalise('DRAFT'), GarsonOrderStatus.draft);
    });

    test('F5. büyük harf "SENT" → "sent"', () {
      expect(GarsonOrderStatus.normalise('SENT'), GarsonOrderStatus.sent);
    });

    test('F6. boşluklu " sent " → "sent"', () {
      expect(GarsonOrderStatus.normalise(' sent '), GarsonOrderStatus.sent);
    });

    test('F7. tire-bölümlü "pre-paring" → "preparing"', () {
      expect(
        GarsonOrderStatus.normalise('pre-paring'),
        'pre_paring',
        reason: 'Tire alt çizgiye dönüşür (aynı şekilde normalize edilir)',
      );
    });

    test('F8. null → varsayılan "sent"', () {
      expect(GarsonOrderStatus.normalise(null), GarsonOrderStatus.sent);
    });

    test('F9. boş string → varsayılan "sent"', () {
      expect(GarsonOrderStatus.normalise(''), GarsonOrderStatus.sent);
    });

    test('F10. bilinen statüler değişmeden geçer', () {
      for (final s in [
        GarsonOrderStatus.draft,
        GarsonOrderStatus.waiting,
        GarsonOrderStatus.sent,
        GarsonOrderStatus.preparing,
        GarsonOrderStatus.ready,
        GarsonOrderStatus.served,
        GarsonOrderStatus.closed,
        GarsonOrderStatus.completed,
      ]) {
        expect(GarsonOrderStatus.normalise(s), s, reason: "'$s' değişmeden geçmeli");
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // G. GarsonOperationRules delegasyon paritesi
  //    _orderEditPolicy() switchi → GarsonOperationRules.forStatus() ile aynı
  // ══════════════════════════════════════════════════════════════════════════

  group('G. GarsonOperationRules → eski switch paritesi', () {
    // draft/waiting: canEdit=true, canResend=false, isWarning=false, isLocked=false
    test('G1. draft → canEdit:true, canResend:false, showEditWarning:false', () {
      final r = GarsonOperationRules.forStatus('draft');
      expect(r.canEdit, isTrue);
      expect(r.canResend, isFalse);
      expect(r.showEditWarning, isFalse);
    });

    test('G2. waiting → canEdit:true, canResend:false, showEditWarning:false', () {
      final r = GarsonOperationRules.forStatus('waiting');
      expect(r.canEdit, isTrue);
      expect(r.canResend, isFalse);
      expect(r.showEditWarning, isFalse);
    });

    // sent: canEdit=true, canResend=true, isWarning=false
    test('G3. sent → canEdit:true, canResend:true, showEditWarning:false', () {
      final r = GarsonOperationRules.forStatus('sent');
      expect(r.canEdit, isTrue);
      expect(r.canResend, isTrue);
      expect(r.showEditWarning, isFalse);
    });

    // preparing/ready: canEdit=true, canResend=true, isWarning=true
    test('G4. preparing → canEdit:true, canResend:true, showEditWarning:true', () {
      final r = GarsonOperationRules.forStatus('preparing');
      expect(r.canEdit, isTrue);
      expect(r.canResend, isTrue);
      expect(r.showEditWarning, isTrue);
    });

    test('G5. ready → canEdit:true, canResend:true, showEditWarning:true', () {
      final r = GarsonOperationRules.forStatus('ready');
      expect(r.canEdit, isTrue);
      expect(r.canResend, isTrue);
      expect(r.showEditWarning, isTrue);
    });

    // served/closed/completed: canEdit=false → isLocked=true
    for (final s in ['served', 'closed', 'completed']) {
      test('G6. $s → canEdit:FALSE (kilitli)', () {
        final r = GarsonOperationRules.forStatus(s);
        expect(r.canEdit, isFalse, reason: "'$s' düzenlenemez olmalı");
        expect(r.canResend, isFalse);
      });
    }

    test('G7. editNote boş olmayan string içerir (her statü için)', () {
      for (final s in [
        'draft', 'waiting', 'sent', 'preparing', 'ready', 'served', 'closed',
      ]) {
        final r = GarsonOperationRules.forStatus(s);
        expect(
          r.editNote.isNotEmpty,
          isTrue,
          reason: "'$s' için editNote mesajı boş olamaz",
        );
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // H. KitchenPrintPolicy + GarsonOperationRules — entegrasyon senaryoları
  // ══════════════════════════════════════════════════════════════════════════

  group('H. KitchenPrintPolicy + GarsonOperationRules entegrasyon', () {
    test('H1. draft → tam bilet VE editNote mutfak-öncesi mesaj içerir', () {
      expect(KitchenPrintPolicy.shouldDispatchFullTicket('draft'), isTrue);
      final note = GarsonOperationRules.forStatus('draft').editNote;
      // editNote mutfağa iletilmeden önce mesajı içermeli
      expect(note.toLowerCase(), anyOf(contains('iletilmeden'), contains('düzenlenebilir')));
    });

    test('H2. sent → diff VE editNote mutfak tekrar mesajı içerir', () {
      expect(KitchenPrintPolicy.shouldDispatchFullTicket('sent'), isFalse);
      final note = GarsonOperationRules.forStatus('sent').editNote;
      expect(note.toLowerCase(), anyOf(contains('tekrar'), contains('değişiklik')));
    });

    test('H3. preparing → diff VE canEdit:true VE showEditWarning:true', () {
      expect(KitchenPrintPolicy.shouldDispatchFullTicket('preparing'), isFalse);
      final r = GarsonOperationRules.forStatus('preparing');
      expect(r.canEdit, isTrue);
      expect(r.showEditWarning, isTrue);
    });

    test('H4. closed → diff, canEdit:false (ödeme yapılmış masa değiştirilemez)', () {
      expect(KitchenPrintPolicy.shouldDispatchFullTicket('closed'), isFalse);
      final r = GarsonOperationRules.forStatus('closed');
      expect(r.canEdit, isFalse);
    });

    test('H5. her diff statüsünde canResend-ile-shouldDispatch tutarlı', () {
      // canResend=true olan statüler → shouldDispatchFullTicket=false (diff iletimi)
      // canResend=false olan statüler → shouldDispatchFullTicket true ya da false ama edit yok
      for (final s in ['sent', 'preparing', 'ready']) {
        final r = GarsonOperationRules.forStatus(s);
        expect(r.canResend, isTrue, reason: "'$s' için canResend bekleniyor");
        expect(
          KitchenPrintPolicy.shouldDispatchFullTicket(s),
          isFalse,
          reason: "'$s' için diff iletimi bekleniyor",
        );
      }
    });

    test('H6. "new" alias → waiting → tam bilet; canResend=false', () {
      expect(KitchenPrintPolicy.shouldDispatchFullTicket('new'), isTrue);
      expect(GarsonOperationRules.forStatus('new').canResend, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('I. TableLevelPolicy', () {
    // ── canTransfer ──
    group('I1. canTransfer', () {
      test('boş masa → false', () {
        expect(TableLevelPolicy.canTransfer([]), isFalse);
      });

      test('yalnızca aktarılamaz statüler (served/closed) → false', () {
        expect(
          TableLevelPolicy.canTransfer(['served', 'closed']),
          isFalse,
        );
      });

      test('en az bir aktarılabilir statü (sent/preparing) → true', () {
        expect(
          TableLevelPolicy.canTransfer(['sent', 'preparing']),
          isTrue,
        );
      });

      test('karışık: aktarılabilir + aktarılamaz → true', () {
        expect(
          TableLevelPolicy.canTransfer(['closed', 'sent']),
          isTrue,
        );
      });

      test('null statü değerleri yok sayılır, geçerli aktarılabilir → true', () {
        expect(
          TableLevelPolicy.canTransfer([null, 'waiting']),
          isTrue,
        );
      });
    });

    // ── canPay ──
    group('I2. canPay', () {
      test('boş masa → false', () {
        expect(TableLevelPolicy.canPay([]), isFalse);
      });

      test('yalnızca closed → false', () {
        expect(TableLevelPolicy.canPay(['closed']), isFalse);
      });

      test('yalnızca completed → false', () {
        expect(TableLevelPolicy.canPay(['completed']), isFalse);
      });

      test('aktif sipariş (sent) → true', () {
        expect(TableLevelPolicy.canPay(['sent']), isTrue);
      });

      test('karışık: closed + sent → true (en az bir aktif)', () {
        expect(TableLevelPolicy.canPay(['closed', 'sent']), isTrue);
      });
    });

    // ── subtitle sabitler ──
    group('I3. subtitle sabitler boş değil', () {
      test('transferEnabled boş değil', () {
        expect(TableLevelPolicy.transferEnabled, isNotEmpty);
      });
      test('transferBlocked boş değil', () {
        expect(TableLevelPolicy.transferBlocked, isNotEmpty);
      });
      test('payEnabled boş değil', () {
        expect(TableLevelPolicy.payEnabled, isNotEmpty);
      });
      test('payBlocked boş değil', () {
        expect(TableLevelPolicy.payBlocked, isNotEmpty);
      });
      test('splitEnabled boş değil', () {
        expect(TableLevelPolicy.splitEnabled, isNotEmpty);
      });
      test('splitBlocked boş değil', () {
        expect(TableLevelPolicy.splitBlocked, isNotEmpty);
      });
      test('closeEnabled boş değil', () {
        expect(TableLevelPolicy.closeEnabled, isNotEmpty);
      });
      test('closeBlocked boş değil', () {
        expect(TableLevelPolicy.closeBlocked, isNotEmpty);
      });
      test('reprintEnabled boş değil', () {
        expect(TableLevelPolicy.reprintEnabled, isNotEmpty);
      });
      test('reprintBlocked boş değil', () {
        expect(TableLevelPolicy.reprintBlocked, isNotEmpty);
      });
      test('adisyonEnabled boş değil', () {
        expect(TableLevelPolicy.adisyonEnabled, isNotEmpty);
      });
      test('adisyonBlocked boş değil', () {
        expect(TableLevelPolicy.adisyonBlocked, isNotEmpty);
      });
    });
  });

  // ──────────────────────────────────────────────────────────────────────────────
  group('J. KitchenPrintPolicy.canReprint + TableLevelPolicy.canReprint', () {
    group('J1. KitchenPrintPolicy.canReprint — per-order', () {
      test('sent → true', () {
        expect(KitchenPrintPolicy.canReprint('sent'), isTrue);
      });
      test('preparing → true', () {
        expect(KitchenPrintPolicy.canReprint('preparing'), isTrue);
      });
      test('ready → true', () {
        expect(KitchenPrintPolicy.canReprint('ready'), isTrue);
      });
      test('draft → false (henüz mutfağa iletilmedi)', () {
        expect(KitchenPrintPolicy.canReprint('draft'), isFalse);
      });
      test('waiting → false', () {
        expect(KitchenPrintPolicy.canReprint('waiting'), isFalse);
      });
      test('served → false', () {
        expect(KitchenPrintPolicy.canReprint('served'), isFalse);
      });
      test('closed → false', () {
        expect(KitchenPrintPolicy.canReprint('closed'), isFalse);
      });
    });

    group('J2. TableLevelPolicy.canReprint — masa düzeyi', () {
      test('boş masa → false', () {
        expect(TableLevelPolicy.canReprint([]), isFalse);
      });
      test('yalnızca draft/waiting → false (henüz mutfağa girilmedi)', () {
        expect(
          TableLevelPolicy.canReprint(['draft', 'waiting']),
          isFalse,
        );
      });
      test('en az bir sent → true', () {
        expect(TableLevelPolicy.canReprint(['sent']), isTrue);
      });
      test('karışık: draft + sent → true', () {
        expect(
          TableLevelPolicy.canReprint(['draft', 'sent']),
          isTrue,
        );
      });
      test('yalnızca served/closed → false', () {
        expect(
          TableLevelPolicy.canReprint(['served', 'closed']),
          isFalse,
        );
      });
    });
  });

  // ──────────────────────────────────────────────────────────────────────────────
  group('K. OrderPreviewRecord', () {
    Map<String, dynamic> _row({
      String id = 'ord-001',
      int tableNumber = 5,
      List<Map<String, dynamic>>? items,
      String status = 'sent',
      int revision = 1,
      double? grandTotal,
      String? waiterName,
      String? paymentMethod,
      String? lastEditNote,
      Map<String, dynamic>? lastEditSummary,
    }) {
      final itemList = items ??
          [
            {'name': 'Tavuk', 'quantity': 2, 'price': 50.0},
            {'name': 'Çorba', 'quantity': 1, 'price': 30.0},
          ];
      return {
        'id': id,
        'table_number': tableNumber,
        'items': itemList,
        'status': status,
        'revision': revision,
        'grand_total': grandTotal,
        'waiter_name': waiterName,
        'payment_method': paymentMethod,
        'last_edit_note': lastEditNote,
        'last_edit_summary': lastEditSummary,
        'created_at': '2026-01-15T12:00:00.000Z',
      };
    }

    group('K1. fromTableOrder — temel alan eşlemesi', () {
      test('orderId ve tableNumber doğru atanır', () {
        final r = OrderPreviewRecord.fromTableOrder(_row());
        expect(r.orderId, equals('ord-001'));
        expect(r.tableNumber, equals(5));
      });

      test('status ve revision doğru atanır', () {
        final r =
            OrderPreviewRecord.fromTableOrder(_row(status: 'preparing', revision: 3));
        expect(r.status, equals('preparing'));
        expect(r.revision, equals(3));
      });

      test('grand_total null geldiğinde items toplamından hesaplar', () {
        final r = OrderPreviewRecord.fromTableOrder(_row());
        // 2×50 + 1×30 = 130
        expect(r.grandTotal, closeTo(130.0, 0.01));
      });

      test('grand_total verildiğinde kullanılır', () {
        final r = OrderPreviewRecord.fromTableOrder(_row(grandTotal: 99.9));
        expect(r.grandTotal, closeTo(99.9, 0.01));
      });

      test('waiterName ve paymentMethod atanır', () {
        final r = OrderPreviewRecord.fromTableOrder(
          _row(waiterName: 'Ahmet', paymentMethod: 'card'),
        );
        expect(r.waiterName, equals('Ahmet'));
        expect(r.paymentMethod, equals('card'));
      });

      test('createdAt UTC → local dönüştürülür', () {
        final r = OrderPreviewRecord.fromTableOrder(_row());
        expect(r.createdAt.isUtc, isFalse);
      });
    });

    group('K2. shortSummary', () {
      test('2 ürün — "+N daha" eklenmez', () {
        final r = OrderPreviewRecord.fromTableOrder(_row());
        expect(r.shortSummary, contains('Tavuk'));
        expect(r.shortSummary, contains('Çorba'));
        expect(r.shortSummary, isNot(contains('daha')));
      });

      test('3+ ürün — "+N daha" eklenir', () {
        final r = OrderPreviewRecord.fromTableOrder(
          _row(items: [
            {'name': 'A', 'quantity': 1, 'price': 10.0},
            {'name': 'B', 'quantity': 2, 'price': 20.0},
            {'name': 'C', 'quantity': 1, 'price': 15.0},
          ]),
        );
        expect(r.shortSummary, contains('+1 daha'));
      });

      test('boş items → "Ürün yok"', () {
        final r = OrderPreviewRecord.fromTableOrder(_row(items: []));
        expect(r.shortSummary, equals('Ürün yok'));
      });
    });

    group('K3. itemCount', () {
      test('adetlerin toplamını döner', () {
        // 2 + 1 = 3
        final r = OrderPreviewRecord.fromTableOrder(_row());
        expect(r.itemCount, equals(3));
      });

      test('boş liste → 0', () {
        final r = OrderPreviewRecord.fromTableOrder(_row(items: []));
        expect(r.itemCount, equals(0));
      });
    });

    group('K4. addedItems / removedItems — lastEditSummary', () {
      test('added listesi doğru döner', () {
        final r = OrderPreviewRecord.fromTableOrder(
          _row(lastEditSummary: {
            'added': [
              {'name': 'Yeni Ürün', 'quantity': 1}
            ],
            'removed': <Map<String, dynamic>>[],
          }),
        );
        expect(r.addedItems, hasLength(1));
        expect(r.addedItems.first['name'], equals('Yeni Ürün'));
      });

      test('removed listesi doğru döner', () {
        final r = OrderPreviewRecord.fromTableOrder(
          _row(lastEditSummary: {
            'added': <Map<String, dynamic>>[],
            'removed': [
              {'name': 'Silinen Ürün', 'quantity': 2}
            ],
          }),
        );
        expect(r.removedItems, hasLength(1));
        expect(r.removedItems.first['name'], equals('Silinen Ürün'));
      });

      test('lastEditSummary null → boş listeler', () {
        final r = OrderPreviewRecord.fromTableOrder(_row());
        expect(r.addedItems, isEmpty);
        expect(r.removedItems, isEmpty);
      });
    });

    group('K5. fromHistory — TableOrderHistoryRecord eşlemesi', () {
      test('temel alanlar doğru haritalanır', () {
        final hist = TableOrderHistoryRecord(
          id: 'hist-001',
          originalOrderId: 'ord-hist',
          sellerId: _sellerId,
          tableNumber: 7,
          items: const [
            {'name': 'Adana', 'quantity': 1, 'price': 80.0}
          ],
          status: 'closed',
          revision: 2,
          grandTotal: 80.0,
          createdAt: DateTime(2026, 1, 15, 12),
          closedAt: DateTime(2026, 1, 15, 14),
          sessionKey: 'sk1',
        );
        final r = OrderPreviewRecord.fromHistory(hist);
        expect(r.orderId, equals('ord-hist'));
        expect(r.tableNumber, equals(7));
        expect(r.status, equals('closed'));
        expect(r.revision, equals(2));
        expect(r.grandTotal, closeTo(80.0, 0.01));
        expect(r.items, hasLength(1));
      });

      test('closedAt → updatedAt olarak atanır', () {
        final closed = DateTime(2026, 1, 15, 14, 30);
        final hist = TableOrderHistoryRecord(
          id: 'h2',
          originalOrderId: 'o2',
          sellerId: _sellerId,
          tableNumber: 3,
          items: const [],
          status: 'closed',
          revision: 1,
          grandTotal: 0,
          createdAt: DateTime(2026, 1, 15, 12),
          closedAt: closed,
          sessionKey: 'sk2',
        );
        final r = OrderPreviewRecord.fromHistory(hist);
        expect(r.updatedAt, equals(closed));
      });

      test('K5c. closedByName ve paymentNote tarihe taşınır', () {
        final hist = TableOrderHistoryRecord(
          id: 'h3',
          originalOrderId: 'o3',
          sellerId: _sellerId,
          tableNumber: 5,
          items: const [],
          status: 'closed',
          revision: 1,
          grandTotal: 250.0,
          createdAt: DateTime(2026, 1, 15, 12),
          closedAt: DateTime(2026, 1, 15, 14),
          waiterName: 'Ahmet',
          paymentNote: 'split bill',
        );
        final r = OrderPreviewRecord.fromHistory(hist);
        expect(r.closedByName, equals('Ahmet'));
        expect(r.paymentNote, equals('split bill'));
      });

      test('K5d. sessionDuration: openedAt → closedAt farkı doğru', () {
        final opened = DateTime(2026, 1, 15, 12);
        final closed = DateTime(2026, 1, 15, 14);
        final hist = TableOrderHistoryRecord(
          id: 'h4',
          originalOrderId: 'o4',
          sellerId: _sellerId,
          tableNumber: 2,
          items: const [],
          status: 'closed',
          revision: 1,
          grandTotal: 0,
          createdAt: DateTime(2026, 1, 15, 11, 50),
          closedAt: closed,
          openedAt: opened,
        );
        final r = OrderPreviewRecord.fromHistory(hist);
        expect(r.openedAt, equals(opened));
        expect(r.closedAt, equals(closed));
        expect(r.sessionDuration, equals(const Duration(hours: 2)));
      });

      test('K5d2. sessionDuration null → openedAt yoksa createdAt kullanılır', () {
        final created = DateTime(2026, 1, 15, 12);
        final closed = DateTime(2026, 1, 15, 13, 30);
        final hist = TableOrderHistoryRecord(
          id: 'h5',
          originalOrderId: 'o5',
          sellerId: _sellerId,
          tableNumber: 4,
          items: const [],
          status: 'closed',
          revision: 1,
          grandTotal: 0,
          createdAt: created,
          closedAt: closed,
        );
        final r = OrderPreviewRecord.fromHistory(hist);
        expect(r.sessionDuration, equals(const Duration(hours: 1, minutes: 30)));
      });

      test('K5e. TableOrderHistoryRecord.fromMap — paymentNote doğru okunur', () {
        final map = {
          'id': 'h6',
          'original_order_id': 'o6',
          'seller_id': _sellerId,
          'table_number': 9,
          'items': <dynamic>[],
          'status': 'closed',
          'revision': 1,
          'grand_total': 120.0,
          'closed_at': '2026-01-15T14:00:00.000',
          'created_at': '2026-01-15T12:00:00.000',
          'payment_note': 'ayrı ödeme',
        };
        final rec = TableOrderHistoryRecord.fromMap(map);
        expect(rec.paymentNote, equals('ayrı ödeme'));
      });

      test('K5f. TableOrderHistoryRecord.fromMap — waiterId doğru okunur', () {
        final map = {
          'id': 'h7',
          'original_order_id': 'o7',
          'seller_id': _sellerId,
          'table_number': 10,
          'items': <dynamic>[],
          'status': 'closed',
          'revision': 1,
          'grand_total': 200.0,
          'closed_at': '2026-01-15T14:00:00.000',
          'created_at': '2026-01-15T12:00:00.000',
          'waiter_id': 'uid-123',
        };
        final rec = TableOrderHistoryRecord.fromMap(map);
        expect(rec.waiterId, equals('uid-123'));
      });
    });
  });
}
