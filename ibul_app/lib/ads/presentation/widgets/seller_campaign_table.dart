import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../enums/ad_enums.dart';
import '../../models/ad_campaign.dart';
import '../../models/ad_health_score.dart';
import '../../models/ad_metrics.dart';
import 'campaign_action_menu.dart';
import 'status_chip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Row data model
// ─────────────────────────────────────────────────────────────────────────────

class SellerCampaignTableRow {
  const SellerCampaignTableRow({
    required this.campaign,
    required this.metrics,
    this.health,
  });

  final AdCampaign campaign;
  final AdMetrics metrics;
  final AdHealthScore? health;
}

// ─────────────────────────────────────────────────────────────────────────────
// Column definition — config-driven
// Each column: id, two-layer label (TR + EN), width, numeric flag, sortable flag
// ─────────────────────────────────────────────────────────────────────────────

typedef CampaignTableCellBuilder =
    Widget Function(
      BuildContext context,
      SellerCampaignTableRow row,
      String currency,
    );

class CampaignTableColumnDef {
  const CampaignTableColumnDef({
    required this.id,
    required this.labelTr,
    required this.labelEn,
    required this.cellBuilder,
    this.width = 120.0,
    this.minWidth = 72.0,
    this.numeric = false,
    this.sortable = true,
    this.reorderable = true,
  });

  final String id;
  final String labelTr;
  final String labelEn;
  final CampaignTableCellBuilder cellBuilder;
  final double width;
  final double minWidth;
  final bool numeric;
  final bool sortable;

  /// False for fixed columns like 'actions'.
  final bool reorderable;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class SellerCampaignTable extends StatefulWidget {
  const SellerCampaignTable({
    required this.rows,
    required this.currency,
    required this.visibleColumnIds,
    required this.optionalColumnIds,
    this.selectionMode = false,
    this.selectedCampaignIds = const <String>{},
    this.sortColumnId,
    this.sortAscending = true,
    this.onSortChanged,
    this.pageIndex = 0,
    this.pageSize = 10,
    this.totalRowCount = 0,
    this.onPageChanged,
    this.onPageSizeChanged,
    this.onEdit,
    this.onDetail,
    this.onPause,
    this.onResume,
    this.onDelete,
    this.onSelectionChanged,
    this.onSelectAllChanged,
    super.key,
  });

  final List<SellerCampaignTableRow> rows;
  final String currency;

  /// IDs of the non-optional columns that should currently be visible.
  final Set<String> visibleColumnIds;

  /// IDs of optional/extra-metric columns currently enabled by the user.
  final Set<String> optionalColumnIds;
  final bool selectionMode;
  final Set<String> selectedCampaignIds;

  final String? sortColumnId;
  final bool sortAscending;
  final ValueChanged<String>? onSortChanged;

  final int pageIndex;
  final int pageSize;
  final int totalRowCount;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int?>? onPageSizeChanged;

  final void Function(AdCampaign campaign)? onEdit;
  final void Function(AdCampaign campaign)? onDetail;
  final void Function(AdCampaign campaign)? onPause;
  final void Function(AdCampaign campaign)? onResume;
  final void Function(AdCampaign campaign)? onDelete;
  final void Function(String campaignId, bool selected)? onSelectionChanged;
  final ValueChanged<bool>? onSelectAllChanged;

  @override
  State<SellerCampaignTable> createState() => _SellerCampaignTableState();
}

class _SellerCampaignTableState extends State<SellerCampaignTable> {
  final ScrollController _horizHeader = ScrollController();
  final ScrollController _horizBody = ScrollController();
  final ScrollController _vert = ScrollController();
  bool _syncing = false;
  String? _hoveredId;

  // Drag-reorder state: ordered list of visible column IDs (excluding 'actions').
  List<String>? _columnOrder;

  // Per-column width overrides set by the user via resize drag.
  final Map<String, double> _widthOverrides = {};
  String? _resizingId;
  double _resizeDragStartX = 0;
  double _resizeDragStartWidth = 0;

