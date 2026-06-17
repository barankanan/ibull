import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/card_brand_detector.dart';
import '../models/saved_payment_card_models.dart';

class SavedPaymentCardsService {
  SavedPaymentCardsService._();
  static final SavedPaymentCardsService instance = SavedPaymentCardsService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _table = 'saved_payment_cards';

  Exception _schemaException() => Exception(
        "Kayıtlı kart sistemi Supabase'te hazır değil. "
        'SUPABASE_SAVED_PAYMENT_CARDS.sql dosyasını çalıştırın.',
      );

  bool _isSchemaError(Object error) {
    final message = error.toString();
    if (error is PostgrestException) {
      if (error.code == 'PGRST205') return true;
      if (message.contains(_table)) return true;
    }
    return message.contains('does not exist') ||
        message.contains('Could not find');
  }

  Exception _friendlyException(Object error) {
    if (_isSchemaError(error)) return _schemaException();
    if (error is PostgrestException) return Exception(error.message);
    return Exception(error.toString());
  }

  String? _currentUserId() => _supabase.auth.currentUser?.id;

  /// Placeholder until a real payment provider tokenization endpoint is wired.
  Future<CardTokenizationResult?> tokenizeCard(RawCardInput input) async {
    if (!input.isComplete) {
      throw Exception('Kart bilgileri eksik veya geçersiz.');
    }
    // Never log PAN/CVV — only safe metadata in debug.
    if (kDebugMode) {
      debugPrint(
        'SavedPaymentCardsService.tokenizeCard: provider not configured '
        '(brand=${detectCardBrand(input.cardNumber)}, last4=${input.last4})',
      );
    }
    throw const CardTokenizationUnavailable();
  }

  Future<List<SavedPaymentCard>> getMyCards() async {
    final userId = _currentUserId();
    if (userId == null) return [];

    try {
      final rows = await _supabase
          .from(_table)
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((row) => SavedPaymentCard.fromJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList(growable: false);
    } catch (error) {
      throw _friendlyException(error);
    }
  }

  bool isDuplicateCard(
    List<SavedPaymentCard> existing,
    CardTokenizationResult token,
  ) {
    return existing.any(
      (card) =>
          card.provider == token.provider &&
          card.providerCardToken == token.providerCardToken,
    );
  }

  Future<SavedPaymentCard> addSavedCardFromProviderToken(
    CardTokenizationResult token, {
    bool makeDefault = false,
  }) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw Exception('Kart kaydetmek için giriş yapmalısınız.');
    }
    if (token.providerCardToken.trim().isEmpty) {
      throw Exception('Geçersiz ödeme kartı tokenı.');
    }

    final existing = await getMyCards();
    if (isDuplicateCard(existing, token)) {
      throw Exception('Bu kart zaten kayıtlı.');
    }

    final shouldDefault = makeDefault || existing.isEmpty;

    try {
      if (shouldDefault) {
        await _clearDefaultForUser(userId);
      }

      final inserted = await _supabase
          .from(_table)
          .insert(
            SavedPaymentCard(
              id: '',
              userId: userId,
              provider: token.provider,
              providerCardToken: token.providerCardToken,
              cardHolderName: token.cardHolderName,
              cardAlias: token.cardAlias,
              cardBrand: token.cardBrand,
              cardLast4: token.cardLast4,
              expMonth: token.expMonth,
              expYear: token.expYear,
              isDefault: shouldDefault,
            ).toInsertJson(
              userId: userId,
              provider: token.provider,
              providerCardToken: token.providerCardToken,
              cardHolderName: token.cardHolderName,
              cardAlias: token.cardAlias,
              cardBrand: token.cardBrand,
              cardLast4: token.cardLast4,
              expMonth: token.expMonth,
              expYear: token.expYear,
              isDefault: shouldDefault,
            ),
          )
          .select()
          .single();

      return SavedPaymentCard.fromJson(
        Map<String, dynamic>.from(inserted as Map),
      );
    } catch (error) {
      throw _friendlyException(error);
    }
  }

  Future<SavedPaymentCard?> saveCardAfterCheckout({
    required RawCardInput rawCard,
    bool makeDefault = false,
  }) async {
    final token = await tokenizeCard(rawCard);
    if (token == null) return null;
    try {
      return await addSavedCardFromProviderToken(token, makeDefault: makeDefault);
    } on CardTokenizationUnavailable {
      rethrow;
    }
  }

  Future<void> setDefaultCard(String cardId) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw Exception('Varsayılan kart seçmek için giriş yapmalısınız.');
    }

    try {
      await _clearDefaultForUser(userId);
      await _supabase
          .from(_table)
          .update({'is_default': true})
          .eq('id', cardId)
          .eq('user_id', userId)
          .eq('is_active', true);
    } catch (error) {
      throw _friendlyException(error);
    }
  }

  Future<void> deleteCard(String cardId) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw Exception('Kart silmek için giriş yapmalısınız.');
    }

    try {
      final cards = await getMyCards();
      final target = cards.where((c) => c.id == cardId).firstOrNull;
      if (target == null) {
        throw Exception('Kart bulunamadı.');
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from(_table)
          .update({
            'is_active': false,
            'is_default': false,
            'deleted_at': now,
          })
          .eq('id', cardId)
          .eq('user_id', userId);

      if (target.isDefault) {
        final remaining = cards.where((c) => c.id != cardId).toList();
        if (remaining.isNotEmpty) {
          await setDefaultCard(remaining.first.id);
        }
      }
    } catch (error) {
      throw _friendlyException(error);
    }
  }

  Future<void> _clearDefaultForUser(String userId) async {
    await _supabase
        .from(_table)
        .update({'is_default': false})
        .eq('user_id', userId)
        .eq('is_active', true);
  }

  /// Builds order payload map — only masked number, never full PAN.
  Map<String, dynamic> paymentCardPayloadFromSaved(SavedPaymentCard card) {
    return {
      'name': card.displayAlias,
      'number': card.maskedNumber,
      'savedCardId': card.id,
    };
  }

  Map<String, dynamic> paymentCardPayloadFromRaw(RawCardInput input) {
    return {
      'name': (input.alias?.trim().isNotEmpty ?? false)
          ? input.alias!.trim()
          : 'Kartım',
      'number': maskLast4(input.last4),
    };
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
