import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/mall_auth_session.dart';
import '../../seller/seller_mall_link_repository.dart' show mallLinkDocumentBucket;
import '../models/mall_ops.dart';
import '../models/mall_store_link.dart';
import 'mall_management_repository.dart';

export '../../seller/seller_mall_link_repository.dart';

/// Store links, campaigns, ads, stats, team and activity. Every write is an RPC
/// that re-checks the caller's mall role on the server.
class MallOperationsRepository {
  MallOperationsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? MallAuthSession.instance.client;

  static final codePattern = RegExp(r'^IBL-[A-Z0-9]{6}$');

  static String normalizeCode(String raw) {
    final compact = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s_]'), '');
    if (compact.startsWith('IBL') && !compact.startsWith('IBL-') && compact.length == 9) {
      return 'IBL-${compact.substring(3)}';
    }
    return compact;
  }

  Future<List<MallBranchCandidate>> findBranches(String mallId, String query) async {
    final rows = await _rpc('mall_find_store_branches', {'p_mall_id': mallId, 'p_query': query.trim()});
    final items = _list(rows).map(MallBranchCandidate.fromMap).toList();
    debugPrint('[MALL][STORES] search len=${query.trim().length} results=${items.length}');
    return items;
  }

  Future<List<MallBranchCandidate>> findBranchByCode(String mallId, String code) async {
    final normalized = normalizeCode(code);
    if (!codePattern.hasMatch(normalized)) {
      throw MallManagementException('Kod IBL-XXXXXX biçiminde olmalı.');
    }
    return findBranches(mallId, normalized);
  }

  /// Floor + store number; the server reuses the matching area or creates it
  /// (type store, reserved) and opens a pending request for the store owner.
  Future<void> requestStoreLink({
    required String mallId,
    required String branchId,
    required String floorId,
    required String unitCode,
    double? areaM2,
    String? note,
  }) async {
    const rpc = 'request_mall_store_link';
    final Object? row;
    try {
      row = await _db.rpc(rpc, params: {
        'p_mall_id': mallId,
        'p_branch_id': branchId,
        'p_floor_id': floorId,
        'p_unit_code': unitCode.trim(),
        'p_area_m2': areaM2,
        'p_note': note?.trim().isEmpty ?? true ? null : note!.trim(),
      });
    } catch (error) {
      final pg = error is PostgrestException ? error : null;
      debugPrint('[MALL][STORE_LINK_REQUEST] rpc=$rpc code=${pg?.code} message=${pg?.message ?? error} '
          'details=${pg?.details} hint=${pg?.hint} mall_id=$mallId branch_id=$branchId '
          'floor_id=$floorId unit_code=${unitCode.trim()}');
      throw MallManagementException(friendlyMallError(error, context: rpc));
    }
    final created = row is Map && row['unit_created'] == true;
    debugPrint('[MALL][STORE_LINK_REQUEST] ok mall_id=$mallId unit_created=$created');
  }

  Future<void> cancelLink(String linkId) => _rpc('cancel_mall_branch_link', {'p_link_id': linkId});

  /// Store applications: the AVM gives the final answer.
  Future<void> respondToApplication(String linkId, {required bool approve, String? note}) => _rpc(
        'respond_mall_branch_link',
        {'p_link_id': linkId, 'p_approve': approve, 'p_note': note?.trim().isEmpty ?? true ? null : note!.trim()},
      );

  Future<void> requestInfo(String linkId, String message) =>
      _rpc('request_mall_link_info', {'p_link_id': linkId, 'p_message': message.trim()});

  /// Short-lived link for a private application document; storage RLS checks the AVM role.
  Future<String> documentUrl(String path) =>
      _guard(() => _db.storage.from(mallLinkDocumentBucket).createSignedUrl(path, 300));

  Future<List<MallStoreLink>> storeLinks(String mallId) async {
    final rows = await _rpc('mall_store_links', {'p_mall_id': mallId});
    return _list(rows).map(MallStoreLink.fromMap).toList();
  }

  Future<List<MallCampaign>> campaigns(String mallId) async {
    final rows = await _guard(() => _db
        .from('mall_campaigns')
        .select()
        .eq('mall_id', mallId)
        .order('starts_at', ascending: false));
    return _list(rows).map(MallCampaign.fromMap).toList();
  }

  Future<void> saveCampaign(String mallId, MallCampaignDraft draft) async {
    await _rpc('upsert_mall_campaign', {
      'p_mall_id': mallId,
      'p_campaign_id': draft.id,
      'p_title': draft.title.trim(),
      'p_description': draft.description,
      'p_image_url': draft.imageUrl,
      'p_starts_at': draft.startsAt.toUtc().toIso8601String(),
      'p_ends_at': draft.endsAt.toUtc().toIso8601String(),
      'p_target_type': draft.targetType,
      'p_target_branch_ids': draft.targetBranchIds,
      'p_target_category': draft.targetCategory,
      'p_publish': draft.publish,
    });
  }

  Future<void> deleteCampaign(String mallId, String campaignId) =>
      _rpc('delete_mall_campaign', {'p_mall_id': mallId, 'p_campaign_id': campaignId});

  Future<List<MallAd>> ads(String mallId) async {
    final rows = await _rpc('mall_ad_campaigns', {'p_mall_id': mallId});
    return _list(rows).map(MallAd.fromMap).toList();
  }

  Future<void> createAd({
    required String mallId,
    required String name,
    required String placement,
    required DateTime startsAt,
    required DateTime endsAt,
    required double totalBudget,
    required bool submit,
  }) async {
    await _rpc('create_mall_ad', {
      'p_mall_id': mallId,
      'p_name': name.trim(),
      'p_placement': placement,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_ends_at': endsAt.toUtc().toIso8601String(),
      'p_total_budget': totalBudget,
      'p_submit': submit,
    });
  }

  Future<void> submitAd(String mallId, String campaignId) =>
      _rpc('submit_mall_ad', {'p_mall_id': mallId, 'p_campaign_id': campaignId});

  Future<MallStats> stats(String mallId, {int days = 30}) async {
    final row = await _rpc('mall_event_stats', {'p_mall_id': mallId, 'p_days': days});
    return MallStats.fromMap(row is Map ? Map<String, dynamic>.from(row) : const {});
  }

  Future<({List<MallMember> members, List<MallInvitation> invitations})> team(String mallId) async {
    final row = await _rpc('mall_member_directory', {'p_mall_id': mallId});
    final map = row is Map ? Map<String, dynamic>.from(row) : const <String, dynamic>{};
    return (
      members: _list(map['members']).map(MallMember.fromMap).toList(),
      invitations: _list(map['invitations']).map(MallInvitation.fromMap).toList(),
    );
  }

  Future<String> invite({required String mallId, required String email, required String role}) async {
    final row = await _rpc('invite_mall_member', {
      'p_mall_id': mallId,
      'p_email': email.trim().toLowerCase(),
      'p_role': role,
    });
    final status = row is Map ? row['status']?.toString() : null;
    return status == 'pending_account'
        ? 'Davet kaydedildi. Kişi bu e-postayla İBUL hesabı açınca daveti kabul edebilir.'
        : 'Davet gönderildi. Kişi kabul edince yetkili olur.';
  }

  Future<void> updateMember({
    required String mallId,
    required String userId,
    required String role,
    required String status,
  }) {
    return _rpc('update_mall_member', {
      'p_mall_id': mallId,
      'p_user_id': userId,
      'p_role': role,
      'p_status': status,
    });
  }

  Future<List<MallActivity>> activity(String mallId) async {
    final rows = await _rpc('mall_recent_activity', {'p_mall_id': mallId, 'p_limit': 10});
    return _list(rows).map(MallActivity.fromMap).toList();
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) {
    return _guard(() => _db.rpc(name, params: params));
  }

  List<Map<String, dynamic>> _list(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw MallManagementException(friendlyMallError(error));
    }
  }
}
