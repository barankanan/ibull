import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../enums/ad_enums.dart';
import '../../helpers/ad_metrics_helper.dart';
import '../../models/ad_campaign.dart';
import '../../models/ad_campaign_page.dart';
import '../../models/ad_health_score.dart';
import '../../models/ad_metrics.dart';
import '../../models/ad_revenue_overview.dart';
import '../../models/ads_dashboard_snapshot.dart';
import '../../services/ad_metrics_service.dart';
import '../../services/ad_revenue_service.dart';
import '../../services/campaign_service.dart';
import '../../../services/store_service.dart';
import 'campaign_detail_dialog.dart';
import 'campaign_wizard_page.dart';
import '../widgets/seller_campaign_table.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/campaign_action_menu.dart';
import '../widgets/health_score_badge.dart';
import '../widgets/status_chip.dart';

class SellerAdsManagerContent extends StatefulWidget {
  const SellerAdsManagerContent({
    required this.sellerId,
    this.embedded = false,
    super.key,
  });

  final String sellerId;
  final bool embedded;

  @override
  State<SellerAdsManagerContent> createState() =>
      _SellerAdsManagerContentState();
}

class _SellerAdsManagerContentState extends State<SellerAdsManagerContent> {
  final CampaignService _campaignService = CampaignService();
  final AdMetricsService _metricsService = AdMetricsService();
  final AdRevenueService _adRevenueService = AdRevenueService();
  final StoreService _storeService = StoreService();

  final TextEditingController _searchController = TextEditingController();
  final Map<String, AdCampaign> _sessionCampaigns = <String, AdCampaign>{};
  static const List<String> _defaultVisibleColumnIds = <String>[
    'name',
    'type',
    'status',
    'spend',
    'impressions',
    'cpm',
    'clicks',
    'ctr',
    'cpc',
    'date',
  ];

  String _typeFilter = 'Tum';
  String _objectiveFilter = 'Tum';
  String _searchQuery = '';
  int _performanceWindowDays = 14;
  final Set<String> _enabledOptionalMetrics = <String>{};
  final Set<String> _selectedStatusFilters = <String>{
    'draft',
    'pending_review',
    'active',
    'approved',
    'paused',
    'scheduled',
    'rejected',
    'stopped',
  };
  DateTimeRange? _dateRange;

  List<AdCampaign> _campaigns = const <AdCampaign>[];
  List<AdCampaign> _tableCampaigns = const <AdCampaign>[];
  List<AdMetrics> _dailyMetrics = const <AdMetrics>[];
  Map<String, AdMetrics> _metricsByCampaign = const <String, AdMetrics>{};
  Map<String, AdHealthScore> _healthByCampaign =
      const <String, AdHealthScore>{};
  AdRevenueOverview? _revenueOverview;
  bool _isLoadingCampaigns = true;
  bool _isLoadingTable = true;
  bool _isRefreshing = false;
  String? _loadError;
  String? _auxiliaryWarning;
  int _campaignLoadToken = 0;
  int _auxLoadToken = 0;
  int _tableLoadToken = 0;
  int _tablePageIndex = 0;
  int _tablePageSize = 10;
  int _tableTotalCount = 0;
  String _tableSortColumnId = 'updated_at';
  bool _tableSortAscending = false;
  bool _selectionMode = false;
  bool _isBulkActionRunning = false;
  final Set<String> _selectedCampaignIds = <String>{};
  final Set<String> _visibleColumnIds = <String>{..._defaultVisibleColumnIds};
  Timer? _tableSearchDebounce;
  bool _isOpeningCreateWizard = false;
  String? _lastSavedCampaignId;
  String? _lastSavedSellerId;
  String? _lastSavedStatus;

