/// Admin mağaza başvurusunda kurumsal kimlik alanlarını başvuru kaydından üretir.
/// KEP asla normal e-posta ile doldurulmaz.
class StoreApplicationIdentity {
  const StoreApplicationIdentity._();

  static const _empty = '-';

  static String displayValue(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? _empty : text;
  }

  static String legalTitle(Map<String, dynamic> application) {
    return displayValue(application['business_name']);
  }

  static String taxNumber(Map<String, dynamic> application) {
    return displayValue(
      application['tax_office_number'] ??
          application['tax_number'] ??
          application['vergi_no'],
    );
  }

  static String mersisNumber(Map<String, dynamic> application) {
    return displayValue(
      application['mersis_no'] ??
          application['mersis_number'] ??
          application['mersis'],
    );
  }

  /// KEP yalnızca gerçek KEP formatındaysa gösterilir (`*@*.kep.tr`).
  static String kepAddress(Map<String, dynamic> application) {
    final raw = displayValue(
      application['kep_address'] ??
          application['kep_email'] ??
          application['kep'],
    );
    if (raw == _empty) return _empty;
    return looksLikeKepAddress(raw) ? raw : _empty;
  }

  static String email(Map<String, dynamic> application) {
    return displayValue(application['email'] ?? application['user_email']);
  }

  static String website(Map<String, dynamic> application) {
    return displayValue(application['website'] ?? application['web_site']);
  }

  static String phone(Map<String, dynamic> application) {
    return displayValue(application['phone'] ?? application['user_phone']);
  }

  static String contactName(Map<String, dynamic> application) {
    return displayValue(
      application['contact_name'] ??
          application['full_name'] ??
          application['user_name'],
    );
  }

  static String iban(Map<String, dynamic> application) {
    return displayValue(application['iban']);
  }

  static String bankName(Map<String, dynamic> application) {
    return displayValue(application['bank_name']);
  }

  static String accountHolder(Map<String, dynamic> application) {
    return displayValue(application['account_holder']);
  }

  static String businessType(Map<String, dynamic> application) {
    return displayValue(application['business_type']);
  }

  static bool looksLikeKepAddress(String value) {
    final lower = value.trim().toLowerCase();
    final at = lower.indexOf('@');
    if (at <= 0 || at == lower.length - 1) return false;
    final domain = lower.substring(at + 1);
    return domain == 'kep.tr' || domain.endsWith('.kep.tr');
  }
}
