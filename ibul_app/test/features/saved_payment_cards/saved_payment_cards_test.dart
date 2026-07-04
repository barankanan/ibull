import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/features/saved_payment_cards/helpers/card_brand_detector.dart';
import 'package:ibul_app/features/saved_payment_cards/helpers/checkout_payment_integration.dart';
import 'package:ibul_app/features/saved_payment_cards/models/saved_payment_card_models.dart';
import 'package:ibul_app/features/saved_payment_cards/services/saved_payment_cards_service.dart';
import 'package:ibul_app/features/saved_payment_cards/widgets/checkout_save_card_checkbox.dart';
import 'package:ibul_app/features/saved_payment_cards/widgets/saved_payment_card_tile.dart';
import 'package:ibul_app/features/saved_payment_cards/widgets/saved_payment_cards_empty_state.dart';
import 'package:ibul_app/widgets/account_sidebar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  group('SavedPaymentCard model', () {
    test('maskedNumber uses last4 only', () {
      const card = SavedPaymentCard(
        id: '1',
        userId: 'u1',
        provider: 'pending',
        providerCardToken: 'tok_abc',
        cardLast4: '4242',
        cardAlias: 'Kişisel Kartım',
        cardBrand: 'Visa',
        expMonth: 8,
        expYear: 2028,
        isDefault: true,
      );

      expect(card.maskedNumber, '**** 4242');
      expect(card.expiryLabel, '08/28');
      expect(card.displayAlias, 'Kişisel Kartım');
    });

    test('fromJson parses list payload without provider_card_token', () {
      final card = SavedPaymentCard.fromJson({
        'id': 'card-1',
        'user_id': 'u1',
        'provider': 'pending',
        'card_alias': 'Kişisel Kartım',
        'card_brand': 'Visa',
        'card_last4': '4242',
        'exp_month': 8,
        'exp_year': 2028,
        'is_default': true,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(card.providerCardToken, isNull);
      expect(card.maskedNumber, '**** 4242');
      expect(card.displayAlias, 'Kişisel Kartım');
    });
  });

  group('SavedPaymentCardsService list select', () {
    test('list select columns exclude provider_card_token', () {
      expect(
        kSavedPaymentCardListSelectColumns.contains('provider_card_token'),
        isFalse,
      );
      expect(kSavedPaymentCardListSelectColumns, contains('card_last4'));
      expect(kSavedPaymentCardListSelectColumns, contains('is_default'));
    });
  });

  group('card brand detector', () {
    test('detects visa and mastercard', () {
      expect(detectCardBrand('4111111111111111'), 'Visa');
      expect(detectCardBrand('5500000000000004'), 'Mastercard');
      expect(maskLast4('1234'), '**** 1234');
    });
  });

  group('checkout payment integration', () {
    test('raw card payload never includes full pan', () {
      const input = RawCardInput(
        cardNumber: '4111111111111111',
        expiry: '08/28',
        cvv: '123',
        holderName: 'Test User',
        alias: 'Kartım',
      );

      final payload = SavedPaymentCardsService.instance
          .paymentCardPayloadFromRaw(input);
      expect(payload['number'], '**** 1111');
      expect(payload['name'], 'Kartım');
      expect(payload.containsKey('cardNumber'), isFalse);
      expect(payload.containsKey('cvv'), isFalse);
    });

    test('hasValidPayment accepts saved card selection', () {
      const card = SavedPaymentCard(
        id: 'card-1',
        userId: 'u1',
        provider: 'pending',
        providerCardToken: 'tok',
        cardLast4: '1111',
      );

      expect(
        CheckoutPaymentIntegration.hasValidPayment(
          savedCards: const [card],
          selectedSavedCardId: 'card-1',
          useNewCard: false,
          newCardInput: null,
        ),
        isTrue,
      );
    });
  });

  group('tokenization fallback', () {
    test('tokenizeCard does not fake success', () async {
      const input = RawCardInput(
        cardNumber: '4111111111111111',
        expiry: '08/28',
        cvv: '123',
        holderName: 'Test User',
      );

      expect(
        () => SavedPaymentCardsService.instance.tokenizeCard(input),
        throwsA(isA<CardTokenizationUnavailable>()),
      );
    });
  });

  testWidgets('empty state renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SavedPaymentCardsEmptyState(onAddCard: () {})),
      ),
    );

    expect(find.text('Kayıtlı kartın yok'), findsOneWidget);
    expect(find.text('Kart Ekle'), findsOneWidget);
  });

  testWidgets('default card badge visible on tile', (tester) async {
    const card = SavedPaymentCard(
      id: '1',
      userId: 'u1',
      provider: 'pending',
      providerCardToken: 'tok',
      cardLast4: '4242',
      cardAlias: 'Kişisel Kartım',
      cardBrand: 'Visa',
      isDefault: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedPaymentCardTile(
            card: card,
            onSetDefault: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Varsayılan'), findsOneWidget);
    expect(find.text('**** 4242'), findsOneWidget);
  });

  testWidgets('delete confirmation dialog copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  showDeleteSavedCardDialog(context, onConfirm: () {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Kart silinsin mi?'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);
  });

  testWidgets('checkout save card checkbox visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckoutSaveCardCheckbox(value: true, onChanged: (_) {}),
        ),
      ),
    );

    expect(
      find.text('Kartımı sonraki alışverişlerim için kaydet'),
      findsOneWidget,
    );
    expect(find.textContaining('CVV kaydedilmez'), findsOneWidget);
  });

  testWidgets('account sidebar navigates Kayıtlı Kartlarım entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 280,
                height: 1200,
                child: AccountSidebar(activePage: 'Adreslerim'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kayıtlı Kartlarım'), findsOneWidget);

    await tester.ensureVisible(find.text('Kayıtlı Kartlarım'));
    await tester.tap(find.text('Kayıtlı Kartlarım'));
    await tester.pumpAndSettle();

    expect(find.text('Kartlarım'), findsWidgets);
    expect(find.textContaining('Güvenli ödeme'), findsOneWidget);
  });
}
