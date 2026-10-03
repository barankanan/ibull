import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/store/store_media_service.dart';
import '../auth/mall_auth_session.dart';
import '../models/mall_application.dart';

String draftWriteMessage(Object error) {
  if (error is MallApplicationException) return error.message;
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final message = error.message;
    final details = error.details?.toString() ?? '';
    final hint = error.hint ?? '';
    debugPrint(
      '[MALL][DRAFT] code=$code message=$message details=$details hint=$hint',
    );
    if (code == '23505') {
      return 'Bu AVM adı ile açık bir başvurunuz zaten var.';
    }
    if (code == '23503') {
      return 'Hesap profili bulunamadı. AVM girişinden tekrar deneyin.';
    }
    if (message.contains('tax_number') || details.contains('tax_number')) {
      return 'Vergi numarası 10 veya 11 haneli olmalıdır.';
    }
    if (message.contains('mersis') || details.contains('mersis')) {
      return 'MERSİS numarası 16 haneli olmalıdır.';
    }
    if (message.contains('mall_application_document_path') || code == '22023') {
      return 'Belge yolu başvuru kaydına yazılamadı.';
    }
    if (code == '42501') {
      return 'Başvuru kaydı için yetki doğrulanamadı.';
    }
    if (code == '42703') {
      return 'Başvuru kaydı şu an yazılamıyor. Lütfen daha sonra tekrar deneyin.';
    }
    return 'Başvuru kaydı yazılamadı.';
  }
  debugPrint('[MALL][DRAFT] $error');
  return 'Başvuru kaydı yazılamadı.';
}

void _rejectInvalidCommercialFields(MallApplicationDraft draft) {
  final tax = (draft.taxNumber ?? '').replaceAll(RegExp(r'\D'), '');
  if (tax.isNotEmpty && !RegExp(r'^[0-9]{10,11}$').hasMatch(tax)) {
    throw MallApplicationException('Vergi numarası 10 veya 11 haneli olmalıdır.');
  }
  final mersis = (draft.mersisNo ?? '').replaceAll(RegExp(r'\D'), '');
  if (mersis.isNotEmpty && !RegExp(r'^[0-9]{16}$').hasMatch(mersis)) {
    throw MallApplicationException('MERSİS numarası 16 haneli olmalıdır.');
  }
}

void _logDraftPayload(Map<String, dynamic> row) {
  final summary = row.entries.map((entry) {
    final value = entry.value;
    if (value == null) return '${entry.key}=null';
    if (value is List) return '${entry.key}=list:${value.length}';
    if (value is num) return '${entry.key}=num';
    return '${entry.key}=len:${value.toString().length}';
  }).join(' ');
  debugPrint('[MALL][DRAFT] payload $summary');
}

class MallApplicationException implements Exception {
  MallApplicationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class MallApplicationRepository {
  MallApplicationRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static const table = 'mall_applications';
  static const bucket = 'seller-documents';
  static const mediaBucket = 'mall-media';

  SupabaseClient get _db => _client ?? MallAuthSession.instance.client;

  String get _userId {
    final id = _db.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw MallApplicationException('Başvuru için giriş yapın');
    }
    return id;
  }

