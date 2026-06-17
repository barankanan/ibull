class SavedPaymentCard {
  const SavedPaymentCard({
    required this.id,
    required this.userId,
    required this.provider,
    required this.providerCardToken,
    this.cardHolderName,
    this.cardAlias,
    this.cardBrand,
    required this.cardLast4,
    this.expMonth,
    this.expYear,
    this.isDefault = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String provider;
  final String providerCardToken;
  final String? cardHolderName;
  final String? cardAlias;
  final String? cardBrand;
  final String cardLast4;
  final int? expMonth;
  final int? expYear;
  final bool isDefault;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayAlias =>
      (cardAlias?.trim().isNotEmpty ?? false) ? cardAlias!.trim() : 'Kartım';

  String get maskedNumber => '**** $cardLast4';

  String get expiryLabel {
    if (expMonth == null || expYear == null) return '--/--';
    final year = expYear! >= 100 ? expYear! % 100 : expYear!;
    return '${expMonth!.toString().padLeft(2, '0')}/'
        '${year.toString().padLeft(2, '0')}';
  }

  String get brandLabel {
    final brand = cardBrand?.trim();
    if (brand == null || brand.isEmpty) return 'Bilinmiyor';
    return brand;
  }

  factory SavedPaymentCard.fromJson(Map<String, dynamic> json) {
    return SavedPaymentCard(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      providerCardToken: json['provider_card_token']?.toString() ?? '',
      cardHolderName: json['card_holder_name']?.toString(),
      cardAlias: json['card_alias']?.toString(),
      cardBrand: json['card_brand']?.toString(),
      cardLast4: json['card_last4']?.toString() ?? '0000',
      expMonth: _parseInt(json['exp_month']),
      expYear: _parseInt(json['exp_year']),
      isDefault: json['is_default'] == true,
      isActive: json['is_active'] != false,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toInsertJson({
    required String userId,
    required String provider,
    required String providerCardToken,
    String? cardHolderName,
    String? cardAlias,
    String? cardBrand,
    required String cardLast4,
    int? expMonth,
    int? expYear,
    bool isDefault = false,
  }) {
    return {
      'user_id': userId,
      'provider': provider,
      'provider_card_token': providerCardToken,
      'card_holder_name': cardHolderName,
      'card_alias': cardAlias,
      'card_brand': cardBrand,
      'card_last4': cardLast4,
      'exp_month': expMonth,
      'exp_year': expYear,
      'is_default': isDefault,
      'is_active': true,
    };
  }

  static int? _parseInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

/// Raw card input for tokenization only — never persisted to Supabase.
class RawCardInput {
  const RawCardInput({
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
    required this.holderName,
    this.alias,
  });

  final String cardNumber;
  final String expiry;
  final String cvv;
  final String holderName;
  final String? alias;

  String get digitsOnly =>
      cardNumber.replaceAll(RegExp(r'[^0-9]'), '');

  String get last4 {
    final digits = digitsOnly;
    if (digits.length < 4) return digits.padLeft(4, '0');
    return digits.substring(digits.length - 4);
  }

  (int?, int?) get parsedExpiry {
    final parts = expiry.split('/');
    if (parts.length != 2) return (null, null);
    final month = int.tryParse(parts[0].trim());
    var year = int.tryParse(parts[1].trim());
    if (year != null && year < 100) year += 2000;
    return (month, year);
  }

  bool get isComplete {
    if (digitsOnly.length < 13) return false;
    if (holderName.trim().isEmpty) return false;
    if (cvv.trim().length < 3) return false;
    final (month, year) = parsedExpiry;
    return month != null && month >= 1 && month <= 12 && year != null;
  }
}

class CardTokenizationResult {
  const CardTokenizationResult({
    required this.provider,
    required this.providerCardToken,
    required this.cardLast4,
    this.cardBrand,
    this.expMonth,
    this.expYear,
    this.cardHolderName,
    this.cardAlias,
  });

  final String provider;
  final String providerCardToken;
  final String cardLast4;
  final String? cardBrand;
  final int? expMonth;
  final int? expYear;
  final String? cardHolderName;
  final String? cardAlias;
}

class CardTokenizationUnavailable implements Exception {
  const CardTokenizationUnavailable([
    this.message =
        'Kart kaydetme ödeme altyapısı aktif edildiğinde kullanılabilir.',
  ]);

  final String message;

  @override
  String toString() => message;
}
