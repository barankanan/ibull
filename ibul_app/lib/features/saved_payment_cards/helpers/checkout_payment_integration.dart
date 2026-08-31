import '../models/saved_payment_card_models.dart';
import '../services/saved_payment_cards_service.dart';

class CheckoutPaymentIntegration {
  CheckoutPaymentIntegration._();

  static bool hasValidPayment({
    required List<SavedPaymentCard> savedCards,
    required String? selectedSavedCardId,
    required bool useNewCard,
    required RawCardInput? newCardInput,
    bool? chargeProviderReady,
  }) {
    final ready =
        chargeProviderReady ?? SavedPaymentCardsService.isChargeProviderReady;
    if (!ready) return false;
    if (!useNewCard && selectedSavedCardId != null) {
      return savedCards.any((c) => c.id == selectedSavedCardId);
    }
    return newCardInput?.isComplete ?? false;
  }

  static Map<String, dynamic> resolvePaymentCardPayload({
    required List<SavedPaymentCard> savedCards,
    required String? selectedSavedCardId,
    required bool useNewCard,
    required RawCardInput? newCardInput,
  }) {
    final service = SavedPaymentCardsService.instance;
    if (!useNewCard && selectedSavedCardId != null) {
      final card = savedCards.firstWhere((c) => c.id == selectedSavedCardId);
      return service.paymentCardPayloadFromSaved(card);
    }
    if (newCardInput != null) {
      return service.paymentCardPayloadFromRaw(newCardInput);
    }
    throw Exception('Ödeme kartı seçilmedi.');
  }

  static RawCardInput? rawInputFromControllers({
    required String cardNumber,
    required String expiry,
    required String cvv,
    required String holderName,
    required String alias,
  }) {
    final input = RawCardInput(
      cardNumber: cardNumber,
      expiry: expiry,
      cvv: cvv,
      holderName: holderName,
      alias: alias,
    );
    return input.isComplete ? input : null;
  }
}
