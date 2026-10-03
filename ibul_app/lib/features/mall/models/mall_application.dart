/// AVM başvuru durumu. Bilinmeyen veritabanı değeri [unknown] olur.
enum MallApplicationStatus {
  draft,
  pendingReview,
  approved,
  rejected,
  needsInfo,
  cancelled,
  unknown;

  static MallApplicationStatus fromDb(Object? raw) {
    switch (raw?.toString().trim()) {
      case 'draft':
        return MallApplicationStatus.draft;
      case 'pending_review':
        return MallApplicationStatus.pendingReview;
      case 'approved':
        return MallApplicationStatus.approved;
      case 'rejected':
        return MallApplicationStatus.rejected;
      case 'needs_info':
        return MallApplicationStatus.needsInfo;
      case 'cancelled':
        return MallApplicationStatus.cancelled;
      default:
        return MallApplicationStatus.unknown;
    }
  }

  String get dbValue => switch (this) {
        MallApplicationStatus.draft => 'draft',
        MallApplicationStatus.pendingReview => 'pending_review',
        MallApplicationStatus.approved => 'approved',
        MallApplicationStatus.rejected => 'rejected',
        MallApplicationStatus.needsInfo => 'needs_info',
        MallApplicationStatus.cancelled => 'cancelled',
        MallApplicationStatus.unknown => 'unknown',
      };

  bool get isEditable =>
      this == MallApplicationStatus.draft ||
      this == MallApplicationStatus.needsInfo;

  String get label => switch (this) {
        MallApplicationStatus.draft => 'Taslak',
        MallApplicationStatus.pendingReview => 'İncelemede',
        MallApplicationStatus.approved => 'Onaylandı',
        MallApplicationStatus.rejected => 'Reddedildi',
        MallApplicationStatus.needsInfo => 'Ek bilgi gerekli',
        MallApplicationStatus.cancelled => 'İptal edildi',
        MallApplicationStatus.unknown => 'Bilinmeyen durum',
      };
}

