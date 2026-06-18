enum SellerBrandVerificationStatus {
  none,
  draft,
  submitted,
  needsInfo,
  approved,
  rejected,
}

class SellerBrandVerificationApplication {
  const SellerBrandVerificationApplication({
    required this.id,
    required this.sellerId,
    required this.status,
    required this.fullName,
    required this.brandName,
    required this.companyTitle,
    required this.mersisNo,
    required this.taxNo,
    this.companyFoundedAt,
    this.website,
    required this.email,
    required this.phone,
    this.tradeRegistryNo,
    this.storeNote,
    this.taxPlatePath,
    this.tradeRegistryPath,
    this.brandRegistrationPath,
    this.identityDocumentPath,
    this.acceptedAccuracy,
    this.acceptedReview,
    this.adminNote,
    this.rejectionReason,
    this.storeName,
    this.createdAt,
    this.updatedAt,
    this.reviewedAt,
  });

  final String id;
  final String sellerId;
  final SellerBrandVerificationStatus status;
  final String fullName;
  final String brandName;
  final String companyTitle;
  final String mersisNo;
  final String taxNo;
  final DateTime? companyFoundedAt;
  final String? website;
  final String email;
  final String phone;
  final String? tradeRegistryNo;
  final String? storeNote;
  final String? taxPlatePath;
  final String? tradeRegistryPath;
  final String? brandRegistrationPath;
  final String? identityDocumentPath;
  final bool? acceptedAccuracy;
  final bool? acceptedReview;
  final String? adminNote;
  final String? rejectionReason;
  final String? storeName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;

  bool get isActive =>
      status == SellerBrandVerificationStatus.draft ||
      status == SellerBrandVerificationStatus.submitted ||
      status == SellerBrandVerificationStatus.needsInfo;

  bool get canEdit =>
      status == SellerBrandVerificationStatus.none ||
      status == SellerBrandVerificationStatus.draft ||
      status == SellerBrandVerificationStatus.needsInfo ||
      status == SellerBrandVerificationStatus.rejected;

  bool get canSubmit =>
      status == SellerBrandVerificationStatus.none ||
      status == SellerBrandVerificationStatus.draft ||
      status == SellerBrandVerificationStatus.needsInfo ||
      status == SellerBrandVerificationStatus.rejected;

  String get statusLabel {
    switch (status) {
      case SellerBrandVerificationStatus.none:
        return 'Başvuru yok';
      case SellerBrandVerificationStatus.draft:
        return 'Taslak';
      case SellerBrandVerificationStatus.submitted:
        return 'İncelemede';
      case SellerBrandVerificationStatus.needsInfo:
        return 'Ek bilgi bekleniyor';
      case SellerBrandVerificationStatus.approved:
        return 'Onaylandı';
      case SellerBrandVerificationStatus.rejected:
        return 'Reddedildi';
    }
  }

