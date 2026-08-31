/// Adım bazlı validasyon — ihiz_web `_IhizApplyPage` kurallarıyla aynı.
class IhizCourierApplyValidator {
  const IhizCourierApplyValidator._();

  static const licenseOptions = ['A1', 'A2', 'B', 'Diğer'];
  static const motorOptions = ['110 CC ve üzeri', '50 CC', 'Motorum yok'];
  static const criminalRecordOptions = ['Var', 'Yok'];
  static const companyOptions = [
    'Şahıs Şirketi',
    'Limited Şirket',
    'Şirketim yok',
  ];

  static DateTime? parseBirthDate(String value) {
    final normalized = value.replaceAll(' ', '');
    final parts = normalized.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (year < 1900 || year > DateTime.now().year) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static String normalizedIban(String value) {
    return value.replaceAll(' ', '').toUpperCase();
  }

  static Set<String> validateStepOne({
    required String firstName,
    required String lastName,
    required String phone,
    required String tcNumber,
    required String birthDate,
    required String email,
    required String password,
  }) {
    final invalid = <String>{};
    if (firstName.trim().isEmpty) invalid.add('first_name');
    if (lastName.trim().isEmpty) invalid.add('last_name');
    if (phone.trim().length != 11) invalid.add('phone');
    if (tcNumber.trim().length != 11) invalid.add('tc_number');
    if (birthDate.trim().isEmpty || parseBirthDate(birthDate.trim()) == null) {
      invalid.add('birth_date');
    }
    final emailTrim = email.trim();
    if (emailTrim.isEmpty || !emailTrim.contains('@')) invalid.add('email');
    if (password.trim().length < 6) invalid.add('password');
    return invalid;
  }

  static Set<String> validateStepTwo({
    required String? licenseType,
    required String? motorType,
    required String? criminalRecord,
    required String? companyType,
    required String taxNumber,
  }) {
    final invalid = <String>{};
    if ((licenseType ?? '').trim().isEmpty) invalid.add('license_type');
    if ((motorType ?? '').trim().isEmpty) invalid.add('motor_type');
    if ((criminalRecord ?? '').trim().isEmpty) invalid.add('criminal_record');
    if ((companyType ?? '').trim().isEmpty) invalid.add('company_type');
    if (companyType != 'Şirketim yok' && taxNumber.trim().length != 10) {
      invalid.add('tax_number');
    }
    return invalid;
  }

  static Set<String> validateStepThree({
    required String city,
    required String district,
    required String availability,
    required String note,
  }) {
    final invalid = <String>{};
    if (city.trim().isEmpty) invalid.add('city');
    if (district.trim().isEmpty) invalid.add('district');
    if (availability.trim().isEmpty) invalid.add('availability');
    if (note.trim().isEmpty) invalid.add('note');
    return invalid;
  }

  static Set<String> validateStepFour({
    required bool hasDriverFront,
    required bool hasDriverBack,
    required bool hasVehicleRegistration,
  }) {
    final invalid = <String>{};
    if (!hasDriverFront) invalid.add('driver_license_front');
    if (!hasDriverBack) invalid.add('driver_license_back');
    if (!hasVehicleRegistration) invalid.add('vehicle_registration');
    return invalid;
  }

  static Set<String> validateStepFive({
    required String paymentAccountHolder,
    required String paymentBankName,
    required String paymentIban,
  }) {
    final invalid = <String>{};
    if (paymentAccountHolder.trim().isEmpty) {
      invalid.add('payment_account_holder');
    }
    if (paymentBankName.trim().isEmpty) invalid.add('payment_bank_name');
    final iban = normalizedIban(paymentIban.trim());
    if (!RegExp(r'^TR[0-9]{24}$').hasMatch(iban)) {
      invalid.add('payment_iban');
    }
    return invalid;
  }
}