class MallApplication {
  const MallApplication({
    required this.id,
    required this.applicantUserId,
    required this.mallName,
    required this.city,
    required this.district,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    required this.authorizedPersonName,
    required this.authorizedPersonTitle,
    required this.documentPaths,
    required this.status,
    this.legalName,
    this.phone,
    this.website,
    this.logoUrl,
    this.coverUrl,
    this.declaredFloorCount,
    this.taxNumber,
    this.taxOffice,
    this.mersisNo,
    this.tradeRegistryNo,
    this.kepAddress,
    this.authorizedPersonPhone,
    this.authorizedPersonEmail,
    this.adminNote,
    this.rejectionReason,
    this.reviewedAt,
    this.createdMallId,
    this.submittedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String applicantUserId;
  final String mallName;
  final String? legalName;
  final String city;
  final String district;
  final String addressText;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? website;
  final String? logoUrl;
  final String? coverUrl;
  final String authorizedPersonName;
  final String authorizedPersonTitle;
  final int? declaredFloorCount;
  final String? taxNumber;
  final String? taxOffice;
  final String? mersisNo;
  final String? tradeRegistryNo;
  final String? kepAddress;
  final String? authorizedPersonPhone;
  final String? authorizedPersonEmail;
  final List<String> documentPaths;
  final MallApplicationStatus status;
  final String? adminNote;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? createdMallId;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static MallApplication fromMap(Map<String, dynamic> map) {
    return MallApplication(
      id: map['id']?.toString() ?? '',
      applicantUserId: map['applicant_user_id']?.toString() ?? '',
      mallName: map['mall_name']?.toString() ?? '',
      legalName: _nullableText(map['legal_name']),
      city: map['city']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      addressText: map['address_text']?.toString() ?? '',
      latitude: _asDouble(map['latitude']) ?? 0,
      longitude: _asDouble(map['longitude']) ?? 0,
      phone: _nullableText(map['phone']),
      website: _nullableText(map['website']),
      logoUrl: _nullableText(map['logo_url']),
      coverUrl: _nullableText(map['cover_url']),
      authorizedPersonName: map['authorized_person_name']?.toString() ?? '',
      authorizedPersonTitle: map['authorized_person_title']?.toString() ?? '',
      declaredFloorCount: _asInt(map['declared_floor_count']),
      taxNumber: _nullableText(map['tax_number']),
      taxOffice: _nullableText(map['tax_office']),
      mersisNo: _nullableText(map['mersis_no']),
      tradeRegistryNo: _nullableText(map['trade_registry_no']),
      kepAddress: _nullableText(map['kep_address']),
      authorizedPersonPhone: _nullableText(map['authorized_person_phone']),
      authorizedPersonEmail: _nullableText(map['authorized_person_email']),
      documentPaths: _stringList(map['document_paths']),
      status: MallApplicationStatus.fromDb(map['status']),
      adminNote: _nullableText(map['admin_note']),
      rejectionReason: _nullableText(map['rejection_reason']),
      reviewedAt: DateTime.tryParse(map['reviewed_at']?.toString() ?? ''),
      createdMallId: _nullableText(map['created_mall_id']),
      submittedAt: DateTime.tryParse(map['submitted_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}

class MallApplicationDraft {
  const MallApplicationDraft({
    required this.mallName,
    required this.city,
    required this.district,
    required this.addressText,
    this.latitude,
    this.longitude,
    required this.authorizedPersonName,
    required this.authorizedPersonTitle,
    this.legalName,
    this.phone,
    this.website,
    this.logoUrl,
    this.coverUrl,
    this.declaredFloorCount,
    this.documentPaths = const [],
    this.taxNumber,
    this.taxOffice,
    this.mersisNo,
    this.tradeRegistryNo,
    this.kepAddress,
    this.authorizedPersonPhone,
    this.authorizedPersonEmail,
  });

  final String mallName;
  final String? legalName;
  final String city;
  final String district;
  final String addressText;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? website;
  final String? logoUrl;
  final String? coverUrl;
  final String authorizedPersonName;
  final String authorizedPersonTitle;
  final int? declaredFloorCount;
  final List<String> documentPaths;
  final String? taxNumber;
  final String? taxOffice;
  final String? mersisNo;
  final String? tradeRegistryNo;
  final String? kepAddress;
  final String? authorizedPersonPhone;
  final String? authorizedPersonEmail;

  /// İçerik kolonları. status ve audit alanları yazılmaz.
  Map<String, dynamic> toContentRow(String applicantUserId) {
    return {
      'applicant_user_id': applicantUserId,
      'mall_name': mallName.trim(),
      'legal_name': _emptyToNull(legalName),
      'city': city.trim(),
      'district': district.trim(),
      'address_text': addressText.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'phone': _emptyToNull(phone),
      'website': _emptyToNull(website),
      'logo_url': _emptyToNull(logoUrl),
      'cover_url': _emptyToNull(coverUrl),
      'authorized_person_name': authorizedPersonName.trim(),
      'authorized_person_title': authorizedPersonTitle.trim(),
      'declared_floor_count': declaredFloorCount,
      'document_paths': documentPaths,
      'tax_number': _digitsOrNull(taxNumber),
      'tax_office': _emptyToNull(taxOffice),
      'mersis_no': _digitsOrNull(mersisNo),
      'trade_registry_no': _emptyToNull(tradeRegistryNo),
      'kep_address': _emptyToNull(kepAddress),
      'authorized_person_phone': _emptyToNull(authorizedPersonPhone),
      'authorized_person_email': _emptyToNull(authorizedPersonEmail),
    };
  }
}

class MallDocumentSlot {
  const MallDocumentSlot(this.kind, this.label);

  final String kind;
  final String label;

  String get dbType => switch (kind) {
        'authority' => 'authorization_letter',
        'gazette' => 'trade_registry_gazette',
        'tax_plate' => 'tax_certificate',
        'activity' => 'activity_certificate',
        'signature' => 'signature_circular',
        'identity' => 'authorized_person_identity',
        _ => 'other',
      };

  static const all = <MallDocumentSlot>[
    MallDocumentSlot('authority', 'AVM Yönetim Yetki Belgesi'),
    MallDocumentSlot('gazette', 'Ticaret Sicil Gazetesi'),
    MallDocumentSlot('tax_plate', 'Vergi Levhası'),
    MallDocumentSlot('activity', 'Faaliyet Belgesi'),
    MallDocumentSlot('signature', 'İmza Sirküleri / Beyannamesi'),
    MallDocumentSlot('identity', 'Yetkili Kimlik Belgesi'),
  ];

  static String? kindOf(String path) {
    final name = path.split('/').last;
    for (final slot in all) {
      if (path.contains('/${slot.kind}/') || name.startsWith('${slot.kind}_')) {
        return slot.kind;
      }
    }
    return null;
  }

  /// DB guard: `{uid}/mall-applications/{applicationId}/{file}` — extra folder yok.
  static bool storagePathAllowed({
    required String userId,
    required String applicationId,
    required String path,
  }) {
    final pattern = RegExp(
      '^${RegExp.escape(userId)}/mall-applications/${RegExp.escape(applicationId)}/[^/]+\$',
    );
    return pattern.hasMatch(path) && !path.contains('..');
  }
}

class MallSubmitIssue {
  const MallSubmitIssue({
    required this.step,
    required this.field,
    required this.message,
  });

  /// Wizard step index: 0 Hesap, 1 İşletme, 2 AVM, 3 Konum, 4 Belgeler.
  final int step;
  final String field;
  final String message;
}

class MallApplicationValidation {
  const MallApplicationValidation._();

  static const int maxDocuments = 12;
  static const int maxDocumentBytes = 10 * 1024 * 1024;

  static List<String> uploadDraftErrors(MallApplicationDraft draft) {
    return draftErrors(draft);
  }

  /// Only what `mall_applications` NOT NULL / check constraints reject.
  static List<String> draftErrors(MallApplicationDraft draft, {String? floorText}) {
    final errors = <String>[];
    final name = draft.mallName.trim();
    if (name.isEmpty || name.length > 160) errors.add('AVM adı zorunlu');
    if (draft.city.trim().isEmpty) errors.add('Şehir zorunlu');
    if (draft.district.trim().isEmpty) errors.add('İlçe zorunlu');
    if (draft.addressText.trim().isEmpty) errors.add('Açık adres zorunlu');
    if (!_validPoint(draft)) errors.add('Haritadan konum seçin');
    if (draft.authorizedPersonName.trim().isEmpty) {
      errors.add('Yetkili adı zorunlu');
    }
    if (draft.authorizedPersonTitle.trim().isEmpty) {
      errors.add('Yetkili görevi zorunlu');
    }
    final floor = floorText == null
        ? (draft.declaredFloorCount == null ? null : _floorRangeError(draft.declaredFloorCount!))
        : floorCountError(floorText);
    if (floor != null) errors.add(floor);
    final tax = (draft.taxNumber ?? '').replaceAll(RegExp(r'\D'), '');
    if (tax.isNotEmpty) {
      final taxError = taxNumberError(tax);
      if (taxError != null) errors.add(taxError);
    }
    final mersis = (draft.mersisNo ?? '').replaceAll(RegExp(r'\D'), '');
    if (mersis.isNotEmpty) {
      final mersisErr = mersisError(mersis);
      if (mersisErr != null) errors.add(mersisErr);
    }
    if (draft.documentPaths.length > maxDocuments) {
      errors.add('En fazla $maxDocuments belge yüklenebilir');
    }
    return errors;
  }

  /// Single submit source of truth: stepper ✓, preview list and the button.
  /// [documentKinds] are the slots the UI shows as uploaded.
  static List<MallSubmitIssue> submitIssues(
    MallApplicationDraft draft, {
    Iterable<String>? documentKinds,
    String? floorText,
  }) {
    final issues = <MallSubmitIssue>[];
    void add(int step, String field, String message) =>
        issues.add(MallSubmitIssue(step: step, field: field, message: message));

    if (draft.authorizedPersonName.trim().isEmpty) {
      add(0, 'Yetkili adı soyadı', 'Yetkili adı zorunlu');
    }
    if (draft.authorizedPersonTitle.trim().isEmpty) {
      add(0, 'Yetkili görevi', 'Yetkili görevi zorunlu');
    }
    if (draft.legalName?.trim().isEmpty ?? true) {
      add(1, 'Şirket / ticari unvan', 'Unvan zorunlu');
    }
    final tax = taxNumberError(draft.taxNumber);
    if (tax != null) add(1, 'Vergi numarası', tax);
    if (draft.taxOffice?.trim().isEmpty ?? true) {
      add(1, 'Vergi dairesi', 'Vergi dairesi zorunlu');
    }
    final mersis = mersisError(draft.mersisNo);
    if (mersis != null) add(1, 'MERSİS numarası', mersis);
    if (draft.tradeRegistryNo?.trim().isEmpty ?? true) {
      add(1, 'Ticaret sicil numarası', 'Ticaret sicil numarası zorunlu');
    }
    final kep = optionalKepError(draft.kepAddress);
    if (kep != null) add(1, 'KEP adresi', kep);
    final name = draft.mallName.trim();
    if (name.isEmpty || name.length > 160) add(2, 'AVM adı', 'AVM adı zorunlu');
    final phone = optionalPhoneError(draft.phone);
    if (phone != null) add(2, 'AVM telefonu', phone);
    final website = optionalWebsiteError(draft.website);
    if (website != null) add(2, 'Web sitesi', website);
    final floor = floorText == null
        ? (draft.declaredFloorCount == null ? null : _floorRangeError(draft.declaredFloorCount!))
        : floorCountError(floorText);
    if (floor != null) add(2, 'Kat sayısı', floor);
    if (draft.city.trim().isEmpty) add(3, 'Şehir', 'Şehir zorunlu');
    if (draft.district.trim().isEmpty) add(3, 'İlçe', 'İlçe zorunlu');
    if (draft.addressText.trim().isEmpty) add(3, 'Açık adres', 'Açık adres zorunlu');
    if (!_validPoint(draft)) add(3, 'Harita konumu', 'Haritadan konum seçin');
    final kinds = (documentKinds ??
            draft.documentPaths.map(MallDocumentSlot.kindOf).whereType<String>())
        .toSet();
    for (final slot in MallDocumentSlot.all) {
      if (!kinds.contains(slot.kind)) {
        add(4, slot.label, '${slot.label} yükleyin');
      }
    }
    if (draft.documentPaths.length > maxDocuments) {
      add(4, 'Belgeler', 'En fazla $maxDocuments belge yüklenebilir');
    }
    return issues;
  }

  static List<String> submitErrors(
    MallApplicationDraft draft, {
    Iterable<String>? documentKinds,
    String? floorText,
  }) {
    return [
      for (final issue in submitIssues(
        draft,
        documentKinds: documentKinds,
        floorText: floorText,
      ))
        issue.message,
    ];
  }

  static bool _validPoint(MallApplicationDraft draft) {
    final lat = draft.latitude;
    final lng = draft.longitude;
    return lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  static String? _floorRangeError(int value) {
    if (value < 1 || value > 40) return 'Kat sayısı 1 ile 40 arasında olmalı';
    return null;
  }

  static String? normalizeWebsite(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.contains(' ') || !value.contains('.')) return value;
    return 'https://$value';
  }

  static int? stepForError(String message) {
    if (message.contains('KEP')) return 1;
    if (message.contains('Yetkili') ||
        message.contains('Şifre') ||
        message.contains('e-posta')) {
      return 0;
    }
    if (message.contains('Vergi') ||
        message.contains('MERSİS') ||
        message.contains('sicil') ||
        message.contains('Unvan')) {
      return 1;
    }
    if (message.contains('AVM adı') ||
        message.contains('Telefon') ||
        message.contains('Web sitesi') ||
        message.contains('Kat sayısı')) {
      return 2;
    }
    if (message.contains('Şehir') ||
        message.contains('İlçe') ||
        message.contains('adres') ||
        message.contains('konum') ||
        message.contains('Haritada')) {
      return 3;
    }
    return 4;
  }

  static String? taxNumberError(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Vergi numarası zorunlu';
    if (digits.length != 10 && digits.length != 11) {
      return 'Vergi numarası 10 veya 11 haneli olmalıdır.';
    }
    return null;
  }

  static String? mersisError(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'MERSİS numarası zorunlu';
    if (digits.length != 16) return 'MERSİS numarası 16 haneli olmalıdır.';
    return null;
  }

  static String? optionalKepError(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'KEP adresi e-posta biçiminde olmalıdır (ör. ornek@hs01.kep.tr).';
    }
    return null;
  }

  /// Boş kat sayısı null'dır. 0 gönderilmez.
  static int? parseDeclaredFloorCount(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static String? floorCountError(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > 40) {
      return 'Kat sayısı 1 ile 40 arasında olmalı';
    }
    return null;
  }

  static String? optionalPhoneError(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) {
      return 'Telefon 10-15 hane olmalı';
    }
    return null;
  }

  static String? optionalWebsiteError(String? raw) {
    final value = normalizeWebsite(raw) ?? '';
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        !uri.host.contains('.')) {
      return 'Geçerli bir web sitesi girin (ör. primall.com).';
    }
    return null;
  }

  static bool documentFileAllowed({
    required String fileName,
    required int byteLength,
  }) {
    final lower = fileName.toLowerCase();
    final allowed = lower.endsWith('.pdf') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
    return allowed && byteLength > 0 && byteLength <= maxDocumentBytes;
  }

  static const int maxImageBytes = 10 * 1024 * 1024;

  static bool imageFileAllowed({
    required String fileName,
    required int byteLength,
  }) {
    final lower = fileName.toLowerCase();
    final allowed = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
    return allowed && byteLength > 0 && byteLength <= maxImageBytes;
  }
}

MallApplication? pickPrimaryMallApplication(List<MallApplication> items) {
  if (items.isEmpty) return null;
  int rank(MallApplicationStatus status) => switch (status) {
        MallApplicationStatus.needsInfo => 0,
        MallApplicationStatus.pendingReview => 1,
        MallApplicationStatus.draft => 2,
        MallApplicationStatus.approved => 3,
        MallApplicationStatus.rejected => 4,
        MallApplicationStatus.cancelled => 5,
        MallApplicationStatus.unknown => 6,
      };
  final sorted = [...items]..sort((a, b) {
      final byStatus = rank(a.status).compareTo(rank(b.status));
      if (byStatus != 0) return byStatus;
      final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  return sorted.first;
}

String? _nullableText(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

String? _emptyToNull(String? raw) {
  final value = raw?.trim() ?? '';
  return value.isEmpty ? null : value;
}

String? _digitsOrNull(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? null : digits;
}

double? _asDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

int? _asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
}