  factory SellerBrandVerificationApplication.fromMap(
    Map<String, dynamic> map,
  ) {
    return SellerBrandVerificationApplication(
      id: map['id']?.toString() ?? '',
      sellerId: map['seller_id']?.toString() ?? '',
      status: _statusFromDb(map['status']?.toString()),
      fullName: map['full_name']?.toString() ?? '',
      brandName: map['brand_name']?.toString() ?? '',
      companyTitle: map['company_title']?.toString() ?? '',
      mersisNo: map['mersis_no']?.toString() ?? '',
      taxNo: map['tax_no']?.toString() ?? '',
      companyFoundedAt: DateTime.tryParse(
        map['company_founded_at']?.toString() ?? '',
      ),
      website: map['website']?.toString(),
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      tradeRegistryNo: map['trade_registry_no']?.toString(),
      storeNote: map['store_note']?.toString(),
      taxPlatePath: map['tax_plate_path']?.toString(),
      tradeRegistryPath: map['trade_registry_path']?.toString(),
      brandRegistrationPath: map['brand_registration_path']?.toString(),
      identityDocumentPath: map['identity_document_path']?.toString(),
      acceptedAccuracy: map['accepted_accuracy'] == true,
      acceptedReview: map['accepted_review'] == true,
      adminNote: map['admin_note']?.toString(),
      rejectionReason: map['rejection_reason']?.toString(),
      storeName: map['store_name']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      reviewedAt: DateTime.tryParse(map['reviewed_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toInsertMap({required String sellerId}) {
    return {
      'seller_id': sellerId,
      'status': _statusToDb(status == SellerBrandVerificationStatus.none
          ? SellerBrandVerificationStatus.draft
          : status),
      'full_name': fullName.trim(),
      'brand_name': brandName.trim(),
      'company_title': companyTitle.trim(),
      'mersis_no': mersisNo.trim(),
      'tax_no': taxNo.trim(),
      'company_founded_at': companyFoundedAt?.toIso8601String(),
      'website': website?.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'trade_registry_no': tradeRegistryNo?.trim(),
      'store_note': storeNote?.trim(),
      'tax_plate_path': taxPlatePath,
      'trade_registry_path': tradeRegistryPath,
      'brand_registration_path': brandRegistrationPath,
      'identity_document_path': identityDocumentPath,
      'accepted_accuracy': acceptedAccuracy == true,
      'accepted_review': acceptedReview == true,
    };
  }

  static SellerBrandVerificationStatus _statusFromDb(String? raw) {
    switch (raw) {
      case 'draft':
        return SellerBrandVerificationStatus.draft;
      case 'submitted':
        return SellerBrandVerificationStatus.submitted;
      case 'needs_info':
        return SellerBrandVerificationStatus.needsInfo;
      case 'approved':
        return SellerBrandVerificationStatus.approved;
      case 'rejected':
        return SellerBrandVerificationStatus.rejected;
      default:
        return SellerBrandVerificationStatus.none;
    }
  }

  static String _statusToDb(SellerBrandVerificationStatus status) {
    switch (status) {
      case SellerBrandVerificationStatus.none:
      case SellerBrandVerificationStatus.draft:
        return 'draft';
      case SellerBrandVerificationStatus.submitted:
        return 'submitted';
      case SellerBrandVerificationStatus.needsInfo:
        return 'needs_info';
      case SellerBrandVerificationStatus.approved:
        return 'approved';
      case SellerBrandVerificationStatus.rejected:
        return 'rejected';
    }
  }
}

class SellerBrandVerificationFormData {
  const SellerBrandVerificationFormData({
    this.fullName = '',
    this.brandName = '',
    this.companyTitle = '',
    this.mersisNo = '',
    this.taxNo = '',
    this.companyFoundedAt,
    this.website = '',
    this.email = '',
    this.phone = '',
    this.tradeRegistryNo = '',
    this.storeNote = '',
    this.taxPlatePath,
    this.tradeRegistryPath,
    this.brandRegistrationPath,
    this.identityDocumentPath,
    this.acceptedAccuracy = false,
    this.acceptedReview = false,
  });

  final String fullName;
  final String brandName;
  final String companyTitle;
  final String mersisNo;
  final String taxNo;
  final DateTime? companyFoundedAt;
  final String website;
  final String email;
  final String phone;
  final String tradeRegistryNo;
  final String storeNote;
  final String? taxPlatePath;
  final String? tradeRegistryPath;
  final String? brandRegistrationPath;
  final String? identityDocumentPath;
  final bool acceptedAccuracy;
  final bool acceptedReview;

  SellerBrandVerificationFormData copyWith({
    String? fullName,
    String? brandName,
    String? companyTitle,
    String? mersisNo,
    String? taxNo,
    DateTime? companyFoundedAt,
    String? website,
    String? email,
    String? phone,
    String? tradeRegistryNo,
    String? storeNote,
    String? taxPlatePath,
    String? tradeRegistryPath,
    String? brandRegistrationPath,
    String? identityDocumentPath,
    bool? acceptedAccuracy,
    bool? acceptedReview,
  }) {
    return SellerBrandVerificationFormData(
      fullName: fullName ?? this.fullName,
      brandName: brandName ?? this.brandName,
      companyTitle: companyTitle ?? this.companyTitle,
      mersisNo: mersisNo ?? this.mersisNo,
      taxNo: taxNo ?? this.taxNo,
      companyFoundedAt: companyFoundedAt ?? this.companyFoundedAt,
      website: website ?? this.website,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      tradeRegistryNo: tradeRegistryNo ?? this.tradeRegistryNo,
      storeNote: storeNote ?? this.storeNote,
      taxPlatePath: taxPlatePath ?? this.taxPlatePath,
      tradeRegistryPath: tradeRegistryPath ?? this.tradeRegistryPath,
      brandRegistrationPath:
          brandRegistrationPath ?? this.brandRegistrationPath,
      identityDocumentPath: identityDocumentPath ?? this.identityDocumentPath,
      acceptedAccuracy: acceptedAccuracy ?? this.acceptedAccuracy,
      acceptedReview: acceptedReview ?? this.acceptedReview,
    );
  }

  String? validateForSubmit() {
    if (fullName.trim().isEmpty) return 'Ad Soyad zorunludur';
    if (brandName.trim().isEmpty) return 'Marka Adı zorunludur';
    if (companyTitle.trim().isEmpty) return 'Şirket / Firma Ünvanı zorunludur';
    if (mersisNo.trim().isEmpty) return 'MERSİS No zorunludur';
    if (taxNo.trim().isEmpty) return 'Vergi No zorunludur';
    if (companyFoundedAt == null) return 'Şirket kuruluş tarihi zorunludur';
    if (email.trim().isEmpty) return 'E-posta zorunludur';
    if (phone.trim().isEmpty) return 'Telefon zorunludur';
    if (tradeRegistryNo.trim().isEmpty) return 'Ticaret Sicil No zorunludur';
    if ((taxPlatePath ?? '').isEmpty) return 'Vergi levhası yüklenmelidir';
    if ((tradeRegistryPath ?? '').isEmpty) {
      return 'Ticaret sicil / faaliyet belgesi yüklenmelidir';
    }
    if (!acceptedAccuracy) return 'Bilgilerin doğruluğunu kabul etmelisiniz';
    if (!acceptedReview) {
      return 'İBUL doğrulama incelemesini kabul etmelisiniz';
    }
    return null;
  }

  SellerBrandVerificationApplication toApplication({
    required String id,
    required String sellerId,
    required SellerBrandVerificationStatus status,
  }) {
    return SellerBrandVerificationApplication(
      id: id,
      sellerId: sellerId,
      status: status,
      fullName: fullName,
      brandName: brandName,
      companyTitle: companyTitle,
      mersisNo: mersisNo,
      taxNo: taxNo,
      companyFoundedAt: companyFoundedAt,
      website: website.trim().isEmpty ? null : website.trim(),
      email: email,
      phone: phone,
      tradeRegistryNo: tradeRegistryNo,
      storeNote: storeNote.trim().isEmpty ? null : storeNote.trim(),
      taxPlatePath: taxPlatePath,
      tradeRegistryPath: tradeRegistryPath,
      brandRegistrationPath: brandRegistrationPath,
      identityDocumentPath: identityDocumentPath,
      acceptedAccuracy: acceptedAccuracy,
      acceptedReview: acceptedReview,
    );
  }

  factory SellerBrandVerificationFormData.fromApplication(
    SellerBrandVerificationApplication application,
  ) {
    return SellerBrandVerificationFormData(
      fullName: application.fullName,
      brandName: application.brandName,
      companyTitle: application.companyTitle,
      mersisNo: application.mersisNo,
      taxNo: application.taxNo,
      companyFoundedAt: application.companyFoundedAt,
      website: application.website ?? '',
      email: application.email,
      phone: application.phone,
      tradeRegistryNo: application.tradeRegistryNo ?? '',
      storeNote: application.storeNote ?? '',
      taxPlatePath: application.taxPlatePath,
      tradeRegistryPath: application.tradeRegistryPath,
      brandRegistrationPath: application.brandRegistrationPath,
      identityDocumentPath: application.identityDocumentPath,
      acceptedAccuracy: application.acceptedAccuracy == true,
      acceptedReview: application.acceptedReview == true,
    );
  }
}
