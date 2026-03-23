import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/ads_table_names.dart';
import '../enums/ad_enums.dart';
import '../models/ab_test_variant.dart';
import '../models/ad_campaign.dart';
import '../models/ad_campaign_page.dart';
import '../models/ad_metrics.dart';
import '../models/ad_revenue_record.dart';
import '../models/ad_wallet_transaction.dart';
import '../models/campaign_asset.dart';
import '../models/campaign_review.dart';
import '../models/geo_push_trigger.dart';
import '../models/user_interest.dart';
import '../models/user_product_event.dart';
import '../preview/ads_preview_data_source.dart';

class AdsRepository {
  static final AdsPreviewDataSource _sharedPreview = AdsPreviewDataSource();

  AdsRepository({
    SupabaseClient? client,
    AdsPreviewDataSource? previewDataSource,
    this.preferPreview = false,
    this.usePreviewOnFailure = true,
  }) : _client = client ?? Supabase.instance.client,
       _preview = previewDataSource ?? _sharedPreview;

  final SupabaseClient _client;
  final AdsPreviewDataSource _preview;
  final bool preferPreview;
  final bool usePreviewOnFailure;

  static const String _campaignSelect =
      '*, campaign_targets(*), campaign_assets(*), ab_test_variants(*)';

  List<T> _parseListResponse<T>(
    dynamic response,
    T Function(Map<String, dynamic> json) fromJson, {
    required String label,
  }) {
    if (response is! List) {
      debugPrint('AdsRepository $label response was not a list: $response');
      return List<T>.empty(growable: false);
    }

    final items = <T>[];
    for (final item in response) {
      if (item is! Map) {
        debugPrint('AdsRepository $label row skipped because it is not a map.');
        continue;
      }
      try {
        items.add(fromJson(Map<String, dynamic>.from(item)));
      } catch (error, stackTrace) {
        debugPrint('AdsRepository $label row parse failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    return items;
  }

  Map<String, dynamic>? _asJsonMap(dynamic value, {required String label}) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    debugPrint('AdsRepository $label response was not a map: $value');
    return null;
  }

  Map<String, dynamic> _compactPayload(Map<String, dynamic> value) {
    final compact = <String, dynamic>{};
    value.forEach((key, rawValue) {
      if (rawValue == null) return;
      if (rawValue is String && rawValue.trim().isEmpty) return;
      compact[key] = rawValue;
    });
    return compact;
  }

  List<AdCampaign> _mergeCampaignLists(
    List<AdCampaign> remoteCampaigns, {
    String? sellerId,
    List<CampaignStatus>? statuses,
    AdCampaignType? type,
    CampaignObjective? objective,
    int? limit,
  }) {
    final previewCampaigns = _preview.getCampaigns(
      sellerId: sellerId,
      statuses: statuses,
      type: type,
      objective: objective,
      limit: 500,
    );
    final merged = <String, AdCampaign>{
      for (final campaign in previewCampaigns) campaign.id: campaign,
      for (final campaign in remoteCampaigns) campaign.id: campaign,
    };
    final items = merged.values.toList(growable: false)
      ..sort((a, b) {
        final aDate =
            a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateCompare = bDate.compareTo(aDate);
        if (dateCompare != 0) return dateCompare;
        return a.name.compareTo(b.name);
      });
    if (limit == null || items.length <= limit) {
      return items;
    }
    return items.take(limit).toList(growable: false);
  }

  bool _matchesCampaignSearchAndRange(
    AdCampaign campaign, {
    String? searchQuery,
    DateTime? from,
    DateTime? to,
  }) {
    final trimmedQuery = searchQuery?.trim().toLowerCase() ?? '';
    final matchesQuery =
        trimmedQuery.isEmpty ||
        campaign.name.toLowerCase().contains(trimmedQuery) ||
        (campaign.description ?? '').toLowerCase().contains(trimmedQuery);
    final matchesFrom = from == null || !campaign.endsAt.isBefore(from);
    final matchesTo = to == null || !campaign.startsAt.isAfter(to);
    return matchesQuery && matchesFrom && matchesTo;
  }

  List<AdCampaign> _sortCampaignPageItems(
    List<AdCampaign> campaigns, {
    required String sortField,
    required bool ascending,
  }) {
    final sorted = List<AdCampaign>.from(campaigns);
    int compareCampaigns(AdCampaign a, AdCampaign b) {
      int result;
      switch (sortField) {
        case 'name':
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'status':
          result = a.status.dbValue.compareTo(b.status.dbValue);
        case 'objective':
          result = a.objective.dbValue.compareTo(b.objective.dbValue);
        case 'type':
          result = a.type.dbValue.compareTo(b.type.dbValue);
        case 'total_budget':
          result = a.totalBudget.compareTo(b.totalBudget);
        case 'spent_amount':
          result = a.spentAmount.compareTo(b.spentAmount);
        case 'updated_at':
          result = (a.updatedAt ?? a.createdAt ?? DateTime(2000)).compareTo(
            b.updatedAt ?? b.createdAt ?? DateTime(2000),
          );
        case 'starts_at':
        default:
          result = a.startsAt.compareTo(b.startsAt);
      }
      return ascending ? result : -result;
    }

    sorted.sort(compareCampaigns);
    return sorted;
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<AdCampaign>> getCampaigns({
    String? sellerId,
    List<CampaignStatus>? statuses,
    AdCampaignType? type,
    CampaignObjective? objective,
    int limit = 50,
  }) {
    return _run(
      label: 'campaigns',
      action: () async {
        dynamic query = _client
            .from(AdsTableNames.campaigns)
            .select(_campaignSelect);

        if ((sellerId ?? '').isNotEmpty) {
          query = query.eq('seller_id', sellerId!);
        }
        if (statuses != null && statuses.isNotEmpty) {
          query = query.inFilter(
            'status',
            statuses.map((item) => item.dbValue).toList(),
          );
        }
        if (type != null) {
          query = query.eq('type', type.dbValue);
        }
        if (objective != null) {
          query = query.eq('objective', objective.dbValue);
        }

        final response = await query
            .order('starts_at', ascending: false)
            .limit(limit);
        final campaigns = _parseListResponse(
          response,
          AdCampaign.fromJson,
          label: 'campaigns',
        );
        for (final campaign in campaigns) {
          _preview.upsertCampaign(campaign);
        }
        return _mergeCampaignLists(
          campaigns,
          sellerId: sellerId,
          statuses: statuses,
          type: type,
          objective: objective,
          limit: limit,
        );
      },
      preview: () => _preview.getCampaigns(
        sellerId: sellerId,
        statuses: statuses,
        type: type,
        objective: objective,
        limit: limit,
      ),
    );
  }

  Future<AdCampaignPage> getCampaignPage({
    String? sellerId,
    List<CampaignStatus>? statuses,
    AdCampaignType? type,
    CampaignObjective? objective,
    String? searchQuery,
    DateTime? from,
    DateTime? to,
    required int page,
    required int pageSize,
    String sortField = 'starts_at',
    bool ascending = false,
  }) {
    return _run(
      action: () async {
        dynamic countQuery = _client.from(AdsTableNames.campaigns).select('id');
        dynamic dataQuery = _client
            .from(AdsTableNames.campaigns)
            .select(_campaignSelect);

        dynamic applyFilters(dynamic query) {
          if ((sellerId ?? '').isNotEmpty) {
            query = query.eq('seller_id', sellerId!);
          }
          if (statuses != null && statuses.isNotEmpty) {
            query = query.inFilter(
              'status',
              statuses.map((item) => item.dbValue).toList(growable: false),
            );
          }
          if (type != null) {
            query = query.eq('type', type.dbValue);
          }
          if (objective != null) {
            query = query.eq('objective', objective.dbValue);
          }
          final trimmedQuery = searchQuery?.trim() ?? '';
          if (trimmedQuery.isNotEmpty) {
            query = query.or(
              'name.ilike.%$trimmedQuery%,description.ilike.%$trimmedQuery%',
            );
          }
          if (from != null) {
            query = query.gte('ends_at', from.toUtc().toIso8601String());
          }
          if (to != null) {
            query = query.lte('starts_at', to.toUtc().toIso8601String());
          }
          return query;
        }

        countQuery = applyFilters(countQuery);
        dataQuery = applyFilters(dataQuery);

        final totalCount = await countQuery.count(CountOption.exact);
        final safePage = page < 0 ? 0 : page;
        final fromIndex = safePage * pageSize;
        final toIndex = pageSize <= 0 ? fromIndex : fromIndex + pageSize - 1;
        final response = await dataQuery
            .order(sortField, ascending: ascending)
            .range(fromIndex, toIndex);
        final items = _parseListResponse(
          response,
          AdCampaign.fromJson,
          label: 'campaign_page',
        );
        for (final campaign in items) {
          _preview.upsertCampaign(campaign);
        }

        final mergedItems = _mergeCampaignLists(
          items,
          sellerId: sellerId,
          statuses: statuses,
          type: type,
          objective: objective,
          limit: 500,
        ).where(
          (campaign) => _matchesCampaignSearchAndRange(
            campaign,
            searchQuery: searchQuery,
            from: from,
            to: to,
          ),
        ).toList(growable: false);
        final sortedItems = _sortCampaignPageItems(
          mergedItems,
          sortField: sortField,
          ascending: ascending,
        );
        final mergedTotalCount = sortedItems.length;
        final start = safePage * pageSize;
        final end = start + pageSize;
        final pageItems = start >= sortedItems.length
            ? const <AdCampaign>[]
            : sortedItems.sublist(
                start,
                end > sortedItems.length ? sortedItems.length : end,
              );

        return AdCampaignPage(
          items: pageItems,
          totalCount: mergedTotalCount > totalCount
              ? mergedTotalCount
              : totalCount,
          page: safePage,
          pageSize: pageSize,
        );
      },
      preview: () {
        final previewItems = _preview.getCampaigns(
          sellerId: sellerId,
          statuses: statuses,
          type: type,
          objective: objective,
          limit: 500,
        );
        final trimmedQuery = searchQuery?.trim().toLowerCase() ?? '';
        final filtered = previewItems
            .where((campaign) {
              final matchesQuery =
                  trimmedQuery.isEmpty ||
                  campaign.name.toLowerCase().contains(trimmedQuery) ||
                  (campaign.description ?? '').toLowerCase().contains(
                    trimmedQuery,
                  );
              final matchesFrom =
                  from == null || !campaign.endsAt.isBefore(from);
              final matchesTo = to == null || !campaign.startsAt.isAfter(to);
              return matchesQuery && matchesFrom && matchesTo;
            })
            .toList(growable: true);

        int compareCampaigns(AdCampaign a, AdCampaign b) {
          int result;
          switch (sortField) {
            case 'name':
              result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            case 'status':
              result = a.status.dbValue.compareTo(b.status.dbValue);
            case 'objective':
              result = a.objective.dbValue.compareTo(b.objective.dbValue);
            case 'type':
              result = a.type.dbValue.compareTo(b.type.dbValue);
            case 'total_budget':
              result = a.totalBudget.compareTo(b.totalBudget);
            case 'spent_amount':
              result = a.spentAmount.compareTo(b.spentAmount);
            case 'updated_at':
              result = (a.updatedAt ?? a.createdAt ?? DateTime(2000)).compareTo(
                b.updatedAt ?? b.createdAt ?? DateTime(2000),
              );
            case 'starts_at':
            default:
              result = a.startsAt.compareTo(b.startsAt);
          }
          return ascending ? result : -result;
        }

        filtered.sort(compareCampaigns);
        final totalCount = filtered.length;
        final safePage = page < 0 ? 0 : page;
        final start = safePage * pageSize;
        final end = start + pageSize;
        final pageItems = start >= filtered.length
            ? const <AdCampaign>[]
            : filtered.sublist(
                start,
                end > filtered.length ? filtered.length : end,
              );
        return AdCampaignPage(
          items: pageItems,
          totalCount: totalCount,
          page: safePage,
          pageSize: pageSize,
        );
      },
    );
  }

  Future<AdCampaign?> getCampaignById(String campaignId) {
    return _run(
      action: () async {
        final response = await _client
            .from(AdsTableNames.campaigns)
            .select(_campaignSelect)
            .eq('id', campaignId)
            .maybeSingle();
        final json = _asJsonMap(response, label: 'campaign_by_id');
        if (json == null) return null;
        final campaign = AdCampaign.fromJson(json);
        _preview.upsertCampaign(campaign);
        return campaign;
      },
      preview: () => _preview.getCampaignById(campaignId),
    );
  }

  Future<AdCampaign> upsertCampaign(AdCampaign campaign) {
    return _run(
      label: 'upsert_campaign',
      action: () async {
        final payload = campaign.toJson(includeRelations: false)
          ..['updated_at'] = DateTime.now().toUtc().toIso8601String();

        final savedResponse = await _client
            .from(AdsTableNames.campaigns)
            .upsert(payload)
            .select()
            .single();
        final savedCampaignJson = _asJsonMap(
          savedResponse,
          label: 'upsert_campaign',
        );
        final savedCampaign = AdCampaign.fromJson(
          savedCampaignJson ?? campaign.toJson(includeRelations: false),
        );
        debugPrint(
          'AdsRepository upsert_campaign persisted id=${savedCampaign.id} sellerId=${savedCampaign.sellerId} storeId=${savedCampaign.storeId} status=${savedCampaign.status.dbValue}',
        );

        final campaignTarget = campaign.target;
        if (campaignTarget != null) {
          final targetPayload = _compactPayload(campaignTarget.toJson())
            ..['campaign_id'] = savedCampaign.id;
          await _client
              .from(AdsTableNames.campaignTargets)
              .upsert(targetPayload, onConflict: 'campaign_id');
        }

        await _client
            .from(AdsTableNames.campaignAssets)
            .delete()
            .eq('campaign_id', savedCampaign.id);
        if (campaign.assets.isNotEmpty) {
          final assetsPayload = campaign.assets
              .map(
                (item) => _compactPayload(item.toJson())
                  ..['campaign_id'] = savedCampaign.id,
              )
              .toList(growable: false);
          await _client
              .from(AdsTableNames.campaignAssets)
              .insert(assetsPayload);
        }

        await _client
            .from(AdsTableNames.abTestVariants)
            .delete()
            .eq('campaign_id', savedCampaign.id);
        if (campaign.abTestVariants.isNotEmpty) {
          final variantsPayload = campaign.abTestVariants
              .map(
                (item) => _compactPayload(item.toJson())
                  ..['campaign_id'] = savedCampaign.id,
              )
              .toList(growable: false);
          await _client
              .from(AdsTableNames.abTestVariants)
              .insert(variantsPayload);
        }

        final resolvedCampaign =
            (await getCampaignById(savedCampaign.id)) ?? savedCampaign;
        _preview.upsertCampaign(resolvedCampaign);
        return resolvedCampaign;
      },
      preview: () => _preview.upsertCampaign(campaign),
      allowPreviewFallback: false,
    );
  }

  Future<AdCampaign?> setCampaignStatus(
    String campaignId,
    CampaignStatus status, {
    String? reviewNotes,
  }) {
    return _run(
      label: 'set_campaign_status',
      action: () async {
        final payload = <String, dynamic>{
          'status': status.dbValue,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          ...?reviewNotes == null ? null : {'review_notes': reviewNotes},
          if (status == CampaignStatus.paused)
            'paused_at': DateTime.now().toUtc().toIso8601String(),
          if (status == CampaignStatus.approved)
            'approved_at': DateTime.now().toUtc().toIso8601String(),
          if (status == CampaignStatus.rejected)
            'rejected_at': DateTime.now().toUtc().toIso8601String(),
        };
        await _client
            .from(AdsTableNames.campaigns)
            .update(payload)
            .eq('id', campaignId);
        final campaign = await getCampaignById(campaignId);
        if (campaign != null) {
          _preview.upsertCampaign(campaign);
        }
        return campaign;
      },
      preview: () => _preview.setCampaignStatus(
        campaignId,
        status,
        reviewNotes: reviewNotes,
      ),
      allowPreviewFallback: false,
    );
  }

  Future<void> deleteCampaign(String campaignId) {
    return _run(
      label: 'delete_campaign',
      action: () async {
        await _client
            .from(AdsTableNames.campaignAssets)
            .delete()
            .eq('campaign_id', campaignId);
        await _client
            .from(AdsTableNames.abTestVariants)
            .delete()
            .eq('campaign_id', campaignId);
        await _client
            .from(AdsTableNames.campaignTargets)
            .delete()
            .eq('campaign_id', campaignId);
        await _client
            .from(AdsTableNames.campaigns)
            .delete()
            .eq('id', campaignId);
        _preview.deleteCampaign(campaignId);
      },
      preview: () {
        _preview.deleteCampaign(campaignId);
      },
      allowPreviewFallback: false,
    );
  }

  Future<List<AdMetrics>> getMetrics({
    List<String>? campaignIds,
    DateTime? from,
    DateTime? to,
  }) {
    return _run(
      label: 'metrics',
      action: () async {
        dynamic query = _client.from(AdsTableNames.adMetricsDaily).select();
        if (campaignIds != null && campaignIds.isNotEmpty) {
          query = query.inFilter('campaign_id', campaignIds);
        }
        if (from != null) {
          query = query.gte('metric_date', from.toUtc().toIso8601String());
        }
        if (to != null) {
          query = query.lte('metric_date', to.toUtc().toIso8601String());
        }
        final response = await query.order('metric_date', ascending: false);
        return _parseListResponse(
          response,
          AdMetrics.fromJson,
          label: 'metrics',
        );
      },
      preview: () =>
          _preview.getMetrics(campaignIds: campaignIds, from: from, to: to),
    );
  }

  Future<AdMetrics> upsertDailyMetrics(AdMetrics metrics) {
    return _run(
      label: 'upsert_daily_metrics',
      action: () async {
        final response = await _client
            .from(AdsTableNames.adMetricsDaily)
            .upsert(metrics.toJson(), onConflict: 'campaign_id,metric_date')
            .select()
            .single();
        return AdMetrics.fromJson(Map<String, dynamic>.from(response));
      },
      preview: () => _preview.upsertDailyMetrics(metrics),
      allowPreviewFallback: false,
    );
  }

  Future<List<AdRevenueRecord>> getRevenueRecords({
    String? sellerId,
    String? campaignId,
    DateTime? from,
    DateTime? to,
  }) {
    return _run(
      label: 'revenue_records',
      action: () async {
        dynamic query = _client.from(AdsTableNames.adRevenueLogs).select();
        if ((sellerId ?? '').isNotEmpty) {
          query = query.eq('seller_id', sellerId!);
        }
        if ((campaignId ?? '').isNotEmpty) {
          query = query.eq('campaign_id', campaignId!);
        }
        if (from != null) {
          query = query.gte('recorded_at', from.toUtc().toIso8601String());
        }
        if (to != null) {
          query = query.lte('recorded_at', to.toUtc().toIso8601String());
        }
        final response = await query.order('recorded_at', ascending: false);
        return _parseListResponse(
          response,
          AdRevenueRecord.fromJson,
          label: 'revenue_records',
        );
      },
      preview: () => _preview.getRevenueRecords(
        sellerId: sellerId,
        campaignId: campaignId,
        from: from,
        to: to,
      ),
    );
  }

  Future<List<AdWalletTransaction>> getWalletTransactions({
    String? sellerId,
    String? campaignId,
  }) {
    return _run(
      label: 'wallet_transactions',
      action: () async {
        dynamic query = _client
            .from(AdsTableNames.adWalletTransactions)
            .select();
        if ((sellerId ?? '').isNotEmpty) {
          query = query.eq('seller_id', sellerId!);
        }
        if ((campaignId ?? '').isNotEmpty) {
          query = query.eq('campaign_id', campaignId!);
        }
        final response = await query.order('created_at', ascending: false);
        return _parseListResponse(
          response,
          AdWalletTransaction.fromJson,
          label: 'wallet_transactions',
        );
      },
      preview: () => _preview.getWalletTransactions(
        sellerId: sellerId,
        campaignId: campaignId,
      ),
    );
  }

  Future<AdWalletTransaction> createWalletTransaction(
    AdWalletTransaction transaction,
  ) {
    return _run(
      label: 'create_wallet_transaction',
      action: () async {
        final response = await _client
            .from(AdsTableNames.adWalletTransactions)
            .insert(transaction.toJson())
            .select()
            .single();
        return AdWalletTransaction.fromJson(
          Map<String, dynamic>.from(response),
        );
      },
      preview: () => _preview.addWalletTransaction(transaction),
      allowPreviewFallback: false,
    );
  }

  Future<AdRevenueRecord> createRevenueRecord(AdRevenueRecord record) {
    return _run(
      label: 'create_revenue_record',
      action: () async {
        final response = await _client
            .from(AdsTableNames.adRevenueLogs)
            .insert(record.toJson())
            .select()
            .single();
        return AdRevenueRecord.fromJson(Map<String, dynamic>.from(response));
      },
      preview: () => _preview.addRevenueRecord(record),
      allowPreviewFallback: false,
    );
  }

  Future<List<CampaignReview>> getCampaignReviews({
    String? campaignId,
    CampaignReviewStatus? status,
  }) {
    return _run(
      label: 'campaign_reviews',
      action: () async {
        dynamic query = _client.from(AdsTableNames.campaignReviews).select();
        if ((campaignId ?? '').isNotEmpty) {
          query = query.eq('campaign_id', campaignId!);
        }
        if (status != null) {
          query = query.eq('status', status.dbValue);
        }
        final response = await query.order('created_at', ascending: false);
        return _parseListResponse(
          response,
          CampaignReview.fromJson,
          label: 'campaign_reviews',
        );
      },
      preview: () =>
          _preview.getCampaignReviews(campaignId: campaignId, status: status),
    );
  }

  Future<CampaignReview> submitCampaignReview(CampaignReview review) {
    return _run(
      label: 'submit_campaign_review',
      action: () async {
        final response = await _client
            .from(AdsTableNames.campaignReviews)
            .insert(review.toJson())
            .select()
            .single();

        try {
          await _client.from(AdsTableNames.adminReviewLogs).insert({
            'campaign_id': review.campaignId,
            'reviewer_id': review.reviewerId,
            'status': review.status.dbValue,
            'note': review.note,
            'created_at': review.createdAt.toUtc().toIso8601String(),
          });
        } catch (_) {}

        return CampaignReview.fromJson(Map<String, dynamic>.from(response));
      },
      preview: () => _preview.addCampaignReview(review),
      allowPreviewFallback: false,
    );
  }

  Future<List<UserInterest>> getUserInterests({String? userId}) {
    return _run(
      action: () async {
        dynamic query = _client.from(AdsTableNames.userInterests).select();
        if ((userId ?? '').isNotEmpty) {
          query = query.eq('user_id', userId!);
        }
        final response = await query.order('affinity_score', ascending: false);
        return (response as List)
            .map(
              (item) => UserInterest.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      },
      preview: () => _preview.getUserInterests(userId: userId),
    );
  }

  Future<List<UserProductEvent>> getUserEvents({
    String? userId,
    DateTime? from,
  }) {
    return _run(
      action: () async {
        dynamic query = _client.from(AdsTableNames.userProductEvents).select();
        if ((userId ?? '').isNotEmpty) {
          query = query.eq('user_id', userId!);
        }
        if (from != null) {
          query = query.gte('created_at', from.toUtc().toIso8601String());
        }
        final response = await query.order('created_at', ascending: false);
        return (response as List)
            .map(
              (item) =>
                  UserProductEvent.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      },
      preview: () => _preview.getUserEvents(userId: userId, from: from),
    );
  }

  Future<UserProductEvent> recordUserEvent(UserProductEvent event) {
    return _run(
      label: 'record_user_event',
      action: () async {
        final response = await _client
            .from(AdsTableNames.userProductEvents)
            .insert(event.toJson())
            .select()
            .single();
        return UserProductEvent.fromJson(Map<String, dynamic>.from(response));
      },
      preview: () => _preview.addUserEvent(event),
      allowPreviewFallback: false,
    );
  }

  Future<List<GeoPushTrigger>> getGeoPushTriggers({
    String? sellerId,
    String? campaignId,
    bool activeOnly = true,
  }) {
    return _run(
      action: () async {
        dynamic query = _client.from(AdsTableNames.campaignAssets).select();
        query = query.eq('asset_type', AdAssetType.notification.dbValue);
        if ((campaignId ?? '').isNotEmpty) {
          query = query.eq('campaign_id', campaignId!);
        }
        final response = await query.order('created_at', ascending: false);
        final triggers = (response as List)
            .map(
              (item) => CampaignAsset.fromJson(Map<String, dynamic>.from(item)),
            )
            .where(
              (asset) =>
                  sellerId == null || asset.metadata['seller_id'] == sellerId,
            )
            .map(
              (asset) => GeoPushTrigger(
                id: asset.id ?? asset.campaignId,
                campaignId: asset.campaignId,
                sellerId:
                    asset.metadata['seller_id']?.toString() ?? sellerId ?? '',
                storeId: asset.entityId ?? '',
                title: asset.title ?? 'Nearby promotion',
                body: asset.subtitle ?? 'You are close to a promoted store.',
                radiusMeters:
                    int.tryParse(
                      asset.metadata['radius_meters']?.toString() ?? '',
                    ) ??
                    1500,
                cooldownHours:
                    int.tryParse(
                      asset.metadata['cooldown_hours']?.toString() ?? '',
                    ) ??
                    8,
                maxSendsPerWeek:
                    int.tryParse(
                      asset.metadata['max_sends_per_week']?.toString() ?? '',
                    ) ??
                    3,
                triggerType: GeoTriggerTypeParser.fromDbValue(
                  asset.metadata['trigger_type']?.toString(),
                ),
                targetCityCodes:
                    (asset.metadata['target_city_codes'] as List<dynamic>? ??
                            const [])
                        .map((item) => item.toString())
                        .toList(growable: false),
                geohashPrefixes:
                    (asset.metadata['geohash_prefixes'] as List<dynamic>? ??
                            const [])
                        .map((item) => item.toString())
                        .toList(growable: false),
                productIds:
                    (asset.metadata['product_ids'] as List<dynamic>? ??
                            const [])
                        .map((item) => item.toString())
                        .toList(growable: false),
                isActive: activeOnly,
                metadata: asset.metadata,
              ),
            )
            .toList(growable: false);
        if (!activeOnly) return triggers;
        return triggers.where((item) => item.isActive).toList(growable: false);
      },
      preview: () => _preview.getGeoPushTriggers(
        sellerId: sellerId,
        campaignId: campaignId,
        activeOnly: activeOnly,
      ),
    );
  }

  Future<GeoPushTrigger> upsertGeoPushTrigger(GeoPushTrigger trigger) {
    return _run(
      label: 'upsert_geo_push_trigger',
      action: () async {
        await _client.from(AdsTableNames.campaignAssets).upsert({
          'id': trigger.id,
          'campaign_id': trigger.campaignId,
          'asset_type': AdAssetType.notification.dbValue,
          'entity_id': trigger.storeId,
          'title': trigger.title,
          'subtitle': trigger.body,
          'placements': [AdPlacement.pushNotification.dbValue],
          'metadata': {
            'seller_id': trigger.sellerId,
            'radius_meters': trigger.radiusMeters,
            'cooldown_hours': trigger.cooldownHours,
            'max_sends_per_week': trigger.maxSendsPerWeek,
            'trigger_type': trigger.triggerType.dbValue,
            'target_city_codes': trigger.targetCityCodes,
            'geohash_prefixes': trigger.geohashPrefixes,
            'product_ids': trigger.productIds,
            ...trigger.metadata,
          },
        });
        return trigger;
      },
      preview: () => _preview.upsertGeoPushTrigger(trigger),
      allowPreviewFallback: false,
    );
  }

  Future<List<AbTestVariant>> getAbTestVariants(String campaignId) {
    return _run(
      action: () async {
        final response = await _client
            .from(AdsTableNames.abTestVariants)
            .select()
            .eq('campaign_id', campaignId)
            .order('created_at', ascending: false);
        return (response as List)
            .map(
              (item) => AbTestVariant.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      },
      preview: () => _preview.getAbTestVariants(campaignId),
    );
  }

  Future<T> _run<T>({
    String label = 'request',
    required Future<T> Function() action,
    required T Function() preview,
    bool allowPreviewFallback = true,
  }) async {
    if (preferPreview) {
      debugPrint('AdsRepository $label using preview directly.');
      return preview();
    }
    debugPrint('AdsRepository $label started');
    try {
      final result = await action().timeout(const Duration(seconds: 6));
      debugPrint('AdsRepository $label finished');
      return result;
    } catch (error, stackTrace) {
      debugPrint('AdsRepository $label failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!usePreviewOnFailure || !allowPreviewFallback) rethrow;
      debugPrint('AdsRepository $label preview fallback aktif.');
      return preview();
    }
  }
}