  // Layout constants
  static const double _headerHeight = 58.0;
  static const double _rowHeight = 52.0;
  static const double _footerHeight = 52.0;
  static const double _bodyMin = 208.0;
  static const double _bodyMax = 468.0;
  static const double _cellPaddingH = 10.0;

  @override
  void initState() {
    super.initState();
    // Body drives horizontal scroll; header mirrors it.
    _horizBody.addListener(_syncHeader);
  }

  @override
  void dispose() {
    _horizBody.removeListener(_syncHeader);
    _horizHeader.dispose();
    _horizBody.dispose();
    _vert.dispose();
    super.dispose();
  }

  void _syncHeader() {
    if (_syncing) return;
    _syncing = true;
    if (_horizHeader.hasClients) {
      _horizHeader.jumpTo(_horizBody.offset);
    }
    _syncing = false;
  }

  // ─── Number / date formatters ───────────────────────────────────────────────

  static String _fmtInt(int v) {
    if (v == 0) return '-';
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _fmtMoney(double v, String cur) {
    if (v == 0) return '-';
    final whole = v.truncate();
    final cents = ((v - whole) * 100).round();
    final w = _fmtInt(whole);
    return cents == 0
        ? '$w $cur'
        : '$w,${cents.toString().padLeft(2, '0')} $cur';
  }

  static String _fmtPct(double v) {
    if (v == 0) return '-';
    return '%${(v * 100).toStringAsFixed(2).replaceAll('.', ',')}';
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  static String _typeLabel(AdCampaignType t) => switch (t) {
    AdCampaignType.productBoost => 'Ürün Boost',
    AdCampaignType.storeBoost => 'Mağaza Boost',
    AdCampaignType.collectionBoost => 'Liste Boost',
    AdCampaignType.geoPush => 'Konum Push',
    AdCampaignType.banner => 'Banner',
    AdCampaignType.categorySponsor => 'Kat. Sponsor',
  };

  // ─── Column definitions ─────────────────────────────────────────────────────
  //
  // To add a future KPI column:
  //   1. Add a new CampaignTableColumnDef entry here.
  //   2. If optional, add its id to _optionalIds below.
  //   3. Add it to _defaultVisibleColumnIds or optionalColumnIds in the parent.
  // ─────────────────────────────────────────────────────────────────────────────

  List<CampaignTableColumnDef> _buildAllColumns() {
    return [
      CampaignTableColumnDef(
        id: 'actions',
        labelTr: '',
        labelEn: '',
        width: 56,
        minWidth: 56,
        sortable: false,
        reorderable: false,
        cellBuilder: (ctx, row, _) {
          if (widget.selectionMode) {
            return Center(
              child: Checkbox(
                value: widget.selectedCampaignIds.contains(row.campaign.id),
                onChanged: (value) {
                  widget.onSelectionChanged?.call(
                    row.campaign.id,
                    value ?? false,
                  );
                },
              ),
            );
          }
          return CampaignActionMenu(
            isPaused: row.campaign.status == CampaignStatus.paused,
            onDetail: widget.onDetail != null
                ? () => widget.onDetail!(row.campaign)
                : null,
            onEdit: widget.onEdit != null
                ? () => widget.onEdit!(row.campaign)
                : null,
            onPause: widget.onPause != null
                ? () => widget.onPause!(row.campaign)
                : null,
            onResume: widget.onResume != null
                ? () => widget.onResume!(row.campaign)
                : null,
            onDelete: widget.onDelete != null
                ? () => widget.onDelete!(row.campaign)
                : null,
          );
        },
      ),
      // date first (UX requirement)
      CampaignTableColumnDef(
        id: 'date',
        labelTr: 'Tarih',
        labelEn: 'Date',
        width: 96,
        minWidth: 80,
        sortable: true,
        cellBuilder: (ctx, row, _) => Text(
          _fmtDate(row.campaign.updatedAt ?? row.campaign.createdAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ),
      CampaignTableColumnDef(
        id: 'name',
        labelTr: 'Reklam adı',
        labelEn: 'Ad name',
        width: 180,
        minWidth: 120,
        sortable: true,
        cellBuilder: (ctx, row, _) => Text(
          row.campaign.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      CampaignTableColumnDef(
        id: 'type',
        labelTr: 'Kampanya türü',
        labelEn: 'Type',
        width: 116,
        minWidth: 88,
        sortable: true,
        cellBuilder: (ctx, row, _) => Text(
          _typeLabel(row.campaign.type),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
        ),
      ),
      CampaignTableColumnDef(
        id: 'status',
        labelTr: 'Durum',
        labelEn: 'Status',
        width: 130,
        minWidth: 100,
        sortable: true,
        cellBuilder: (ctx, row, _) =>
            StatusChip.fromStatus(row.campaign.status.dbValue),
      ),
      CampaignTableColumnDef(
        id: 'spend',
        labelTr: 'Harcanan tutar',
        labelEn: 'Adspend',
        width: 120,
        minWidth: 88,
        numeric: true,
        sortable: true,
        cellBuilder: (ctx, row, c) {
          final v = row.metrics.spend > 0
              ? row.metrics.spend
              : row.campaign.spentAmount;
          return Text(
            _fmtMoney(v, c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          );
        },
      ),
      CampaignTableColumnDef(
        id: 'impressions',
        labelTr: 'Görüntülenme',
        labelEn: 'Impr',
        width: 100,
        minWidth: 72,
        numeric: true,
        sortable: true,
        cellBuilder: (ctx, row, _) => Text(
          _fmtInt(row.metrics.impressions),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
      CampaignTableColumnDef(
        id: 'cpm',
        labelTr: '1K kişi maliyeti',
        labelEn: 'CPM',
        width: 110,
        minWidth: 80,
        numeric: true,
        sortable: true,
        cellBuilder: (ctx, row, c) => Text(
          _fmtMoney(row.metrics.cpm, c),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
      CampaignTableColumnDef(
        id: 'clicks',
        labelTr: 'Tıklama sayısı',
        labelEn: 'Clicks',
        width: 86,
        minWidth: 64,
        numeric: true,
        sortable: true,
        cellBuilder: (ctx, row, _) => Text(
          _fmtInt(row.metrics.clicks),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
      CampaignTableColumnDef(
        id: 'ctr',
        labelTr: 'Tıklama oranı',
        labelEn: 'CTR',
        width: 86,
        minWidth: 64,
        numeric: true,
        sortable: true,
        cellBuilder: (ctx, row, _) => Text(
          _fmtPct(row.metrics.ctr),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
      CampaignTableColumnDef(
        id: 'cpc',
        labelTr: 'Tıklama maliyeti',
        labelEn: 'CPC',
        width: 110,
        minWidth: 80,
        numeric: true,
        sortable: true,
        cellBuilder: (ctx, row, c) => Text(
          _fmtMoney(row.metrics.cpc, c),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
      // ── Optional metrics ────────────────────────────────────────────────────
      CampaignTableColumnDef(
        id: 'favorites',
        labelTr: 'Beğenme',
        labelEn: 'Likes',
        width: 86,
        minWidth: 64,
        numeric: true,
        cellBuilder: (ctx, row, _) => Text(
          _fmtInt(row.metrics.favorites),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
      CampaignTableColumnDef(
        id: 'add_to_carts',
        labelTr: 'Sepete ekleme',
        labelEn: 'Add to cart',
        width: 104,
        minWidth: 80,
        numeric: true,
        cellBuilder: (ctx, row, _) => Text(
          _fmtInt(row.metrics.addToCarts),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
      CampaignTableColumnDef(
        id: 'store_visits',
        labelTr: 'Mağaza inceleme',
        labelEn: 'Store visits',
        width: 112,
        minWidth: 88,
        numeric: true,
        cellBuilder: (ctx, row, _) => Text(
          _fmtInt(row.metrics.storeVisits),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
      CampaignTableColumnDef(
        id: 'conversions',
        labelTr: 'Dönüşüm',
        labelEn: 'Conv',
        width: 100,
        minWidth: 72,
        numeric: true,
        cellBuilder: (ctx, row, _) => Text(
          _fmtInt(row.metrics.conversions),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        ),
      ),
    ];
  }

  static const _optionalIds = <String>{
    'favorites',
    'add_to_carts',
    'store_visits',
    'conversions',
  };

  // Returns the default ordered list of visible column IDs (excluding fixed cols).
  List<String> _computeInitialOrder(List<CampaignTableColumnDef> all) {
    final result = <String>[];
    for (final col in all) {
      if (!col.reorderable) continue;
      if (_optionalIds.contains(col.id)) {
        if (widget.optionalColumnIds.contains(col.id)) result.add(col.id);
      } else if (widget.visibleColumnIds.contains(col.id)) {
        result.add(col.id);
      }
    }
    return result;
  }

  // Final ordered list with user width overrides applied; fixed columns stay first.
  List<CampaignTableColumnDef> _orderedVisibleColumns(
    List<CampaignTableColumnDef> all,
  ) {
    final byId = {for (final c in all) c.id: c};
    final order = _columnOrder ?? _computeInitialOrder(all);
    final result = <CampaignTableColumnDef>[];
    final actions = byId['actions'];
    if (actions != null) {
      result.add(actions);
    }
    for (final id in order) {
      final col = byId[id];
      if (col == null) continue;
      final override = _widthOverrides[id];
      result.add(override == null ? col : _withWidth(col, override));
    }
    return result;
  }

  static CampaignTableColumnDef _withWidth(
    CampaignTableColumnDef col,
    double w,
  ) {
    return CampaignTableColumnDef(
      id: col.id,
      labelTr: col.labelTr,
      labelEn: col.labelEn,
      cellBuilder: col.cellBuilder,
      width: w,
      minWidth: col.minWidth,
      numeric: col.numeric,
      sortable: col.sortable,
      reorderable: col.reorderable,
    );
  }

  // Keep _columnOrder in sync when visible props change (prune removed, append new).
  void _syncOrderToProps(List<CampaignTableColumnDef> all) {
    if (_columnOrder == null) return;
    final valid = _computeInitialOrder(all);
    final validSet = valid.toSet();
    final pruned = _columnOrder!.where(validSet.contains).toList();
    for (final id in valid) {
      if (!pruned.contains(id)) pruned.add(id);
    }
    if (pruned.length != _columnOrder!.length ||
        !pruned.every(_columnOrder!.contains)) {
      _columnOrder = pruned;
    }
  }

  void _applyReorder(String fromId, String toId) {
    if (_columnOrder == null) return;
    final order = List<String>.from(_columnOrder!);
    final fromIdx = order.indexOf(fromId);
    final toIdx = order.indexOf(toId);
    if (fromIdx == -1 || toIdx == -1 || fromIdx == toIdx) return;
    order.removeAt(fromIdx);
    order.insert(toIdx, fromId);
    setState(() => _columnOrder = order);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final all = _buildAllColumns();
    _syncOrderToProps(all);
    _columnOrder ??= _computeInitialOrder(all);
    final cols = _orderedVisibleColumns(all);
    final totalWidth = cols.fold<double>(0, (sum, c) => sum + c.width);
    final bodyHeight = math.max(
      _bodyMin,
      math.min(_bodyMax, _rowHeight * widget.rows.length),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill available width when columns are narrower than the viewport;
        // fall back to totalWidth so horizontal scroll still works when wider.
        final effectiveBodyWidth = constraints.maxWidth > 0
            ? math.max(totalWidth, constraints.maxWidth)
            : totalWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(cols, effectiveBodyWidth),
                SizedBox(
                  height: bodyHeight,
                  child: Scrollbar(
                    controller: _vert,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizBody,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: effectiveBodyWidth,
                        child: ListView.builder(
                          controller: _vert,
                          itemCount: widget.rows.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (ctx, i) =>
                              _buildDataRow(ctx, widget.rows[i], cols, i),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(List<CampaignTableColumnDef> cols, double totalWidth) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        controller: _horizHeader,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: totalWidth,
          height: _headerHeight,
          child: Row(
            children: cols
                .map((col) {
                  if (!col.reorderable) return _buildStaticHeaderCell(col);
                  return _buildReorderableHeaderCell(col);
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  Widget _buildReorderableHeaderCell(CampaignTableColumnDef col) {
    final isSorted = widget.sortColumnId == col.id;
    return Draggable<String>(
      data: col.id,
      axis: Axis.horizontal,
      feedback: _buildDragFeedback(col),
      childWhenDragging: _buildDraggingPlaceholder(col),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != col.id,
        onAcceptWithDetails: (d) => _applyReorder(d.data, col.id),
        builder: (ctx, candidateData, _) => _buildHeaderCellContent(
          col,
          isSorted: isSorted,
          dropIndicator: candidateData.isNotEmpty,
        ),
      ),
    );
  }

  Widget _buildDragFeedback(CampaignTableColumnDef col) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: col.width,
        height: _headerHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF3B82F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A3B82F6),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: _cellPaddingH,
          vertical: 8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: col.numeric
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              col.labelTr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              col.labelEn,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggingPlaceholder(CampaignTableColumnDef col) {
    return Container(
      width: col.width,
      height: _headerHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildHeaderCellContent(
    CampaignTableColumnDef col, {
    required bool isSorted,
    required bool dropIndicator,
  }) {
    final labelContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: col.numeric
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (col.labelTr.isNotEmpty)
          Text(
            col.labelTr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isSorted
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF94A3B8),
            ),
          ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                col.labelEn,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSorted
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF334155),
                ),
              ),
            ),
            if (col.sortable && widget.onSortChanged != null) ...[
              const SizedBox(width: 2),
              Icon(
                isSorted
                    ? (widget.sortAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 11,
                color: isSorted
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFCBD5E1),
              ),
            ],
          ],
        ),
      ],
    );

    return GestureDetector(
      onTap: col.sortable && widget.onSortChanged != null
          ? () => widget.onSortChanged!(col.id)
          : null,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Container(
            width: col.width,
            height: _headerHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: _cellPaddingH,
              vertical: 8,
            ),
            alignment: col.numeric
                ? Alignment.centerRight
                : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: dropIndicator
                  ? const Color(0xFFDBEAFE)
                  : isSorted
                  ? const Color(0xFFEFF6FF)
                  : Colors.transparent,
              border: Border(
                right: BorderSide(
                  color: dropIndicator
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFE2E8F0),
                  width: dropIndicator ? 2 : 1,
                ),
                bottom: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: labelContent,
          ),
          // Resize handle glued to the right edge of each header cell.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _ResizeHandle(
              onDragStart: (globalX) {
                _resizingId = col.id;
                _resizeDragStartX = globalX;
                _resizeDragStartWidth = _widthOverrides[col.id] ?? col.width;
              },
              onDragUpdate: (globalX) {
                if (_resizingId != col.id) return;
                final delta = globalX - _resizeDragStartX;
                final newW = (_resizeDragStartWidth + delta).clamp(
                  col.minWidth,
                  600.0,
                );
                setState(() => _widthOverrides[col.id] = newW);
              },
              onDragEnd: () => _resizingId = null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticHeaderCell(CampaignTableColumnDef col) {
    if (col.id == 'actions') {
      if (!widget.selectionMode) {
        return Container(
          width: col.width,
          height: _headerHeight,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(
              right: BorderSide(color: Color(0xFFE2E8F0)),
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: TextButton(
            onPressed: widget.onSelectAllChanged == null
                ? null
                : () => widget.onSelectAllChanged!(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7A2FF4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Text('SEÇ'),
          ),
        );
      }

      final selectableIds = widget.rows
          .map((row) => row.campaign.id)
          .where((id) => id.isNotEmpty)
          .toSet();
      final selectedCount = selectableIds
          .where(widget.selectedCampaignIds.contains)
          .length;
      final allSelected =
          selectableIds.isNotEmpty && selectedCount == selectableIds.length;
      final partiallySelected =
          selectedCount > 0 && selectedCount < selectableIds.length;
      return Container(
        width: col.width,
        height: _headerHeight,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(
            right: BorderSide(color: Color(0xFFE2E8F0)),
            bottom: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Checkbox(
          value: allSelected ? true : (partiallySelected ? null : false),
          tristate: true,
          onChanged: selectableIds.isEmpty
              ? null
              : (value) => widget.onSelectAllChanged?.call(value == true),
        ),
      );
    }

    return Container(
      width: col.width,
      height: _headerHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  // ─── Data rows ─────────────────────────────────────────────────────────────

  Widget _buildDataRow(
    BuildContext ctx,
    SellerCampaignTableRow row,
    List<CampaignTableColumnDef> cols,
    int index,
  ) {
    final id = row.campaign.id;
    final isHovered = _hoveredId == id;
    final bg = isHovered
        ? const Color(0xFFF1F5F9)
        : index.isEven
        ? Colors.white
        : const Color(0xFFFBFDFF);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredId = id),
      onExit: (_) {
        if (_hoveredId == id) setState(() => _hoveredId = null);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: bg,
        height: _rowHeight,
        child: Row(
          children: cols
              .map((c) => _buildDataCell(ctx, row, c))
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildDataCell(
    BuildContext ctx,
    SellerCampaignTableRow row,
    CampaignTableColumnDef col,
  ) {
    return Container(
      width: col.width,
      height: _rowHeight,
      padding: EdgeInsets.symmetric(
        horizontal: _cellPaddingH,
        vertical: col.id == 'status' ? 8 : 10,
      ),
      alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFEEF2F7)),
          bottom: BorderSide(color: Color(0xFFEEF2F7)),
        ),
      ),
      child: col.cellBuilder(ctx, row, widget.currency),
    );
  }

  // ─── Footer / pagination ───────────────────────────────────────────────────

  Widget _buildFooter() {
    const pageSizes = <int>[10, 25, 50];
    final resolvedSize = pageSizes.contains(widget.pageSize)
        ? widget.pageSize
        : pageSizes.first;
    final totalPages = widget.pageSize <= 0
        ? 1
        : ((widget.totalRowCount + widget.pageSize - 1) / widget.pageSize)
              .ceil()
              .clamp(1, 999999);
    final canBack = widget.pageIndex > 0;
    final canNext = widget.pageIndex + 1 < totalPages;
    final start = widget.totalRowCount == 0
        ? 0
        : widget.pageIndex * widget.pageSize + 1;
    final end = (widget.pageIndex * widget.pageSize + widget.rows.length).clamp(
      0,
      widget.totalRowCount,
    );

    return Container(
      height: _footerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFFCFDFF),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            '$start \u2013 $end / ${widget.totalRowCount}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD9E2EC)),
            ),
            child: DropdownButton<int>(
              value: resolvedSize,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              isDense: true,
              items: pageSizes
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text('$s sat\u0131r'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: widget.onPageSizeChanged,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '\u00d6nceki sayfa',
            visualDensity: VisualDensity.compact,
            onPressed: canBack
                ? () => widget.onPageChanged?.call(widget.pageIndex - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
          ),
          Text(
            '${widget.pageIndex + 1} / $totalPages',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          IconButton(
            tooltip: 'Sonraki sayfa',
            visualDensity: VisualDensity.compact,
            onPressed: canNext
                ? () => widget.onPageChanged?.call(widget.pageIndex + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resize handle — separate StatefulWidget so its GestureDetector does not
// conflict with the parent Draggable when both target horizontal drag events.
// ─────────────────────────────────────────────────────────────────────────────

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final void Function(double globalX) onDragStart;
  final void Function(double globalX) onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => widget.onDragStart(d.globalPosition.dx),
        onHorizontalDragUpdate: (d) => widget.onDragUpdate(d.globalPosition.dx),
        onHorizontalDragEnd: (_) => widget.onDragEnd(),
        child: SizedBox(
          width: 8,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 2,
              height: _hovered ? 28 : 18,
              decoration: BoxDecoration(
                color: _hovered
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
