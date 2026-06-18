import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/seller_brand_verification_models.dart';

class SellerBrandVerificationService {
  SellerBrandVerificationService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static const String _table = 'store_brand_verification_applications';

  SupabaseClient? get _db {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _requireDb() {
    if (_db == null) {
      throw Exception('Supabase bağlantısı hazır değil');
    }
  }

  Future<bool> isSellerBrandVerified(String sellerId) async {
    final db = _db;
    if (db == null) return false;
    final normalized = sellerId.trim();
    if (normalized.isEmpty) return false;
    try {
      final row = await db
          .from('stores')
          .select('is_brand_verified')
          .eq('seller_id', normalized)
          .maybeSingle();
      return row?['is_brand_verified'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<SellerBrandVerificationApplication?> fetchLatestForSeller(
    String sellerId,
  ) async {
    final db = _db;
    if (db == null) return null;
    final normalized = sellerId.trim();
    if (normalized.isEmpty) return null;
    try {
      final row = await db
          .from(_table)
          .select()
          .eq('seller_id', normalized)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return SellerBrandVerificationApplication.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<SellerBrandVerificationApplication>> fetchAllForAdmin() async {
    final db = _db;
    if (db == null) {
      throw Exception('Supabase bağlantısı hazır değil');
    }
    try {
      final rows = await db
          .from(_table)
          .select()
          .order('created_at', ascending: false);
      return rows
          .map(
            (row) => SellerBrandVerificationApplication.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (e) {
      throw Exception('Marka onay başvuruları alınamadı: $e');
    }
  }

  Future<String> uploadDocument({
    required String sellerId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _requireDb();
    final db = _db!;
    final normalized = sellerId.trim();
    if (normalized.isEmpty) {
      throw Exception('Satıcı kimliği bulunamadı');
    }
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '$normalized/brand-verification/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await db.storage.from('seller-documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  Future<String> signedDocumentUrl(String path) {
    _requireDb();
    return _db!.storage.from('seller-documents').createSignedUrl(path, 3600);
  }

  Future<SellerBrandVerificationApplication> saveDraft({
    required String sellerId,
    required SellerBrandVerificationFormData form,
    String? existingId,
  }) async {
    _requireDb();
    final db = _db!;
    final normalized = sellerId.trim();
    if (normalized.isEmpty) {
      throw Exception('Satıcı kimliği bulunamadı');
    }

    final application = form.toApplication(
      id: existingId ?? '',
      sellerId: normalized,
      status: SellerBrandVerificationStatus.draft,
    );
    final payload = application.toInsertMap(sellerId: normalized)
      ..['status'] = 'draft';

    if (existingId != null && existingId.isNotEmpty) {
      final updated = await db
          .from(_table)
          .update(payload)
          .eq('id', existingId)
          .eq('seller_id', normalized)
          .select()
          .single();
      return SellerBrandVerificationApplication.fromMap(updated);
    }

    final hasActive = await _hasActiveApplication(normalized);
    if (hasActive) {
      throw Exception('Zaten aktif bir marka onay başvurunuz var');
    }

    final inserted = await db.from(_table).insert(payload).select().single();
    return SellerBrandVerificationApplication.fromMap(inserted);
  }

  Future<SellerBrandVerificationApplication> submitApplication({
    required String sellerId,
    required SellerBrandVerificationFormData form,
    String? existingId,
  }) async {
    _requireDb();
    final db = _db!;
    final validationError = form.validateForSubmit();
    if (validationError != null) {
      throw Exception(validationError);
    }

    final normalized = sellerId.trim();
    if (normalized.isEmpty) {
      throw Exception('Satıcı kimliği bulunamadı');
    }

    if (existingId == null || existingId.isEmpty) {
      final hasActive = await _hasActiveApplication(normalized);
      if (hasActive) {
        throw Exception('Zaten aktif bir marka onay başvurunuz var');
      }
    }

    final application = form.toApplication(
      id: existingId ?? '',
      sellerId: normalized,
      status: SellerBrandVerificationStatus.submitted,
    );
    final payload = application.toInsertMap(sellerId: normalized)
      ..['status'] = 'submitted'
      ..['submitted_at'] = DateTime.now().toIso8601String();

    if (existingId != null && existingId.isNotEmpty) {
      final updated = await db
          .from(_table)
          .update(payload)
          .eq('id', existingId)
          .eq('seller_id', normalized)
          .select()
          .single();
      return SellerBrandVerificationApplication.fromMap(updated);
    }

    final inserted = await db.from(_table).insert(payload).select().single();
    return SellerBrandVerificationApplication.fromMap(inserted);
  }

  Future<bool> _hasActiveApplication(String sellerId) async {
    final latest = await fetchLatestForSeller(sellerId);
    return latest?.isActive == true;
  }

  Future<void> approveApplication({
    required String applicationId,
    String? adminNote,
  }) async {
    _requireDb();
    final db = _db!;
    final row = await db
        .from(_table)
        .select('seller_id')
        .eq('id', applicationId)
        .maybeSingle();
    if (row == null) throw Exception('Başvuru bulunamadı');
    final sellerId = row['seller_id']?.toString() ?? '';
    if (sellerId.isEmpty) throw Exception('Satıcı bilgisi eksik');

    await db.from(_table).update({
      'status': 'approved',
      'admin_note': adminNote?.trim(),
      'rejection_reason': null,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', applicationId);

    await db.from('stores').update({
      'is_brand_verified': true,
    }).eq('seller_id', sellerId);
  }

  Future<void> rejectApplication({
    required String applicationId,
    required String reason,
    String? adminNote,
  }) async {
    _requireDb();
    final db = _db!;
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw Exception('Red gerekçesi zorunludur');
    }
    await db.from(_table).update({
      'status': 'rejected',
      'rejection_reason': trimmed,
      'admin_note': adminNote?.trim(),
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', applicationId);
  }

  Future<void> requestMoreInfo({
    required String applicationId,
    required String adminNote,
  }) async {
    _requireDb();
    final db = _db!;
    final trimmed = adminNote.trim();
    if (trimmed.isEmpty) {
      throw Exception('Ek bilgi notu zorunludur');
    }
    await db.from(_table).update({
      'status': 'needs_info',
      'admin_note': trimmed,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', applicationId);
  }
}