  @override
  void initState() {
    super.initState();
    debugPrint(
      'Seller ads page opened. sellerId=${widget.sellerId.trim().isEmpty ? '(empty)' : widget.sellerId.trim()}',
    );
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadCampaigns());
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _tableSearchDebounce?.cancel();
    super.dispose();
  }

  String get _effectiveSellerId {
    final widgetSellerId = widget.sellerId.trim();
    if (widgetSellerId.isNotEmpty) {
      return widgetSellerId;
    }
    return _storeService.currentUserId?.trim() ?? '';
  }

  String _resolvedDropdownValue(String value, List<String> items) {
    return items.contains(value) ? value : items.first;
  }

  String _formatDateRangeLabel(DateTimeRange? range) {
    if (range == null) {
      return 'Tarih araligi';
    }
    return '${range.start.day}.${range.start.month} - ${range.end.day}.${range.end.month}';
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
    _tableSearchDebounce?.cancel();
    _tableSearchDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      unawaited(_loadCampaignTablePage(resetPage: true));
    });
  }

  Future<void> _loadCampaigns({
    bool refresh = false,
    bool preserveErrors = false,
  }) async {
    final token = ++_campaignLoadToken;
    if (mounted) {
      setState(() {
        _loadError = preserveErrors ? _loadError : null;
        if (_campaigns.isEmpty && !refresh) {
          _isLoadingCampaigns = true;
        } else {
          _isRefreshing = true;
        }
      });
    }

    try {
      debugPrint(
        'Seller ads current filters: search="$_searchQuery", statuses=${_selectedStatusFilters.join(',')}, type=$_typeFilter, objective=$_objectiveFilter',
      );
      final campaigns = await _campaignService
          .getCampaignsForSeller(_effectiveSellerId)
          .timeout(const Duration(seconds: 4));
      if (!mounted || token != _campaignLoadToken) return;

      final mergedCampaigns = _mergeCampaigns(
        remoteCampaigns: campaigns,
        preferSessionOrder: false,
      );
      debugPrint(
        'Seller ads campaigns loaded count=${mergedCampaigns.length} sellerId=$_effectiveSellerId',
      );
      setState(() {
        _campaigns = mergedCampaigns;
        _isLoadingCampaigns = false;
        _isRefreshing = false;
        _loadError = null;
      });
      if (mergedCampaigns.isEmpty) {
        setState(() {
          _tableCampaigns = const <AdCampaign>[];
          _tableTotalCount = 0;
          _tablePageIndex = 0;
          _isLoadingTable = false;
          _selectionMode = false;
          _selectedCampaignIds.clear();
          _dailyMetrics = const <AdMetrics>[];
          _metricsByCampaign = const <String, AdMetrics>{};
          _healthByCampaign = const <String, AdHealthScore>{};
          _revenueOverview = _buildFallbackRevenueOverview(mergedCampaigns);
          _auxiliaryWarning = null;
        });
        return;
      }
      unawaited(_loadCampaignTablePage(resetPage: true));
      unawaited(_loadAuxiliaryData(mergedCampaigns));
    } catch (error, stackTrace) {
      debugPrint('Seller ads load error details: $error\n$stackTrace');
      if (!mounted || token != _campaignLoadToken) return;
      final mergedCampaigns = _mergeCampaigns(
        remoteCampaigns: const <AdCampaign>[],
        preferSessionOrder: false,
      );
      setState(() {
        _campaigns = mergedCampaigns;
        _isLoadingCampaigns = false;
        _isRefreshing = false;
        _loadError = mergedCampaigns.isEmpty ? error.toString() : null;
        _auxiliaryWarning = mergedCampaigns.isEmpty
            ? null
            : 'Kampanyalar gosterildi ancak bazi veriler yenilenemedi.';
      });
      unawaited(_loadCampaignTablePage(resetPage: true));
      if (mergedCampaigns.isNotEmpty) {
        unawaited(_loadAuxiliaryData(mergedCampaigns));
      }
    }
  }

  Future<void> _loadAuxiliaryData(List<AdCampaign> campaigns) async {
    final token = ++_auxLoadToken;
    if (campaigns.isEmpty) {
      if (!mounted) return;
      setState(() {
        _dailyMetrics = const <AdMetrics>[];
        _metricsByCampaign = const <String, AdMetrics>{};
        _healthByCampaign = const <String, AdHealthScore>{};
        _revenueOverview = _buildFallbackRevenueOverview(campaigns);
        _auxiliaryWarning = null;
      });
      return;
    }

    final fallbackRevenue = _buildFallbackRevenueOverview(campaigns);
    var warningMessage = '';
    final revenueFuture = _adRevenueService
        .getRevenueOverview(sellerId: _effectiveSellerId)
        .timeout(const Duration(seconds: 3));
    final metricsFuture = _metricsService
        .getDailyMetrics(
          campaignIds: campaigns.map((item) => item.id).toList(growable: false),
          from: DateTime.now().subtract(const Duration(days: 30)),
        )
        .timeout(const Duration(seconds: 3));

    try {
      final revenue = await revenueFuture;
      if (!mounted || token != _auxLoadToken) return;
      setState(() {
        _revenueOverview = revenue;
      });
    } catch (error, stackTrace) {
      debugPrint('Seller ads revenue load error details: $error\n$stackTrace');
      warningMessage =
          'Gelir verisi su an yuklenemedi. Kampanya listesi gosterilmeye devam ediyor.';
      if (!mounted || token != _auxLoadToken) return;
      setState(() {
        _revenueOverview = fallbackRevenue;
      });
    }

    try {
      final metrics = await metricsFuture;
      if (!mounted || token != _auxLoadToken) return;

      final groupedMetrics = <String, List<AdMetrics>>{};
      for (final metric in metrics) {
        groupedMetrics
            .putIfAbsent(metric.campaignId, () => <AdMetrics>[])
            .add(metric);
      }

      final metricsByCampaign = <String, AdMetrics>{};
      final healthByCampaign = <String, AdHealthScore>{};
      for (final campaign in campaigns) {
        final campaignMetrics =
            groupedMetrics[campaign.id] ?? const <AdMetrics>[];
        metricsByCampaign[campaign.id] = AdMetricsHelper.merge(
          campaignMetrics,
          campaignId: campaign.id,
        );
        healthByCampaign[campaign.id] = AdMetricsHelper.buildHealthScore(
          campaignId: campaign.id,
          metrics: campaignMetrics,
          isPendingReview: campaign.status == CampaignStatus.pendingReview,
        );
      }

      setState(() {
        _dailyMetrics = metrics;
        _metricsByCampaign = metricsByCampaign;
        _healthByCampaign = healthByCampaign;
        _revenueOverview ??= fallbackRevenue;
        _auxiliaryWarning = warningMessage.isEmpty ? null : warningMessage;
      });
    } catch (error, stackTrace) {
      debugPrint('Seller ads aux load error details: $error\n$stackTrace');
      if (!mounted || token != _auxLoadToken) return;
      setState(() {
        _dailyMetrics = const <AdMetrics>[];
        _metricsByCampaign = const <String, AdMetrics>{};
        _healthByCampaign = const <String, AdHealthScore>{};
        _revenueOverview ??= fallbackRevenue;
        _auxiliaryWarning = warningMessage.isEmpty
            ? 'Metrikler su an yuklenemedi. Kampanya listesi gosterilmeye devam ediyor.'
            : '$warningMessage Metrikler de su an yuklenemedi.';
      });
    }

    if (mounted && _isMetricSortColumn(_tableSortColumnId)) {
      setState(() {
        _tableCampaigns = _sortCampaignsForTable(_tableCampaigns);
      });
    }
  }

  Future<void> _loadCampaignTablePage({bool resetPage = false}) async {
    final token = ++_tableLoadToken;
    final requestedPage = resetPage ? 0 : _tablePageIndex;
    if (mounted) {
      setState(() {
        _isLoadingTable = true;
        if (resetPage) {
          _tablePageIndex = 0;
        }
      });
    }

    try {
      final page = await _campaignService
          .getCampaignPageForSeller(
            sellerId: _effectiveSellerId,
            statuses: _selectedStatusFilters
                .map(CampaignStatusParser.fromDbValue)
                .toList(growable: false),
            type: _typeFilter == 'Tum'
                ? null
                : AdCampaignType.values.firstWhere(
                    (item) => item.dbValue == _typeFilter,
                    orElse: () => AdCampaignType.productBoost,
                  ),
            objective: _objectiveFilter == 'Tum'
                ? null
                : CampaignObjective.values.firstWhere(
                    (item) => item.dbValue == _objectiveFilter,
                    orElse: () => CampaignObjective.productViews,
                  ),
            searchQuery: _searchQuery,
            from: _dateRange?.start,
            to: _dateRange?.end,
            page: requestedPage,
            pageSize: _tablePageSize,
            sortField: _backendSortFieldForColumn(_tableSortColumnId),
            ascending: _tableSortAscending,
          )
          .timeout(const Duration(seconds: 4));
      if (!mounted || token != _tableLoadToken) {
        return;
      }

      final rows = _sortCampaignsForTable(page.items);
      final localFallback = _buildLocalTableFallback(
        requestedPage: requestedPage,
        pageSize: _tablePageSize,
      );
      final localOnlyRows = localFallback.items
          .where((item) => !rows.any((row) => row.id == item.id))
          .toList(growable: false);
      final shouldUseLocalFallback =
          rows.isEmpty &&
          (page.totalCount > 0 ||
              (localFallback.totalCount > 0 && localFallback.items.isNotEmpty));
      final shouldMergeLocalFallback =
          localOnlyRows.isNotEmpty ||
          localFallback.totalCount > page.totalCount;
      final resolvedRows = shouldUseLocalFallback
          ? _sortCampaignsForTable(localFallback.items)
          : shouldMergeLocalFallback
          ? _sortCampaignsForTable(<AdCampaign>[...rows, ...localOnlyRows])
          : rows;
      final resolvedTotalCount = shouldUseLocalFallback
          ? localFallback.totalCount
          : shouldMergeLocalFallback
          ? math.max(page.totalCount, localFallback.totalCount)
          : page.totalCount;
      final resolvedPageIndex = shouldUseLocalFallback
          ? localFallback.page
          : page.page;
      // ── DIAG-5: post-resolve state before writing setState ──
      debugPrint(
        '[DIAG-5-FETCH]'
        ' fetchedRemote=${rows.length}'
        ' fetchedIds=${rows.map((c) => c.id).join(",")}'
        ' localFallbackCount=${localFallback.items.length}'
        ' shouldUseLocalFallback=$shouldUseLocalFallback'
        ' shouldMerge=$shouldMergeLocalFallback'
        ' resolvedFinal=${resolvedRows.length}'
        ' resolvedIds=${resolvedRows.map((c) => c.id).join(",")}'
        ' savedId=$_lastSavedCampaignId'
        ' insertedIdInFinal=${_lastSavedCampaignId == null ? 'n/a' : resolvedRows.any((c) => c.id == _lastSavedCampaignId).toString()}',
      );
      if (_lastSavedCampaignId != null) {
        debugPrint(
          'Seller ads table refresh savedId=$_lastSavedCampaignId savedSeller=$_lastSavedSellerId savedStatus=$_lastSavedStatus fetchedCount=${rows.length} fetchTotal=${page.totalCount} localCount=${localFallback.items.length} localTotal=${localFallback.totalCount} fetchedContains=${rows.any((campaign) => campaign.id == _lastSavedCampaignId)} localContains=${localFallback.items.any((campaign) => campaign.id == _lastSavedCampaignId)} resolvedContains=${resolvedRows.any((campaign) => campaign.id == _lastSavedCampaignId)} sellerId=$_effectiveSellerId statuses=${_selectedStatusFilters.join(',')} type=$_typeFilter objective=$_objectiveFilter',
        );
      }
      setState(() {
        _tableCampaigns = resolvedRows;
        _tableTotalCount = resolvedTotalCount;
        _tablePageIndex = resolvedPageIndex;
        _isLoadingTable = false;
        _selectionMode = _selectionMode && resolvedRows.isNotEmpty;
        _selectedCampaignIds.removeWhere(
          (id) => !resolvedRows.any((campaign) => campaign.id == id),
        );
      });
    } catch (_) {
      if (!mounted || token != _tableLoadToken) {
        return;
      }
      final fallbackRows = _buildLocalTableFallback(
        requestedPage: requestedPage,
        pageSize: _tablePageSize,
      );
      if (_lastSavedCampaignId != null) {
        debugPrint(
          'Seller ads table refresh fallback savedId=$_lastSavedCampaignId fallbackCount=${fallbackRows.items.length} fallbackTotal=${fallbackRows.totalCount} fallbackContains=${fallbackRows.items.any((campaign) => campaign.id == _lastSavedCampaignId)} sellerId=$_effectiveSellerId statuses=${_selectedStatusFilters.join(',')} type=$_typeFilter objective=$_objectiveFilter',
        );
      }
      setState(() {
        _tableCampaigns = fallbackRows.items;
        _tableTotalCount = fallbackRows.totalCount;
        _tablePageIndex = fallbackRows.page;
        _isLoadingTable = false;
        _selectionMode = _selectionMode && fallbackRows.items.isNotEmpty;
        _selectedCampaignIds.removeWhere(
          (id) => !fallbackRows.items.any((campaign) => campaign.id == id),
        );
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedCampaignIds.clear();
      }
    });
  }

  void _toggleCampaignSelection(String campaignId, bool selected) {
    setState(() {
      if (selected) {
        _selectedCampaignIds.add(campaignId);
      } else {
        _selectedCampaignIds.remove(campaignId);
      }
    });
  }

  void _toggleSelectAllCurrentPage(bool selected) {
    if (!_selectionMode) {
      setState(() {
        _selectionMode = true;
      });
      return;
    }
    final visibleIds = _tableCampaigns
        .map((campaign) => campaign.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    setState(() {
      if (selected) {
        _selectedCampaignIds.addAll(visibleIds);
      } else {
        _selectedCampaignIds.removeAll(visibleIds);
      }
    });
  }

  List<AdCampaign> get _selectedTableCampaigns => _tableCampaigns
      .where((campaign) => _selectedCampaignIds.contains(campaign.id))
      .toList(growable: false);

  Future<void> _pauseSelectedCampaigns() async {
    final selectedCampaigns = _selectedTableCampaigns;
    final pausable = selectedCampaigns
        .where(
          (campaign) =>
              campaign.status != CampaignStatus.paused &&
              campaign.status != CampaignStatus.stopped,
        )
        .toList(growable: false);

    if (pausable.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Duraklatilabilecek secili kampanya bulunamadi.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Secili kampanyalari duraklat'),
        content: Text('${pausable.length} kampanya duraklatilsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Duraklat'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBulkActionRunning = true);
    try {
      await Future.wait(
        pausable.map((campaign) => _campaignService.pauseCampaign(campaign.id)),
      );
      for (final campaign in pausable) {
        _rememberCampaign(
          campaign.copyWith(
            status: CampaignStatus.paused,
            pausedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _selectedCampaignIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pausable.length} kampanya duraklatildi.')),
      );
      unawaited(_loadCampaigns(refresh: true));
    } finally {
      if (mounted) {
        setState(() => _isBulkActionRunning = false);
      }
    }
  }

  Future<void> _deleteSelectedCampaigns() async {
    final selectedCampaigns = _selectedTableCampaigns;
    if (selectedCampaigns.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silmek icin kampanya secin.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Secili kampanyalari sil'),
        content: Text(
          '${selectedCampaigns.length} kampanya kalici olarak silinsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBulkActionRunning = true);
    try {
      await Future.wait(
        selectedCampaigns.map(
          (campaign) => _campaignService.deleteCampaign(campaign.id),
        ),
      );
      for (final campaign in selectedCampaigns) {
        _sessionCampaigns.remove(campaign.id);
      }
      if (!mounted) return;
      setState(() {
        _campaigns = _campaigns
            .where((campaign) => !_selectedCampaignIds.contains(campaign.id))
            .toList(growable: false);
        _tableCampaigns = _tableCampaigns
            .where((campaign) => !_selectedCampaignIds.contains(campaign.id))
            .toList(growable: false);
        _selectedCampaignIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedCampaigns.length} kampanya silindi.'),
        ),
      );
      unawaited(_loadCampaigns(refresh: true));
    } finally {
      if (mounted) {
        setState(() => _isBulkActionRunning = false);
      }
    }
  }

  AdCampaignPage _buildLocalTableFallback({
    required int requestedPage,
    required int pageSize,
  }) {
    final filtered = _filteredCampaigns(_buildSnapshot());
    final sorted = _sortCampaignsForTable(filtered);
    final totalCount = sorted.length;
    final safePage = requestedPage < 0 ? 0 : requestedPage;
    final start = safePage * pageSize;
    final end = start + pageSize;
    final items = start >= sorted.length
        ? const <AdCampaign>[]
        : sorted.sublist(start, end > sorted.length ? sorted.length : end);
    return AdCampaignPage(
      items: items,
      totalCount: totalCount,
      page: safePage,
      pageSize: pageSize,
    );
  }

  bool _isMetricSortColumn(String columnId) {
    return const <String>{
      'spend',
      'impressions',
      'cpm',
      'clicks',
      'ctr',
      'cpc',
    }.contains(columnId);
  }

  String _backendSortFieldForColumn(String columnId) {
    return switch (columnId) {
      'name' => 'name',
      'status' => 'status',
      'type' => 'type',
      'spend' => 'spent_amount',
      'date' => 'updated_at',
      _ => 'starts_at',
    };
  }

  List<AdCampaign> _sortCampaignsForTable(List<AdCampaign> campaigns) {
    if (!_isMetricSortColumn(_tableSortColumnId)) {
      return campaigns;
    }

    final sorted = List<AdCampaign>.from(campaigns);
    num metricValue(AdCampaign campaign) {
      final metrics =
          _metricsByCampaign[campaign.id] ??
          AdMetrics(campaignId: campaign.id, date: DateTime.now());
      return switch (_tableSortColumnId) {
        'impressions' => metrics.impressions,
        'clicks' => metrics.clicks,
        'ctr' => metrics.ctr,
        'cpm' => metrics.cpm,
        'cpc' => metrics.cpc,
        _ => 0,
      };
    }

    sorted.sort((a, b) {
      final compare = metricValue(a).compareTo(metricValue(b));
      if (compare == 0) {
        return a.name.compareTo(b.name);
      }
      return _tableSortAscending ? compare : -compare;
    });
    return sorted;
  }

  List<AdCampaign> _mergeCampaigns({
    required List<AdCampaign> remoteCampaigns,
    required bool preferSessionOrder,
  }) {
    final merged = <String, AdCampaign>{
      for (final campaign in remoteCampaigns) campaign.id: campaign,
    };
    for (final entry in _sessionCampaigns.entries) {
      merged[entry.key] = entry.value;
    }
    final items = merged.values.toList(growable: false);
    items.sort((a, b) {
      if (preferSessionOrder) {
        final aIsSession = _sessionCampaigns.containsKey(a.id);
        final bIsSession = _sessionCampaigns.containsKey(b.id);
        if (aIsSession != bIsSession) {
          return aIsSession ? -1 : 1;
        }
      }
      final aDate =
          a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCompare = bDate.compareTo(aDate);
      if (dateCompare != 0) return dateCompare;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  AdRevenueOverview _buildFallbackRevenueOverview(List<AdCampaign> campaigns) {
    final currency = campaigns.isEmpty ? 'TRY' : campaigns.first.currency;
    final sellerSpend = <String, double>{
      for (final campaign in campaigns) campaign.id: campaign.spentAmount,
    };
    return AdRevenueOverview(
      totalRevenue: 0,
      todayRevenue: 0,
      weekRevenue: 0,
      monthRevenue: 0,
      pendingPayments: 0,
      approvedPayments: 0,
      refundedPayments: 0,
      walletTopUps: 0,
      currency: currency,
      generatedAt: DateTime.now(),
      sellerSpend: sellerSpend,
    );
  }

  void _rememberCampaign(AdCampaign campaign) {
    _sessionCampaigns[campaign.id] = campaign;
  }

  void _toggleStatusFilter(String status) {
    setState(() {
      if (_selectedStatusFilters.contains(status)) {
        if (_selectedStatusFilters.length == 1) return;
        _selectedStatusFilters.remove(status);
      } else {
        _selectedStatusFilters.add(status);
      }
    });
    debugPrint(
      'Seller ads current filters: search="$_searchQuery", statuses=${_selectedStatusFilters.join(',')}, type=$_typeFilter, objective=$_objectiveFilter',
    );
    unawaited(_loadCampaignTablePage(resetPage: true));
  }

  void _ensureCampaignVisibleAfterSave(AdCampaign campaign) {
    final savedStatus = campaign.status.dbValue;
    final hadMissingStatusFilter = !_selectedStatusFilters.contains(
      savedStatus,
    );
    var filterChanged = false;
    if (hadMissingStatusFilter) {
      _selectedStatusFilters.add(savedStatus);
      filterChanged = true;
    }

    final hadSearch = _searchController.text.trim().isNotEmpty;
    if (hadSearch) {
      _searchController.clear();
    }

    final hadTypeFilter = _typeFilter != 'Tum';
    if (hadTypeFilter) {
      _typeFilter = 'Tum';
      filterChanged = true;
    }

    final hadObjectiveFilter = _objectiveFilter != 'Tum';
    if (hadObjectiveFilter) {
      _objectiveFilter = 'Tum';
      filterChanged = true;
    }

    final hadDateRange = _dateRange != null;
    if (hadDateRange) {
      _dateRange = null;
      filterChanged = true;
    }

    if (filterChanged ||
        hadSearch ||
        hadTypeFilter ||
        hadObjectiveFilter ||
        hadDateRange) {
      final message = [
        if (hadSearch) 'arama filtresi temizlendi',
        if (hadMissingStatusFilter) 'durum filtresi guncellendi',
        if (hadTypeFilter) 'reklam turu filtresi sifirlandi',
        if (hadObjectiveFilter) 'hedef filtresi sifirlandi',
        if (hadDateRange) 'tarih araligi sifirlandi',
      ].join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty
                ? '${campaign.status == CampaignStatus.pendingReview ? 'Bekleniliyor' : 'Taslak'} durumundaki kampanya listenize eklendi.'
                : 'Kampanya gorunsun diye $message.',
          ),
        ),
      );
    }
  }

  void _applyOptimisticCampaign(AdCampaign campaign) {
    final normalized = campaign.copyWith(
      sellerId: campaign.sellerId.trim().isEmpty
          ? _effectiveSellerId
          : campaign.sellerId.trim(),
      updatedAt: campaign.updatedAt ?? DateTime.now(),
      createdAt: campaign.createdAt ?? DateTime.now(),
    );
    _rememberCampaign(normalized);
    _ensureCampaignVisibleAfterSave(normalized);

    final merged = _mergeCampaigns(
      remoteCampaigns: [
        normalized,
        ..._campaigns.where((item) => item.id != normalized.id),
      ],
      preferSessionOrder: true,
    );
    final visibleAfterSave = _sortCampaigns(
      _filteredCampaigns(_buildSnapshot(merged)),
    );
    debugPrint(
      'Seller ads draft saved campaign id=${normalized.id} status=${normalized.status.dbValue} sellerId=${normalized.sellerId} widgetSellerId=$_effectiveSellerId',
    );
    debugPrint(
      'Seller ads visible campaigns after save=${visibleAfterSave.length}',
    );
    final firstPageItems = visibleAfterSave
        .take(_tablePageSize)
        .toList(growable: false);

    setState(() {
      _campaigns = merged;
      _tableCampaigns = _sortCampaignsForTable(firstPageItems);
      _tableTotalCount = visibleAfterSave.length;
      _tablePageIndex = 0;
      _isLoadingTable = false;
      _lastSavedCampaignId = normalized.id;
      _lastSavedSellerId = normalized.sellerId;
      _lastSavedStatus = normalized.status.dbValue;
      final existingMetrics = Map<String, AdMetrics>.from(_metricsByCampaign);
      existingMetrics.putIfAbsent(
        normalized.id,
        () => AdMetrics(campaignId: normalized.id, date: DateTime.now()),
      );
      _metricsByCampaign = existingMetrics;
      final existingHealth = Map<String, AdHealthScore>.from(_healthByCampaign);
      existingHealth.putIfAbsent(
        normalized.id,
        () => AdMetricsHelper.buildHealthScore(
          campaignId: normalized.id,
          metrics: const <AdMetrics>[],
          isPendingReview: normalized.status == CampaignStatus.pendingReview,
        ),
      );
      _healthByCampaign = existingHealth;
      _revenueOverview ??= _buildFallbackRevenueOverview(_campaigns);
      _selectedCampaignIds.removeWhere(
        (id) => !_tableCampaigns.any((campaign) => campaign.id == id),
      );
    });
    // ── DIAG-1: state immediately after optimistic save ──
    debugPrint(
      '[DIAG-1-SAVE]'
      ' _tableCampaigns.length=${_tableCampaigns.length}'
      ' _campaigns.length=${_campaigns.length}'
      ' insertedId=${normalized.id}'
      ' insertedStatus=${normalized.status.dbValue}'
      ' insertedSellerId=${normalized.sellerId}',
    );
  }

  AdsDashboardSnapshot _buildSnapshot([List<AdCampaign>? campaignsOverride]) {
    final campaigns = campaignsOverride ?? _campaigns;
    final revenueOverview =
        _revenueOverview ?? _buildFallbackRevenueOverview(campaigns);
    return AdsDashboardSnapshot(
      role: AdRole.seller,
      sellerId: _effectiveSellerId,
      campaigns: campaigns,
      aggregateMetrics: _aggregateMetrics(campaigns, _metricsByCampaign),
      insights: const [],
      healthScores: _healthByCampaign.values.toList(growable: false),
      revenueOverview: revenueOverview,
      reviews: const [],
      walletTransactions: const [],
      topPlacementResults: const [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _buildSnapshot();
    final filteredCampaigns = _filteredCampaigns(snapshot);
    final sortedCampaigns = _sortCampaigns(filteredCampaigns);
    final pendingApprovalCount = sortedCampaigns
        .where((item) => item.status == CampaignStatus.pendingReview)
        .length;
    final draftCampaigns = sortedCampaigns
        .where((item) => item.status == CampaignStatus.draft)
        .toList(growable: false);
    final aggregate = _aggregateMetrics(filteredCampaigns, _metricsByCampaign);
    final hasPerformanceSignals =
        _dailyMetrics.isNotEmpty ||
        aggregate.impressions > 0 ||
        aggregate.clicks > 0 ||
        aggregate.conversions > 0 ||
        aggregate.spend > 0;
    final currency = snapshot.revenueOverview.currency;
    final viewData = _SellerAdsViewData(
      snapshot: snapshot,
      dailyMetrics: _dailyMetrics,
      metricsByCampaign: _metricsByCampaign,
      healthByCampaign: _healthByCampaign,
      bestCampaign: sortedCampaigns.isEmpty ? null : sortedCampaigns.first,
    );

    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(widget.embedded ? 0 : 20),
      children: [
        if (_isRefreshing) const LinearProgressIndicator(minHeight: 2),
        if (_isLoadingCampaigns && _campaigns.isEmpty) ...[
          _buildPerformanceLoadingShell(),
          const SizedBox(height: 16),
          _buildFilterBar(),
          const SizedBox(height: 16),
          _buildCampaignSectionLoadingShell(),
        ] else if (_loadError != null && _campaigns.isEmpty) ...[
          _buildLoadErrorCard(_loadError ?? 'Bilinmeyen hata'),
        ] else ...[
          if (pendingApprovalCount > 0)
            _buildApprovalInfoBanner(pendingApprovalCount),
          if (pendingApprovalCount > 0) const SizedBox(height: 16),
          if (_auxiliaryWarning != null) _buildAuxiliaryWarningCard(),
          if (_auxiliaryWarning != null) const SizedBox(height: 16),
          if (_campaigns.isEmpty)
            _buildPerformanceEmptyState()
          else if (!hasPerformanceSignals)
            _buildPerformanceEmptyState()
          else if (_dailyMetrics.isEmpty && sortedCampaigns.isNotEmpty)
            _buildDeferredPerformanceShell()
          else
            _buildPerformanceOverview(
              data: viewData,
              campaigns: filteredCampaigns,
              aggregate: aggregate,
              currency: currency,
              draftCampaignCount: draftCampaigns.length,
            ),
          const SizedBox(height: 16),
          _buildFilterBar(),
          const SizedBox(height: 16),
          _buildCampaignSection(
            title: 'Kampanya tablosu',
            subtitle:
                'Meta Ads Manager benzeri veri tablosu. Kolonlari yeniden duzenleyebilir, boyutlandirabilir ve satirlari secerek toplu aksiyonlar uygulayabilirsiniz.',
            data: viewData,
            campaigns: _tableCampaigns,
            emptyTitle: 'Henuz kampanya yok',
            emptyDescription:
                'Henuz kampanya yok. Reklam olusturarak baslayin.',
          ),
          const SizedBox(height: 16),
        ],
      ],
    );

    if (kIsWeb) {
      return content;
    }

    return RefreshIndicator(
      onRefresh: () => _loadCampaigns(refresh: true),
      child: content,
    );
  }

  Widget _buildMetricSummaryCard({
    required String title,
    required String value,
    required Color accent,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceOverview({
    required _SellerAdsViewData data,
    required List<AdCampaign> campaigns,
    required AdMetrics aggregate,
    required String currency,
    required int draftCampaignCount,
  }) {
    final points = _buildTrendPoints(
      campaigns,
      data.dailyMetrics,
      _performanceWindowDays,
    );
    final ctr = aggregate.impressions == 0
        ? 0.0
        : aggregate.clicks / aggregate.impressions;
    final cpc = aggregate.clicks == 0
        ? 0.0
        : aggregate.spend / aggregate.clicks;
    final cpm = aggregate.impressions == 0
        ? 0.0
        : (aggregate.spend / aggregate.impressions) * 1000;
    final balance = data.snapshot.revenueOverview.walletTopUps;
    final activeCount = campaigns.where((item) => item.isLive).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1120;
          final metricCards = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricSummaryCard(
                title: 'Toplam harcama',
                value: '${aggregate.spend.toStringAsFixed(0)} $currency',
                accent: const Color(0xFF2563EB),
              ),
              _buildMetricSummaryCard(
                title: 'Gosterim',
                value: aggregate.impressions.toString(),
                accent: const Color(0xFF7C3AED),
              ),
              _buildMetricSummaryCard(
                title: 'Tiklama',
                value: aggregate.clicks.toString(),
                accent: const Color(0xFF0EA5E9),
              ),
              _buildMetricSummaryCard(
                title: 'CPC / CPM',
                value:
                    '${cpc.toStringAsFixed(2)} / ${cpm.toStringAsFixed(2)} $currency',
                accent: const Color(0xFF16A34A),
              ),
            ],
          );

          final chartSection = Expanded(
            flex: isWide ? 8 : 1,
            child: _buildTrendChartCard(
              points: points,
              currency: currency,
              windowDays: _performanceWindowDays,
            ),
          );
          final sideSection = SizedBox(
            width: isWide ? 300 : double.infinity,
            child: Column(
              children: [
                _buildPerformanceGaugeCard(
                  ctr: ctr,
                  activeCount: activeCount,
                  totalCount: campaigns.length,
                ),
                const SizedBox(height: 12),
                _buildBudgetVisualCard(
                  points: points,
                  balance: balance,
                  currency: currency,
                ),
              ],
            ),
          );

          final actionButtons = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _isOpeningCreateWizard
                    ? null
                    : _handleCreateCampaignTap,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  _isOpeningCreateWizard ? 'Aciliyor...' : 'Reklam olustur',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _loadCampaigns(refresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Yenile'),
              ),
            ],
          );

          final headerText = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reklam Performansi',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$activeCount aktif, $draftCampaignCount taslak kampanya. Performans verileri yukaridan, tablo operasyonlari asagidan yonetilir.',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constraints.maxWidth >= 980)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: headerText),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                )
              else ...[
                headerText,
                const SizedBox(height: 14),
                actionButtons,
              ],
              const SizedBox(height: 18),
              metricCards,
              const SizedBox(height: 16),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    chartSection,
                    const SizedBox(width: 12),
                    sideSection,
                  ],
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 360,
                      child: _buildTrendChartCard(
                        points: points,
                        currency: currency,
                        windowDays: _performanceWindowDays,
                      ),
                    ),
                    const SizedBox(height: 12),
                    sideSection,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1180;
        final searchWidth = compact ? 220.0 : 260.0;
        final dropdownWidth = compact ? 132.0 : 150.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x040F172A),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: searchWidth,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Kampanya ara',
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: dropdownWidth + 28,
                child: PopupMenuButton<String>(
                  tooltip: 'Durum filtreleri',
                  onSelected: _toggleStatusFilter,
                  itemBuilder: (context) => _statusFilterEntries
                      .map(
                        (entry) => CheckedPopupMenuItem<String>(
                          value: entry.$1,
                          checked: _selectedStatusFilters.contains(entry.$1),
                          child: Text(entry.$2),
                        ),
                      )
                      .toList(growable: false),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_outlined,
                          size: 18,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedStatusFilters.length ==
                                    _statusFilterEntries.length
                                ? 'Tum durumlar'
                                : 'Durumlar (${_selectedStatusFilters.length})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _filterDropdown(
                label: 'Reklam turu',
                value: _resolvedDropdownValue(_typeFilter, const <String>[
                  'Tum',
                  'product_boost',
                  'store_boost',
                  'collection_boost',
                  'geo_push',
                ]),
                width: dropdownWidth,
                items: const [
                  'Tum',
                  'product_boost',
                  'store_boost',
                  'collection_boost',
                  'geo_push',
                ],
                onChanged: (value) {
                  setState(() => _typeFilter = value ?? 'Tum');
                  unawaited(_loadCampaignTablePage(resetPage: true));
                },
              ),
              _filterDropdown(
                label: 'Hedef',
                value: _resolvedDropdownValue(_objectiveFilter, const <String>[
                  'Tum',
                  'product_views',
                  'store_visits',
                  'collection_discovery',
                  'favorites',
                  'add_to_cart',
                  'orders',
                  'drive_nearby_traffic',
                ]),
                width: dropdownWidth,
                items: const [
                  'Tum',
                  'product_views',
                  'store_visits',
                  'collection_discovery',
                  'favorites',
                  'add_to_cart',
                  'orders',
                  'drive_nearby_traffic',
                ],
                onChanged: (value) {
                  setState(() => _objectiveFilter = value ?? 'Tum');
                  unawaited(_loadCampaignTablePage(resetPage: true));
                },
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _dateRange,
                  );
                  if (range != null) {
                    setState(() => _dateRange = range);
                    unawaited(_loadCampaignTablePage(resetPage: true));
                  }
                },
                icon: const Icon(Icons.date_range_rounded),
                label: Text(_formatDateRangeLabel(_dateRange)),
              ),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _typeFilter = 'Tum';
                    _objectiveFilter = 'Tum';
                    _dateRange = null;
                    _selectedStatusFilters
                      ..clear()
                      ..addAll(_statusFilterEntries.map((entry) => entry.$1));
                  });
                  unawaited(_loadCampaignTablePage(resetPage: true));
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Sifirla'),
              ),
            ],
          ),
        );
      },
    );
  }

  List<(String, String)> get _statusFilterEntries => const <(String, String)>[
    ('draft', 'Taslak'),
    ('pending_review', 'Onay bekliyor'),
    ('active', 'Aktif'),
    ('approved', 'Onaylandi'),
    ('paused', 'Duraklatildi'),
    ('scheduled', 'Planlandi'),
    ('rejected', 'Reddedildi'),
    ('stopped', 'Durduruldu'),
  ];

  Widget _buildLoadErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reklam paneli yuklenemedi',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF7F1D1D), height: 1.5),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _loadCampaigns(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuxiliaryWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _auxiliaryWarning ?? '-',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceLoadingShell() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically = constraints.maxWidth < 1100;
        if (stackVertically) {
          return Column(
            children: [
              _buildLoadingCard(height: 320),
              const SizedBox(height: 12),
              _buildLoadingCard(height: 164),
              const SizedBox(height: 12),
              _buildLoadingCard(height: 164),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _buildLoadingCard(height: 360)),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildLoadingCard(height: 174),
                  const SizedBox(height: 12),
                  _buildLoadingCard(height: 174),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCampaignSectionLoadingShell() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final subtitleWidth = math.min(460.0, constraints.maxWidth - 36);
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLoadingBar(width: 240, height: 20),
              const SizedBox(height: 10),
              _buildLoadingBar(width: subtitleWidth, height: 12),
              const SizedBox(height: 18),
              ...List.generate(
                5,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildLoadingCard(height: 52, radius: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard({required double height, double radius = 24}) {
    final isCompact = height <= 96;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(isCompact ? 12 : 18),
      child: isCompact
          ? Row(
              children: [
                _buildLoadingBar(width: 120, height: 14),
                const Spacer(),
                _buildLoadingBar(width: 72, height: 14),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLoadingBar(width: 180, height: 18),
                const SizedBox(height: 12),
                _buildLoadingBar(width: double.infinity, height: 12),
                const SizedBox(height: 8),
                _buildLoadingBar(width: double.infinity, height: 12),
                const SizedBox(height: 8),
                _buildLoadingBar(width: 140, height: 12),
              ],
            ),
    );
  }

  Widget _buildLoadingBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildCampaignTable(
    _SellerAdsViewData data,
    List<AdCampaign> campaigns,
  ) {
    final currency = campaigns.isEmpty ? 'TRY' : campaigns.first.currency;
    final rows = campaigns
        .map(
          (campaign) => SellerCampaignTableRow(
            campaign: campaign,
            metrics:
                data.metricsByCampaign[campaign.id] ??
                AdMetrics(campaignId: campaign.id, date: DateTime.now()),
            health: data.healthByCampaign[campaign.id],
          ),
        )
        .toList(growable: false);
    debugPrint(
      '[SELLER-TABLE] rows=${rows.length}'
      ' ids=${rows.map((r) => r.campaign.id).join("|")}'
      ' statuses=${rows.map((r) => r.campaign.status.dbValue).join("|")}',
    );
    return SellerCampaignTable(
      rows: rows,
      currency: currency,
      visibleColumnIds: _visibleColumnIds,
      optionalColumnIds: _enabledOptionalMetrics,
      selectionMode: _selectionMode,
      selectedCampaignIds: _selectedCampaignIds,
      sortColumnId: _tableSortColumnId,
      sortAscending: _tableSortAscending,
      onSortChanged: _handleTableSort,
      pageIndex: _tablePageIndex,
      pageSize: _tablePageSize,
      totalRowCount: _tableTotalCount,
      onPageChanged: _handlePageChanged,
      onPageSizeChanged: _handlePageSizeChanged,
      onEdit: (c) => unawaited(_openEditWizard(c)),
      onDetail: (c) => unawaited(_openDetail(c)),
      onPause: (c) => unawaited(_pauseCampaign(c)),
      onResume: (c) => unawaited(_resumeCampaign(c)),
      onDelete: (c) => unawaited(_deleteCampaign(c)),
      onSelectionChanged: _toggleCampaignSelection,
      onSelectAllChanged: _toggleSelectAllCurrentPage,
    );
  }

  Widget _buildCampaignSection({
    required String title,
    required String subtitle,
    required _SellerAdsViewData data,
    required List<AdCampaign> campaigns,
    required String emptyTitle,
    required String emptyDescription,
  }) {
    // ── DIAG-2: render-source truth ──
    final diagWillShowTable = campaigns.isNotEmpty;
    final diagWillShowLoading = !diagWillShowTable && _isLoadingTable;
    final diagWillShowEmpty = !diagWillShowTable && !diagWillShowLoading;
    debugPrint(
      '[DIAG-2-UI] isLoadingTable=$_isLoadingTable'
      ' tableCampaignsLength=${campaigns.length}'
      ' allCampaignsLength=${_campaigns.length}'
      ' willShowTable=$diagWillShowTable'
      ' willShowLoadingShell=$diagWillShowLoading'
      ' willShowEmptyState=$diagWillShowEmpty',
    );
    return Container(
      padding: const EdgeInsets.only(top: 18, bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                );
                final action = FilledButton.icon(
                  onPressed: _isOpeningCreateWizard
                      ? null
                      : _handleCreateCampaignTap,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(
                    _isOpeningCreateWizard ? 'Aciliyor...' : 'Reklam olustur',
                  ),
                );

                if (constraints.maxWidth >= 920) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 12),
                      action,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleBlock, const SizedBox(height: 14), action],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_selectedCampaignIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_selectedCampaignIds.length} secili',
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (_selectionMode) ...[
                  OutlinedButton.icon(
                    onPressed: _isBulkActionRunning
                        ? null
                        : _toggleSelectionMode,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Iptal'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _selectedCampaignIds.isEmpty || _isBulkActionRunning
                        ? null
                        : _pauseSelectedCampaigns,
                    icon: _isBulkActionRunning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.pause_circle_outline, size: 16),
                    label: const Text('Duraklat'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _selectedCampaignIds.isEmpty || _isBulkActionRunning
                        ? null
                        : _deleteSelectedCampaigns,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    icon: _isBulkActionRunning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Sil'),
                  ),
                ],
                if (campaigns.isNotEmpty || _isLoadingTable)
                  PopupMenuButton<String>(
                    tooltip: 'Sutunlari duzenle',
                    onSelected: _handleColumnMenuSelection,
                    itemBuilder: (context) => [
                      ..._defaultVisibleColumnIds.map(
                        (columnId) => CheckedPopupMenuItem<String>(
                          value: columnId,
                          checked: _visibleColumnIds.contains(columnId),
                          child: Text(_columnMenuLabel(columnId)),
                        ),
                      ),
                      const PopupMenuDivider(),
                      _extraMetricItem(
                        value: 'add_to_carts',
                        label: 'Sepete ekleme',
                      ),
                      _extraMetricItem(value: 'favorites', label: 'Begeni'),
                      _extraMetricItem(
                        value: 'questions',
                        label: 'Soru sayisi',
                      ),
                      _extraMetricItem(
                        value: 'store_visits',
                        label: 'Magaza inceleme',
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_column_outlined,
                            size: 16,
                            color: Color(0xFF475569),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sutunlari duzenle',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    tooltip: 'Ek metrikler',
                    onSelected: _toggleOptionalMetric,
                    itemBuilder: (context) => [
                      _extraMetricItem(
                        value: 'add_to_carts',
                        label: 'Sepete ekleme',
                      ),
                      _extraMetricItem(value: 'favorites', label: 'Begeni'),
                      _extraMetricItem(
                        value: 'questions',
                        label: 'Soru sayisi',
                      ),
                      _extraMetricItem(
                        value: 'store_visits',
                        label: 'Magaza inceleme',
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_column_outlined,
                            size: 16,
                            color: Color(0xFF475569),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Ek metrikler',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Show table whenever we have data (even during background reload),
          // so the optimistic update is never hidden by the loading shell.
          if (campaigns.isNotEmpty)
            _buildCampaignTable(data, campaigns)
          else if (_isLoadingTable)
            _buildCampaignSectionLoadingShell()
          else
            _buildSimpleEmptyState(
              title: emptyTitle,
              description: emptyDescription,
              actionLabel: 'Reklam olustur',
              onAction: _isOpeningCreateWizard
                  ? null
                  : _handleCreateCampaignTap,
            ),
        ],
      ),
    );
  }

  Widget _buildDeferredPerformanceShell() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cta = FilledButton.icon(
                onPressed: _isOpeningCreateWizard
                    ? null
                    : _handleCreateCampaignTap,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  _isOpeningCreateWizard ? 'Aciliyor...' : 'Reklam olustur',
                ),
              );

              if (constraints.maxWidth >= 860) {
                return Row(
                  children: [
                    const Icon(
                      Icons.insights_outlined,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Performans verileri hazirlaniyor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    cta,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.insights_outlined, color: Color(0xFF64748B)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Performans verileri hazirlaniyor',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  cta,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Kampanya listesi hazir. Grafikler ve ek performans kartlari arka planda yukleniyor.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildPerformanceLoadingShell(),
        ],
      ),
    );
  }

  Widget _buildPerformanceEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconBox = Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: Color(0xFF7C3AED),
            ),
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Henuz veri yok, reklam verin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Daha once reklam vermediginiz icin performans verisi olusmadi. Ilk reklaminizi olusturdugunuzda bu alan otomatik olarak dolmaya baslar.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _isOpeningCreateWizard
                        ? null
                        : _handleCreateCampaignTap,
                    icon: const Icon(Icons.ads_click_rounded),
                    label: Text(
                      _isOpeningCreateWizard
                          ? 'Aciliyor...'
                          : 'Hemen reklam ver',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _loadCampaigns(refresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Yenile'),
                  ),
                ],
              ),
            ],
          );

          if (constraints.maxWidth >= 760) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBox,
                const SizedBox(width: 16),
                Expanded(child: content),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [iconBox, const SizedBox(height: 16), content],
          );
        },
      ),
    );
  }

  Widget _buildSimpleEmptyState({
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.campaign_outlined,
            size: 38,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleCreateCampaignTap() async {
    if (_isOpeningCreateWizard || !mounted) {
      return;
    }
    final sellerId = _effectiveSellerId;
    if (sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Satıcı oturumu henüz hazır değil. Lütfen sayfayı yenileyip tekrar deneyin.',
          ),
        ),
      );
      unawaited(_loadCampaigns(refresh: true, preserveErrors: true));
      return;
    }
    setState(() {
      _isOpeningCreateWizard = true;
    });
    try {
      await _openCreateWizard();
    } catch (error, stackTrace) {
      debugPrint('Seller ads create wizard open error: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reklam olusturma sayfasi acilamadi: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningCreateWizard = false;
        });
      }
    }
  }

  void _toggleOptionalMetric(String value) {
    setState(() {
      if (_enabledOptionalMetrics.contains(value)) {
        _enabledOptionalMetrics.remove(value);
      } else {
        _enabledOptionalMetrics.add(value);
      }
    });
  }

  void _toggleColumnVisibility(String columnId) {
    if (_defaultVisibleColumnIds.contains(columnId) &&
        _visibleColumnIds.length == 1) {
      return;
    }
    setState(() {
      if (_visibleColumnIds.contains(columnId)) {
        _visibleColumnIds.remove(columnId);
      } else {
        _visibleColumnIds.add(columnId);
      }
    });
  }

  void _handleColumnMenuSelection(String columnId) {
    if (const <String>{
      'add_to_carts',
      'favorites',
      'questions',
      'store_visits',
    }.contains(columnId)) {
      _toggleOptionalMetric(columnId);
      return;
    }
    _toggleColumnVisibility(columnId);
  }

  void _handleTableSort(String columnId) {
    setState(() {
      if (_tableSortColumnId == columnId) {
        _tableSortAscending = !_tableSortAscending;
      } else {
        _tableSortColumnId = columnId;
        _tableSortAscending = columnId == 'name' || columnId == 'status';
      }
    });
    unawaited(_loadCampaignTablePage(resetPage: true));
  }

  void _handlePageChanged(int pageIndex) {
    if (pageIndex == _tablePageIndex) {
      return;
    }
    setState(() {
      _tablePageIndex = pageIndex;
    });
    unawaited(_loadCampaignTablePage(resetPage: false));
  }

  void _handlePageSizeChanged(int? pageSize) {
    if (pageSize == null || pageSize == _tablePageSize) {
      return;
    }
    setState(() {
      _tablePageSize = pageSize;
      _tablePageIndex = 0;
    });
    unawaited(_loadCampaignTablePage(resetPage: true));
  }

  Widget _buildApprovalInfoBanner(int count) {
    final summary = count == 1
        ? '1 kampanya icin onay bekleniliyor.'
        : '$count kampanya icin onay bekleniliyor.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 20,
            color: Color(0xFFEA580C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$summary Kampanyayi listeden acip duzenleyebilirsiniz.',
              style: const TextStyle(
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBadge(AdCampaign campaign) {
    final isPending = campaign.status == CampaignStatus.pendingReview;
    final isDraft = campaign.status == CampaignStatus.draft;
    if (!isPending && !isDraft) {
      return const SizedBox.shrink();
    }

    final label = isPending ? 'Onay bekleniliyor' : 'Taslak kaydedildi';
    final background = isPending
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFF1F5F9);
    final foreground = isPending
        ? const Color(0xFFEA580C)
        : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isPending ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.hourglass_top_rounded : Icons.edit_note_rounded,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  bool _showReviewBadge(AdCampaign campaign) {
    return campaign.status == CampaignStatus.pendingReview ||
        campaign.status == CampaignStatus.draft;
  }

  // ignore: unused_element
  Widget _buildMobileCampaignCard(_SellerCampaignRow row) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Duzenle',
                onPressed: () => _openEditWizard(row.campaign),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              Expanded(
                child: Text(
                  row.campaign.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              CampaignActionMenu(
                isPaused: row.campaign.status.dbValue == 'paused',
                onDetail: () => _openDetail(row.campaign),
                onEdit: () => _openEditWizard(row.campaign),
                onPause: () => _pauseCampaign(row.campaign),
                onResume: () => _resumeCampaign(row.campaign),
                onDelete: () => _deleteCampaign(row.campaign),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip.fromStatus(row.campaign.status.dbValue),
              HealthScoreBadge(score: row.health?.score ?? 0, compact: true),
              _buildReviewBadge(row.campaign),
            ],
          ),
          const SizedBox(height: 12),
          BudgetProgressBar(
            spent: row.campaign.spentAmount,
            total: row.campaign.totalBudget,
            currency: row.campaign.currency,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _miniMetric(
                'CTR',
                '%${(row.metrics.ctr * 100).toStringAsFixed(2)}',
              ),
              _miniMetric('CPC', row.metrics.cpc.toStringAsFixed(2)),
              _miniMetric('CPM', row.metrics.cpm.toStringAsFixed(2)),
              _miniMetric('Conversion', row.metrics.conversions.toString()),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _extraMetricItem({
    required String value,
    required String label,
  }) {
    return CheckedPopupMenuItem<String>(
      value: value,
      checked: _enabledOptionalMetrics.contains(value),
      child: Text(label),
    );
  }

  String _columnMenuLabel(String columnId) {
    return switch (columnId) {
      'name' => 'Reklam adi',
      'type' => 'Kampanya turu',
      'status' => 'Durum',
      'spend' => 'Adspend',
      'impressions' => 'Gosterim (Impr)',
      'cpm' => 'CPM',
      'clicks' => 'Tiklama (Clicks)',
      'ctr' => 'CTR',
      'cpc' => 'CPC',
      'date' => 'Tarih',
      _ => columnId,
    };
  }

  // ignore: unused_element
  String _objectiveLabel(CampaignObjective objective) {
    return switch (objective) {
      CampaignObjective.productViews => 'Goruntulenme',
      CampaignObjective.storeVisits => 'Magaza ziyareti',
      CampaignObjective.collectionDiscovery => 'Liste kesfi',
      CampaignObjective.favorites => 'Favori',
      CampaignObjective.addToCart => 'Sepete ekleme',
      CampaignObjective.orders => 'Siparis',
      CampaignObjective.driveNearbyTraffic => 'Yakin trafik',
    };
  }

  // ignore: unused_element
  String _campaignTypeLabel(AdCampaignType type) {
    return switch (type) {
      AdCampaignType.productBoost => 'Urun one cikarma',
      AdCampaignType.storeBoost => 'Magaza one cikarma',
      AdCampaignType.collectionBoost => 'Liste one cikar',
      AdCampaignType.geoPush => 'Konum bildirim',
      AdCampaignType.banner => 'Banner',
      AdCampaignType.categorySponsor => 'Kategori sponsor',
    };
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required double width,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(growable: false),
        onChanged: onChanged,
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChartCard({
    required List<_DailyPerformancePoint> points,
    required String currency,
    required int windowDays,
  }) {
    var impressions = 0;
    var clicks = 0;
    var conversions = 0;
    var spend = 0.0;
    for (final point in points) {
      impressions += point.impressions;
      clicks += point.clicks;
      conversions += point.conversions;
      spend += point.spend;
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performans trendi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Son $windowDays gundeki gosterim, tiklama ve donusum hareketi.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: [7, 14, 30]
                    .map(
                      (days) => _windowChip(
                        label: '$days gun',
                        selected: _performanceWindowDays == days,
                        onTap: () {
                          if (_performanceWindowDays == days) return;
                          setState(() => _performanceWindowDays = days);
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chartMetricPill(
                'Gosterim',
                impressions.toString(),
                const Color(0xFF2563EB),
              ),
              _chartMetricPill(
                'Tiklama',
                clicks.toString(),
                const Color(0xFF0EA5E9),
              ),
              _chartMetricPill(
                'Conversion',
                conversions.toString(),
                const Color(0xFF16A34A),
              ),
              _chartMetricPill(
                'Harcama',
                '${spend.toStringAsFixed(0)} $currency',
                const Color(0xFF7C3AED),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 210,
            child: CustomPaint(
              painter: _PerformanceLineChartPainter(points: points),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceGaugeCard({
    required double ctr,
    required int activeCount,
    required int totalCount,
  }) {
    final progress = ctr.clamp(0.0, 0.08) / 0.08;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CTR performansi',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 118,
              height: 118,
              child: CustomPaint(
                painter: _RingGaugePainter(
                  progress: progress,
                  color: const Color(0xFF7C3AED),
                ),
                child: Center(
                  child: Text(
                    '%${(ctr * 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$activeCount / $totalCount kampanya aktif veya yayinda.',
            style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetVisualCard({
    required List<_DailyPerformancePoint> points,
    required double balance,
    required String currency,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Butce akisi',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: CustomPaint(
              painter: _MiniBarChartPainter(points: points),
              child: Container(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Kalan bakiye: ${balance.toStringAsFixed(0)} $currency',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mor cubuklar gunluk harcama yogunlugunu gosterir.',
            style: TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _chartMetricPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _windowChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  List<_DailyPerformancePoint> _buildTrendPoints(
    List<AdCampaign> campaigns,
    List<AdMetrics> metrics,
    int windowDays,
  ) {
    final campaignIds = campaigns.map((item) => item.id).toSet();
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: windowDays - 1));
    final byDay = <DateTime, AdMetrics>{};

    for (final metric in metrics) {
      if (!campaignIds.contains(metric.campaignId)) continue;
      final day = DateTime(
        metric.date.year,
        metric.date.month,
        metric.date.day,
      );
      final existingMetric = byDay[day];
      final metricsForDay = <AdMetrics>[metric];
      if (existingMetric != null) {
        metricsForDay.insert(0, existingMetric);
      }
      byDay[day] = AdMetricsHelper.merge(
        metricsForDay,
        campaignId: 'trend',
      ).copyWith(date: day);
    }

    final points = <_DailyPerformancePoint>[];
    for (var i = 0; i < windowDays; i++) {
      final day = start.add(Duration(days: i));
      final item = byDay[day];
      points.add(
        _DailyPerformancePoint(
          day: day,
          impressions: item?.impressions ?? 0,
          clicks: item?.clicks ?? 0,
          conversions: item?.conversions ?? 0,
          spend: item?.spend ?? 0,
        ),
      );
    }
    return points;
  }

  List<AdCampaign> _filteredCampaigns(AdsDashboardSnapshot snapshot) {
    final query = _searchQuery.trim().toLowerCase();
    final selectedRange = _dateRange;
    return snapshot.campaigns
        .where((campaign) {
          final matchesQuery =
              query.isEmpty ||
              campaign.name.toLowerCase().contains(query) ||
              (campaign.description ?? '').toLowerCase().contains(query);
          final matchesStatus = _selectedStatusFilters.contains(
            campaign.status.dbValue,
          );
          final matchesType =
              _typeFilter == 'Tum' || campaign.type.dbValue == _typeFilter;
          final matchesObjective =
              _objectiveFilter == 'Tum' ||
              campaign.objective.dbValue == _objectiveFilter;
          final matchesDate =
              selectedRange == null ||
              (!campaign.startsAt.isAfter(selectedRange.end) &&
                  !campaign.endsAt.isBefore(selectedRange.start));
          return matchesQuery &&
              matchesStatus &&
              matchesType &&
              matchesObjective &&
              matchesDate;
        })
        .toList(growable: false);
  }

  List<AdCampaign> _sortCampaigns(List<AdCampaign> campaigns) {
    final sorted = [...campaigns];
    sorted.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  AdMetrics _aggregateMetrics(
    List<AdCampaign> campaigns,
    Map<String, AdMetrics> metricsByCampaign,
  ) {
    return AdMetricsHelper.merge(
      campaigns.map(
        (campaign) =>
            metricsByCampaign[campaign.id] ??
            AdMetrics(campaignId: campaign.id, date: DateTime.now()),
      ),
    );
  }

  Future<void> _openCreateWizard() async {
    final sellerId = _effectiveSellerId;
    if (sellerId.isEmpty) {
      throw StateError('Satıcı kimliği bulunamadı.');
    }
    final result = await Navigator.of(context).push<AdCampaign>(
      MaterialPageRoute(
        builder: (context) => CampaignWizardPage(sellerId: sellerId),
        fullscreenDialog: true,
      ),
    );
    debugPrint(
      'Seller ads create wizard closed resultId=${result?.id ?? '(null)'} resultStatus=${result?.status.dbValue ?? '(null)'} resultSeller=${result?.sellerId ?? '(null)'} activeSeller=$_effectiveSellerId',
    );
    if (result != null) {
      _applyOptimisticCampaign(result);
      if (mounted) {
        final label = result.status == CampaignStatus.pendingReview
            ? 'Kampanya incelemeye gonderildi.'
            : 'Taslak kampanya kaydedildi.';
        // ── DIAG-6: snackbar condition ──
        debugPrint(
          '[DIAG-6-SNACKBAR] block=openCreateWizard'
          ' _tableCampaigns.length=${_tableCampaigns.length}'
          ' resultId=${result.id}'
          ' resultStatus=${result.status.dbValue}',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(label)));
      }
      unawaited(_loadCampaigns(refresh: true));
    }
  }

  Future<void> _openEditWizard(AdCampaign campaign) async {
    final result = await Navigator.of(context).push<AdCampaign>(
      MaterialPageRoute(
        builder: (context) => CampaignWizardPage(
          sellerId: _effectiveSellerId,
          existingCampaign: campaign,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result != null) {
      _applyOptimisticCampaign(result);
      unawaited(_loadCampaigns(refresh: true));
    }
  }

  Future<void> _openDetail(AdCampaign campaign) async {
    await showDialog<void>(
      context: context,
      builder: (context) => CampaignDetailDialog(
        campaign: campaign,
        onChanged: () => _loadCampaigns(refresh: true),
      ),
    );
  }

  Future<void> _pauseCampaign(AdCampaign campaign) async {
    await _campaignService.pauseCampaign(campaign.id);
    _rememberCampaign(
      campaign.copyWith(
        status: CampaignStatus.paused,
        pausedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    unawaited(_loadCampaigns(refresh: true));
  }

  Future<void> _resumeCampaign(AdCampaign campaign) async {
    await _campaignService.resumeCampaign(campaign.id);
    _rememberCampaign(
      campaign.copyWith(
        status: CampaignStatus.active,
        updatedAt: DateTime.now(),
      ),
    );
    unawaited(_loadCampaigns(refresh: true));
  }

  Future<void> _deleteCampaign(AdCampaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kampanyayi sil'),
        content: Text('${campaign.name} kalici olarak silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _campaignService.deleteCampaign(campaign.id);
    _sessionCampaigns.remove(campaign.id);
    setState(() {
      _campaigns = _campaigns
          .where((item) => item.id != campaign.id)
          .toList(growable: false);
    });
    unawaited(_loadCampaigns(refresh: true));
  }
}

class _SellerAdsViewData {
  const _SellerAdsViewData({
    required this.snapshot,
    required this.dailyMetrics,
    required this.metricsByCampaign,
    required this.healthByCampaign,
    required this.bestCampaign,
  });

  final AdsDashboardSnapshot snapshot;
  final List<AdMetrics> dailyMetrics;
  final Map<String, AdMetrics> metricsByCampaign;
  final Map<String, AdHealthScore> healthByCampaign;
  final AdCampaign? bestCampaign;
}

class _SellerCampaignRow {
  const _SellerCampaignRow({
    required this.campaign,
    required this.metrics,
    required this.health,
  });

  final AdCampaign campaign;
  final AdMetrics metrics;
  final AdHealthScore? health;
}

class _DailyPerformancePoint {
  const _DailyPerformancePoint({
    required this.day,
    required this.impressions,
    required this.clicks,
    required this.conversions,
    required this.spend,
  });

  final DateTime day;
  final int impressions;
  final int clicks;
  final int conversions;
  final double spend;
}

class _PerformanceLineChartPainter extends CustomPainter {
  const _PerformanceLineChartPainter({required this.points});

  final List<_DailyPerformancePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const padding = 20.0;
    final chartWidth = size.width - (padding * 2);
    final chartHeight = size.height - (padding * 2);
    final maxValue = math
        .max(1, points.map((item) => item.impressions).fold<int>(0, math.max))
        .toDouble();

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = padding + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    final fillPath = Path();
    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = padding + (chartWidth * i / math.max(points.length - 1, 1));
      final y =
          padding +
          chartHeight -
          ((point.impressions / maxValue) * chartHeight);
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height - padding);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width - padding, size.height - padding);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x332563EB), Color(0x052563EB)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF2563EB);
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = padding + (chartWidth * i / math.max(points.length - 1, 1));
      final y =
          padding +
          chartHeight -
          ((point.impressions / maxValue) * chartHeight);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PerformanceLineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _MiniBarChartPainter extends CustomPainter {
  const _MiniBarChartPainter({required this.points});

  final List<_DailyPerformancePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxSpend = math.max(
      1.0,
      points.map((item) => item.spend).fold<double>(0, math.max),
    );
    final barWidth = size.width / (points.length * 1.8);
    final paint = Paint()..color = const Color(0xFF7C3AED);
    final fadedPaint = Paint()..color = const Color(0x337C3AED);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final left = i * (barWidth * 1.8);
      final height = (point.spend / maxSpend) * (size.height - 8);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - height, barWidth, height),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, point.spend > 0 ? paint : fadedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBarChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _RingGaugePainter extends CustomPainter {
  const _RingGaugePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 12.0;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final background = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final foreground = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