  Future<List<MallApplication>> getMyApplications() async {
    final userId = _userId;
    final rows = await _db
        .from(table)
        .select()
        .eq('applicant_user_id', userId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((row) => MallApplication.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<MallApplication?> getApplication(String id) async {
    final userId = _userId;
    final row = await _db
        .from(table)
        .select()
        .eq('id', id)
        .eq('applicant_user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return MallApplication.fromMap(Map<String, dynamic>.from(row));
  }

  Future<MallApplication> createDraft(MallApplicationDraft draft) async {
    final userId = _userId;
    debugPrint(
      '[MALL][DRAFT] user=$userId applicationId=null '
      'floor=${draft.declaredFloorCount} '
      'payloadFloor=${draft.toContentRow(userId)['declared_floor_count']}',
    );
    final errors = MallApplicationValidation.uploadDraftErrors(draft);
    if (errors.isNotEmpty) {
      throw MallApplicationException(errors.first);
    }
    _rejectInvalidCommercialFields(draft);
    final payload = draft.toContentRow(userId)..['status'] = 'draft';
    _logDraftPayload(payload);
    try {
      final row = await _db
          .from(table)
          .insert(payload)
          .select()
          .single();
      final created = MallApplication.fromMap(Map<String, dynamic>.from(row));
      debugPrint('[MALL][DRAFT_SAVE] mode=create applicationId=${created.id} ok');
      return created;
    } catch (error) {
      _logDraftSave('create', null, error);
      throw MallApplicationException(draftWriteMessage(error));
    }
  }

  static void _logDraftSave(String mode, String? applicationId, Object error) {
    if (error is PostgrestException) {
      debugPrint(
        '[MALL][DRAFT_SAVE] mode=$mode applicationId=$applicationId '
        'code=${error.code} message=${error.message} '
        'details=${error.details} hint=${error.hint}',
      );
      return;
    }
    debugPrint(
      '[MALL][DRAFT_SAVE] mode=$mode applicationId=$applicationId '
      'error=${error.runtimeType} $error',
    );
  }

  Future<MallApplication> updateDraft({
    required String applicationId,
    required MallApplicationDraft draft,
  }) async {
    final userId = _userId;
    final errors = MallApplicationValidation.uploadDraftErrors(draft);
    if (errors.isNotEmpty) {
      throw MallApplicationException(errors.first);
    }
    _rejectInvalidCommercialFields(draft);
    final content = draft.toContentRow(userId);
    content.remove('applicant_user_id');
    debugPrint(
      '[MALL][DRAFT] update applicationId=$applicationId '
      'documents=${draft.documentPaths.length}',
    );
    try {
      final row = await _db
          .from(table)
          .update(content)
          .eq('id', applicationId)
          .eq('applicant_user_id', userId)
          .select()
          .single();
      debugPrint('[MALL][DRAFT_SAVE] mode=update applicationId=$applicationId ok');
      return MallApplication.fromMap(Map<String, dynamic>.from(row));
    } catch (error) {
      _logDraftSave('update', applicationId, error);
      throw MallApplicationException(draftWriteMessage(error));
    }
  }

  Future<String> uploadDocument({
    required String applicationId,
    required String fileName,
    required Uint8List bytes,
    String kind = 'authority',
  }) async {
    final userId = _userId;
    if (!MallApplicationValidation.documentFileAllowed(
      fileName: fileName,
      byteLength: bytes.length,
    )) {
      throw MallApplicationException(
        'Belge PDF, JPG veya PNG olmalı ve 10 MB altında kalmalı',
      );
    }
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final folder = kind.replaceAll(RegExp(r'[^a-z0-9_-]'), '');
    final path =
        '$userId/mall-applications/$applicationId/${folder}_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    debugPrint(
      '[MALL][DOCUMENT] user=$userId applicationId=$applicationId '
      'bucket=$bucket path=$path bytes=${bytes.length}',
    );
    if (!MallDocumentSlot.storagePathAllowed(
      userId: userId,
      applicationId: applicationId,
      path: path,
    )) {
      throw MallApplicationException('Belge yolu oluşturulamadı.');
    }
    try {
      await _db.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(fileName),
              upsert: false,
            ),
          );
    } catch (error) {
      _logSupabase('DOCUMENT', error);
      throw _storageUiError(error);
    }
    debugPrint('[MALL][DOCUMENT] storage ok path=$path');
    return path;
  }

  Future<void> recordDocument({
    required String applicationId,
    required String kind,
    required String path,
    required String fileName,
    required int sizeBytes,
  }) async {
    final type = MallDocumentSlot.all
        .where((slot) => slot.kind == kind)
        .map((slot) => slot.dbType)
        .firstOrNull;
    try {
      await _db.from('mall_application_documents').insert({
        'application_id': applicationId,
        'document_type': type ?? 'other',
        'storage_path': path,
        'original_filename': fileName,
        'size_bytes': sizeBytes,
      });
      debugPrint(
        '[MALL][DOCUMENT] row applicationId=$applicationId type=${type ?? 'other'} path=$path',
      );
    } catch (error) {
      _logSupabase('DOCUMENT_ROW', error);
      throw MallApplicationException(draftWriteMessage(error));
    }
  }

  Future<void> removeDocument(String path) async {
    _userId;
    await _db.storage.from(bucket).remove([path]);
  }

  Future<String> signedDocumentUrl(String path) {
    _userId;
    return _db.storage.from(bucket).createSignedUrl(path, 3600);
  }

  Future<String> uploadLogo({
    required String applicationId,
    required String fileName,
    required Uint8List bytes,
    String? previousUrl,
  }) {
    return _replacePublicImage(
      applicationId: applicationId,
      kind: 'logo',
      column: 'logo_url',
      fileName: fileName,
      bytes: bytes,
      previousUrl: previousUrl,
    );
  }

  Future<String> uploadCover({
    required String applicationId,
    required String fileName,
    required Uint8List bytes,
    String? previousUrl,
  }) {
    return _replacePublicImage(
      applicationId: applicationId,
      kind: 'cover',
      column: 'cover_url',
      fileName: fileName,
      bytes: bytes,
      previousUrl: previousUrl,
    );
  }

  Future<void> removeLogo({
    required String applicationId,
    String? previousUrl,
  }) {
    return _clearPublicImage(
      applicationId: applicationId,
      column: 'logo_url',
      previousUrl: previousUrl,
    );
  }

  Future<void> removeCover({
    required String applicationId,
    String? previousUrl,
  }) {
    return _clearPublicImage(
      applicationId: applicationId,
      column: 'cover_url',
      previousUrl: previousUrl,
    );
  }

  Future<String> _replacePublicImage({
    required String applicationId,
    required String kind,
    required String column,
    required String fileName,
    required Uint8List bytes,
    String? previousUrl,
  }) async {
    final userId = _userId;
    if (!MallApplicationValidation.imageFileAllowed(
      fileName: fileName,
      byteLength: bytes.length,
    )) {
      throw MallApplicationException(
        'Logo ve kapak JPG, PNG veya WEBP olmalı ve 10 MB altında kalmalı',
      );
    }
    final optimized = await _compressImage(bytes);
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '$userId/mall-applications/$applicationId/$kind/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final tag = kind == 'logo' ? 'LOGO' : 'COVER';
    debugPrint(
      '[MALL][$tag] user=$userId applicationId=$applicationId '
      'bucket=$mediaBucket path=$path bytes=${optimized.length}',
    );
    if (!path.startsWith('$userId/mall-applications/$applicationId/$kind/')) {
      throw MallApplicationException('Görsel yolu oluşturulamadı.');
    }
    try {
      await _db.storage.from(mediaBucket).uploadBinary(
            path,
            optimized,
            fileOptions: FileOptions(
              contentType: _imageContentType(optimized, fileName),
              upsert: false,
            ),
          );
    } catch (error) {
      _logSupabase(tag, error);
      throw _storageUiError(error);
    }
    debugPrint('[MALL][$tag] storage ok path=$path');
    final url = _db.storage.from(mediaBucket).getPublicUrl(path);
    try {
      await _db
          .from(table)
          .update({column: url})
          .eq('id', applicationId)
          .eq('applicant_user_id', userId);
    } catch (error) {
      _logSupabase(tag, error);
      await _db.storage.from(mediaBucket).remove([path]);
      throw MallApplicationException(
        'Dosya yüklendi ancak başvuru kaydı güncellenemedi.',
      );
    }
    debugPrint('[MALL][$tag] db column=$column updated');
    final oldPath = _ownedMediaPath(previousUrl, userId);
    if (oldPath != null && oldPath != path) {
      try {
        await _db.storage.from(mediaBucket).remove([oldPath]);
      } catch (error) {
        debugPrint('[mall-media] old file remove failed: $error');
      }
    }
    return url;
  }

  Future<void> _clearPublicImage({
    required String applicationId,
    required String column,
    String? previousUrl,
  }) async {
    final userId = _userId;
    await _db
        .from(table)
        .update({column: null})
        .eq('id', applicationId)
        .eq('applicant_user_id', userId);
    final oldPath = _ownedMediaPath(previousUrl, userId);
    if (oldPath == null) return;
    try {
      await _db.storage.from(mediaBucket).remove([oldPath]);
    } catch (error) {
      debugPrint('[mall-media] remove failed: $error');
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    final media = StoreMediaService(
      supabase: _db,
      currentUserIdResolver: () => _db.auth.currentUser?.id,
    );
    try {
      return await media.compressBytes(bytes).timeout(
            StoreMediaService.compressTimeout,
            onTimeout: () => bytes,
          );
    } catch (error) {
      debugPrint('[MALL][MEDIA] compress failed, original bytes kept: $error');
      return bytes;
    }
  }

  static void _logSupabase(String tag, Object error) {
    if (error is StorageException) {
      debugPrint(
        '[MALL][$tag] storage code=${error.statusCode} message=${error.message}',
      );
      return;
    }
    if (error is PostgrestException) {
      debugPrint('[MALL][$tag] db code=${error.code} message=${error.message}');
      return;
    }
    debugPrint('[MALL][$tag] $error');
  }

  static MallApplicationException _storageUiError(Object error) {
    if (error is StorageException) {
      final code = error.statusCode?.toString() ?? '';
      if (code == '401' || code == '403') {
        return MallApplicationException('Dosya yükleme izni alınamadı.');
      }
    }
    return MallApplicationException(
      'Dosya yüklenemedi. Bağlantınızı kontrol edin.',
    );
  }

  static String? _ownedMediaPath(String? url, String userId) {
    if (url == null || url.isEmpty) return null;
    const marker = '/mall-media/';
    final index = url.indexOf(marker);
    if (index < 0) return null;
    final path = Uri.decodeComponent(url.substring(index + marker.length).split('?').first);
    final prefix = '$userId/mall-applications/';
    if (!path.startsWith(prefix)) return null;
    return path;
  }

  static String _imageContentType(Uint8List bytes, String fileName) {
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      return 'image/png';
    }
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  Future<void> submitApplication(String id) async {
    _userId;
    try {
      final result = await _db.rpc(
        'submit_mall_application',
        params: {'p_application_id': id},
      );
      debugPrint('[MALL][SUBMIT] applicationId=$id result=$result');
    } catch (error) {
      if (error is PostgrestException) {
        debugPrint(
          '[MALL][SUBMIT] applicationId=$id code=${error.code} '
          'message=${error.message} details=${error.details}',
        );
        final message = error.message;
        if (message.contains('mall_application_incomplete')) {
          throw MallApplicationException(
            'Başvuru eksik: AVM, konum ve yetkili bilgilerini tamamlayın.',
          );
        }
        if (message.contains('mall_application_documents_required')) {
          throw MallApplicationException('Belgeler başvuru kaydında bulunamadı.');
        }
        if (message.contains('mall_application_invalid_state')) {
          throw MallApplicationException('Bu başvuru artık gönderilemez.');
        }
        throw MallApplicationException('Başvuru gönderilemedi (${error.code}).');
      }
      debugPrint('[MALL][SUBMIT] applicationId=$id error=$error');
      rethrow;
    }
  }

  Future<void> cancelApplication(String id) async {
    _userId;
    await _db.rpc('cancel_mall_application', params: {'p_application_id': id});
  }

  static String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
