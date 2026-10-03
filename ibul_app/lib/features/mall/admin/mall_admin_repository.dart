import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mall_application.dart';

class MallAdminQueueCounts {
  const MallAdminQueueCounts({
    required this.pending,
    required this.needsInfo,
    required this.approved,
    required this.rejected,
  });

  final int pending;
  final int needsInfo;
  final int approved;
  final int rejected;
}

class MallApplicantSummary {
  const MallApplicantSummary({this.displayName, this.email});

  final String? displayName;
  final String? email;
}

class MallAdminCommands {
  const MallAdminCommands._();

  static Map<String, dynamic> approve(String applicationId, String? adminNote) {
    return {
      'p_application_id': applicationId,
      'p_admin_note': _note(adminNote),
    };
  }

  static Map<String, dynamic> reject({
    required String applicationId,
    required String rejectionReason,
    String? adminNote,
  }) {
    return {
      'p_application_id': applicationId,
      'p_rejection_reason': rejectionReason.trim(),
      'p_admin_note': _note(adminNote),
    };
  }

  static Map<String, dynamic> requestInfo({
    required String applicationId,
    required String adminNote,
  }) {
    return {
      'p_application_id': applicationId,
      'p_admin_note': adminNote.trim(),
    };
  }

  static String? _note(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

String mallAdminErrorMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('mall_application_invalid_state') ||
      text.contains('mall_application_mall_already_linked')) {
    return 'Başvurunun durumu başka bir yönetici tarafından değiştirilmiş. Liste yenilendi.';
  }
  if (text.contains('not authorized') || text.contains('42501')) {
    return 'Bu işlem için yetkiniz yok.';
  }
  if (text.contains('rejection_reason_required') ||
      text.contains('admin_note_required')) {
    return 'Bu işlem için açıklama zorunlu.';
  }
  debugPrint('[mall-admin] $error');
  return 'İşlem tamamlanamadı. Bağlantınızı kontrol edip yeniden deneyin.';
}

bool mallAdminCanApprove(MallApplicationStatus status) =>
    status == MallApplicationStatus.pendingReview;

bool mallAdminCanRequestInfo(MallApplicationStatus status) =>
    status == MallApplicationStatus.pendingReview;

bool mallAdminCanReject(MallApplicationStatus status) =>
    status == MallApplicationStatus.pendingReview ||
    status == MallApplicationStatus.needsInfo;

String mallAdminStatusLabel(MallApplicationStatus status) {
  if (status == MallApplicationStatus.needsInfo) return 'Bilgi Bekleniyor';
  return status.label;
}

class MallAdminRepository {
  MallAdminRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static const table = 'mall_applications';
  static const bucket = 'seller-documents';

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<MallAdminQueueCounts> counts() async {
    Future<int> count(String status) {
      return _db.from(table).count(CountOption.exact).eq('status', status);
    }

    final results = await Future.wait([
      count('pending_review'),
      count('needs_info'),
      count('approved'),
      count('rejected'),
    ]);
    return MallAdminQueueCounts(
      pending: results[0],
      needsInfo: results[1],
      approved: results[2],
      rejected: results[3],
    );
  }

  Future<List<MallApplication>> getApplications({
    String? status,
    String? search,
    int limit = 40,
    int offset = 0,
  }) async {
    var query = _db.from(table).select();
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    } else {
      query = query.neq('status', 'draft');
    }
    final token = _searchToken(search);
    if (token.isNotEmpty) {
      final pattern = '%$token%';
      query = query.or(
        'mall_name.ilike.$pattern,city.ilike.$pattern,district.ilike.$pattern,authorized_person_name.ilike.$pattern',
      );
    }
    final rows = await query
        .order('submitted_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map(
          (row) => MallApplication.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<MallApplication?> getApplication(String id) async {
    final row = await _db.from(table).select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return MallApplication.fromMap(Map<String, dynamic>.from(row));
  }

  Future<MallApplicantSummary?> applicantSummary(String userId) async {
    final row = await _db
        .from('users')
        .select('display_name,email')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return MallApplicantSummary(
      displayName: row['display_name']?.toString(),
      email: row['email']?.toString(),
    );
  }

  Future<String?> approveApplication(String applicationId, String? adminNote) async {
    final raw = await _db.rpc(
      'admin_approve_mall_application',
      params: MallAdminCommands.approve(applicationId, adminNote),
    );
    if (raw is Map) return raw['mall_id']?.toString();
    return null;
  }

  Future<void> rejectApplication({
    required String applicationId,
    required String rejectionReason,
    String? adminNote,
  }) {
    return _db.rpc(
      'admin_reject_mall_application',
      params: MallAdminCommands.reject(
        applicationId: applicationId,
        rejectionReason: rejectionReason,
        adminNote: adminNote,
      ),
    );
  }

  Future<void> requestMoreInfo({
    required String applicationId,
    required String adminNote,
  }) {
    return _db.rpc(
      'admin_request_mall_application_info',
      params: MallAdminCommands.requestInfo(
        applicationId: applicationId,
        adminNote: adminNote,
      ),
    );
  }

  /// Malls whose managers asked to go live (status pending_review).
  Future<List<Map<String, dynamic>>> publicationQueue() async {
    final rows = await _db.rpc('admin_mall_publication_queue');
    return [for (final row in rows as List? ?? const []) Map<String, dynamic>.from(row as Map)];
  }

  /// Approve → mall becomes active (visible on the map). Reject needs a note.
  Future<void> reviewPublication({required String mallId, required bool approve, String? note}) {
    return _db.rpc('admin_review_mall_publication', params: {
      'p_mall_id': mallId,
      'p_approve': approve,
      'p_note': MallAdminCommands._note(note),
    });
  }

  Future<String> signedDocumentUrl(String path) {
    return _db.storage.from(bucket).createSignedUrl(path, 300);
  }

  static String _searchToken(String? raw) {
    return (raw ?? '').trim().replaceAll(RegExp(r'[%_,]'), ' ');
  }
}
