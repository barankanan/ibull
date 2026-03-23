import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AdsTableDensity { compact, comfortable, spacious }

class AdsTableColumn<T> {
  const AdsTableColumn({
    required this.id,
    required this.label,
    required this.cellBuilder,
    this.width = 140,
    this.minWidth = 80,
    this.numeric = false,
    this.reorderable = true,
    this.resizable = true,
  });

  final String id;
  final String label;
  final Widget Function(BuildContext context, T row) cellBuilder;
  final double width;
  final double minWidth;
  final bool numeric;
  final bool reorderable;
  final bool resizable;
}

class AdsDataTable<T> extends StatefulWidget {
  const AdsDataTable({
    required this.rows,
    required this.columns,
    this.mobileCardBuilder,
    this.rowIdBuilder,
    this.selectedRowIds = const <String>{},
    this.onSelectionChanged,
    this.showCheckboxes = false,
    this.sortColumnId,
    this.sortAscending = true,
    this.onSortChanged,
    this.pageIndex = 0,
    this.pageSize = 10,
    this.totalRowCount = 0,
    this.onPageChanged,
    this.onPageSizeChanged,
    this.tableHeight = 560,
    this.emptyTitle = 'Kayit yok',
    this.emptySubtitle = 'Filtreleri degistirerek tekrar deneyin.',
    this.density = AdsTableDensity.comfortable,
    this.enableInteractiveColumns = false,
    super.key,
  });

  final List<T> rows;
  final List<AdsTableColumn<T>> columns;
  final Widget Function(BuildContext context, T row)? mobileCardBuilder;
  final String Function(T row)? rowIdBuilder;
  final Set<String> selectedRowIds;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final bool showCheckboxes;
  final String? sortColumnId;
  final bool sortAscending;
  final ValueChanged<String>? onSortChanged;
  final int pageIndex;
  final int pageSize;
  final int totalRowCount;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int?>? onPageSizeChanged;
  final double tableHeight;
  final String emptyTitle;
  final String emptySubtitle;
  final AdsTableDensity density;
  final bool enableInteractiveColumns;

  @override
  State<AdsDataTable<T>> createState() => _AdsDataTableState<T>();
}

class _AdsDataTableState<T> extends State<AdsDataTable<T>> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  static const double _selectionColumnWidth = 48;
  static const double _defaultFooterHeight = 58;
  static const double _minimumBodyHeight = 180;

  List<String> _columnOrder = <String>[];
  Map<String, double> _columnWidths = <String, double>{};
  String? _dragTargetColumnId;
  String? _hoveredRowId;

  @override
  void initState() {
    super.initState();
    _syncColumnState();
  }

  @override
  void didUpdateWidget(covariant AdsDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncColumnState();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _syncColumnState() {
    final incomingIds = widget.columns.map((column) => column.id).toList();
    final preservedOrder = _columnOrder
        .where(incomingIds.contains)
        .toList(growable: true);

    for (final id in incomingIds) {
      if (!preservedOrder.contains(id)) {
        preservedOrder.add(id);
      }
    }

    final nextWidths = <String, double>{};
    for (final column in widget.columns) {
      final currentWidth = _columnWidths[column.id] ?? column.width;
      nextWidths[column.id] = math.max(column.minWidth, currentWidth);
    }

    _columnOrder = preservedOrder;
    _columnWidths = nextWidths;
  }

  List<AdsTableColumn<T>> get _orderedColumns {
    final columnsById = <String, AdsTableColumn<T>>{
      for (final column in widget.columns) column.id: column,
    };
    return _columnOrder
        .where(columnsById.containsKey)
        .map((id) => columnsById[id]!)
        .toList(growable: false);
  }

  double _columnWidth(AdsTableColumn<T> column) {
    final width = _columnWidths[column.id] ?? column.width;
    return math.max(column.minWidth, width);
  }

  String _rowId(T row, int index) {
    return widget.rowIdBuilder?.call(row) ?? 'row-$index';
  }

  void _resizeColumn(AdsTableColumn<T> column, double delta) {
    setState(() {
      final nextWidth = _columnWidth(column) + delta;
      _columnWidths[column.id] = math.max(column.minWidth, nextWidth);
    });
  }

  void _resetColumnWidth(AdsTableColumn<T> column) {
    setState(() {
      _columnWidths[column.id] = column.width;
    });
  }

  void _moveColumn(String draggedId, String targetId) {
    if (draggedId == targetId) {
      return;
    }

    final draggedColumn = _columnById(draggedId);
    final targetColumn = _columnById(targetId);
    if (draggedColumn == null ||
        targetColumn == null ||
        !draggedColumn.reorderable ||
        !targetColumn.reorderable) {
      return;
    }

    final fromIndex = _columnOrder.indexOf(draggedId);
    final toIndex = _columnOrder.indexOf(targetId);
    if (fromIndex == -1 || toIndex == -1) {
      return;
    }

    final nextOrder = List<String>.of(_columnOrder);
    final movedId = nextOrder.removeAt(fromIndex);
    nextOrder.insert(toIndex, movedId);

    setState(() {
      _columnOrder = nextOrder;
      _dragTargetColumnId = null;
    });
  }

  AdsTableColumn<T>? _columnById(String id) {
    for (final column in widget.columns) {
      if (column.id == id) {
        return column;
      }
    }
    return null;
  }

  bool get _allVisibleRowsSelected {
    if (!widget.showCheckboxes || widget.rows.isEmpty) {
      return false;
    }
    for (var index = 0; index < widget.rows.length; index++) {
      if (!widget.selectedRowIds.contains(_rowId(widget.rows[index], index))) {
        return false;
      }
    }
    return true;
  }

  bool get _someVisibleRowsSelected {
    if (!widget.showCheckboxes || widget.rows.isEmpty) {
      return false;
    }
    var anySelected = false;
    var anyUnselected = false;
    for (var index = 0; index < widget.rows.length; index++) {
      final isSelected = widget.selectedRowIds.contains(
        _rowId(widget.rows[index], index),
      );
      anySelected = anySelected || isSelected;
      anyUnselected = anyUnselected || !isSelected;
    }
    return anySelected && anyUnselected;
  }

  void _toggleAllVisibleRows(bool selectAll) {
    if (widget.onSelectionChanged == null) {
      return;
    }
    final next = Set<String>.from(widget.selectedRowIds);
    for (var index = 0; index < widget.rows.length; index++) {
      final id = _rowId(widget.rows[index], index);
      if (selectAll) {
        next.add(id);
      } else {
        next.remove(id);
      }
    }
    widget.onSelectionChanged!(next);
  }

  void _toggleRowSelection(String rowId, bool selected) {
    if (widget.onSelectionChanged == null) {
      return;
    }
    final next = Set<String>.from(widget.selectedRowIds);
    if (selected) {
      next.add(rowId);
    } else {
      next.remove(rowId);
    }
    widget.onSelectionChanged!(next);
  }

  int get _pageStart =>
      widget.totalRowCount == 0 ? 0 : (widget.pageIndex * widget.pageSize) + 1;

  int get _pageEnd {
    final rawEnd = (widget.pageIndex * widget.pageSize) + widget.rows.length;
    return rawEnd > widget.totalRowCount ? widget.totalRowCount : rawEnd;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 46,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              widget.emptyTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.emptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCards =
            constraints.maxWidth < 880 && widget.mobileCardBuilder != null;
        if (useCards) {
          return Column(
            children: widget.rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: widget.mobileCardBuilder!(context, row),
                  ),
                )
                .toList(growable: false),
          );
        }

        final resolvedFooterHeight = _resolvedFooterHeight(
          constraints.maxWidth,
        );
        final resolvedTableHeight = _resolvedTableHeight(
          constraints.maxWidth,
          resolvedFooterHeight,
        );
        debugPrint(
          '[DIAG-4-ADSTABLE] rows=${widget.rows.length}'
          ' constraints=$constraints'
          ' resolvedHeight=$resolvedTableHeight',
        );
        return SizedBox(
          height: resolvedTableHeight,
          child: widget.enableInteractiveColumns
              ? _buildInteractiveTable(
                  context,
                  tableHeight: resolvedTableHeight,
                  footerHeight: resolvedFooterHeight,
                )
              : _buildClassicTable(context),
        );
      },
    );
  }

  double _resolvedFooterHeight(double maxWidth) {
    return maxWidth < 720 ? 88.0 : _defaultFooterHeight;
  }

  double _resolvedTableHeight(double maxWidth, double footerHeight) {
    final headerHeight = widget.density.headingRowHeight;
    final minimumHeight = headerHeight + footerHeight + _minimumBodyHeight;
    return math.max(widget.tableHeight, minimumHeight);
  }

  Widget _buildClassicTable(BuildContext context) {
    return _buildTableShell(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Theme(
            data: Theme.of(
              context,
            ).copyWith(dividerColor: const Color(0xFFE2E8F0)),
            child: DataTable(
              headingRowHeight: widget.density.headingRowHeight,
              dataRowMinHeight: widget.density.dataRowMinHeight,
              dataRowMaxHeight: widget.density.dataRowMaxHeight,
              horizontalMargin: widget.density.horizontalMargin,
              columnSpacing: widget.density.columnSpacing,
              columns: widget.columns
                  .map(
                    (column) => DataColumn(
                      numeric: column.numeric,
                      label: SizedBox(
                        width: column.width,
                        child: Text(
                          column.label,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
              rows: widget.rows
                  .map(
                    (row) => DataRow(
                      cells: widget.columns
                          .map(
                            (column) => DataCell(
                              SizedBox(
                                width: column.width,
                                child: column.cellBuilder(context, row),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveTable(
    BuildContext context, {
    required double tableHeight,
    required double footerHeight,
  }) {
    final orderedColumns = _orderedColumns;
    final totalWidth =
        orderedColumns.fold<double>(
          widget.showCheckboxes ? _selectionColumnWidth : 0,
          (sum, column) => sum + _columnWidth(column),
        ) +
        1;
    final headerHeight = widget.density.headingRowHeight;
    final bodyHeight = math.max<double>(
      _minimumBodyHeight,
      tableHeight - headerHeight - footerHeight,
    );

    return _buildTableShell(
      child: Column(
        children: [
          SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: _buildHeaderRow(orderedColumns),
            ),
          ),
          SizedBox(
            height: bodyHeight,
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  child: ListView.builder(
                    controller: _verticalController,
                    itemCount: widget.rows.length,
                    itemBuilder: (context, index) => _buildDataRow(
                      context,
                      widget.rows[index],
                      orderedColumns,
                      index,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildTableShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9E2EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
    );
  }

  Widget _buildHeaderRow(List<AdsTableColumn<T>> columns) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showCheckboxes) _buildSelectionHeaderCell(),
        ...columns.map(_buildHeaderCell),
      ],
    );
  }

  Widget _buildSelectionHeaderCell() {
    return Container(
      width: _selectionColumnWidth,
      height: widget.density.headingRowHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(color: Color(0xFFD9E2EC)),
          bottom: BorderSide(color: Color(0xFFD9E2EC)),
        ),
      ),
      child: Center(
        child: Checkbox(
          value: _allVisibleRowsSelected,
          tristate: true,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF2563EB);
            }
            return Colors.white;
          }),
          onChanged: widget.onSelectionChanged == null
              ? null
              : (value) =>
                    _toggleAllVisibleRows(value ?? !_someVisibleRowsSelected),
          isError: false,
        ),
      ),
    );
  }

  Widget _buildHeaderCell(AdsTableColumn<T> column) {
    final width = _columnWidth(column);
    final isDropTarget = _dragTargetColumnId == column.id;
    final isSorted = widget.sortColumnId == column.id;
    final textAlign = column.numeric ? TextAlign.right : TextAlign.left;

    final labelRow = Row(
      mainAxisAlignment: column.numeric
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            column.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: TextStyle(
              color: column.label.isEmpty
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (widget.onSortChanged != null && column.label.isNotEmpty) ...[
          const SizedBox(width: 6),
          Icon(
            isSorted
                ? (widget.sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 15,
            color: isSorted ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
          ),
        ],
      ],
    );

    final headerContent = Material(
      color: isDropTarget ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
      child: InkWell(
        onTap: widget.onSortChanged == null || column.label.isEmpty
            ? null
            : () => widget.onSortChanged!(column.id),
        child: Container(
          height: widget.density.headingRowHeight,
          padding: EdgeInsets.only(left: 12, right: column.resizable ? 14 : 12),
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Color(0xFFD9E2EC)),
              bottom: BorderSide(color: Color(0xFFD9E2EC)),
            ),
          ),
          child: Align(
            alignment: column.numeric
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: labelRow,
          ),
        ),
      ),
    );

    Widget child = headerContent;
    if (column.reorderable) {
      child = DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final draggedColumn = _columnById(details.data);
          if (draggedColumn == null || !draggedColumn.reorderable) {
            return false;
          }
          setState(() => _dragTargetColumnId = column.id);
          return details.data != column.id;
        },
        onLeave: (_) {
          if (_dragTargetColumnId == column.id) {
            setState(() => _dragTargetColumnId = null);
          }
        },
        onAcceptWithDetails: (details) => _moveColumn(details.data, column.id),
        builder: (context, candidateData, rejectedData) {
          return Draggable<String>(
            data: column.id,
            feedback: Material(
              color: Colors.transparent,
              elevation: 8,
              child: SizedBox(width: width, child: headerContent),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: headerContent),
            onDragCompleted: () {
              if (mounted) {
                setState(() => _dragTargetColumnId = null);
              }
            },
            onDraggableCanceled: (velocity, offset) {
              if (mounted) {
                setState(() => _dragTargetColumnId = null);
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: headerContent,
            ),
          );
        },
      );
    }

    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          if (column.resizable)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => _resetColumnWidth(column),
                  onHorizontalDragUpdate: (details) =>
                      _resizeColumn(column, details.delta.dx),
                  child: Container(
                    width: 12,
                    alignment: Alignment.center,
                    child: Container(
                      width: 2,
                      height: 18,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    T row,
    List<AdsTableColumn<T>> columns,
    int rowIndex,
  ) {
    final rowId = _rowId(row, rowIndex);
    final isHovered = _hoveredRowId == rowId;
    final isSelected = widget.selectedRowIds.contains(rowId);
    final background = isSelected
        ? const Color(0xFFEFF6FF)
        : isHovered
        ? const Color(0xFFF8FAFC)
        : rowIndex.isEven
        ? Colors.white
        : const Color(0xFFFBFDFF);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRowId = rowId),
      onExit: (_) {
        if (_hoveredRowId == rowId) {
          setState(() => _hoveredRowId = null);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: background,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showCheckboxes)
              _buildSelectionCell(rowId: rowId, selected: isSelected),
            ...columns.map((column) => _buildDataCell(context, row, column)),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCell({required String rowId, required bool selected}) {
    return Container(
      width: _selectionColumnWidth,
      constraints: BoxConstraints(minHeight: widget.density.dataRowMaxHeight),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Center(
        child: Checkbox(
          value: selected,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF2563EB);
            }
            return Colors.white;
          }),
          onChanged: widget.onSelectionChanged == null
              ? null
              : (value) => _toggleRowSelection(rowId, value ?? false),
        ),
      ),
    );
  }

  Widget _buildDataCell(BuildContext context, T row, AdsTableColumn<T> column) {
    final alignment = column.numeric
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return Container(
      width: _columnWidth(column),
      constraints: BoxConstraints(minHeight: widget.density.dataRowMaxHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Align(
        alignment: alignment,
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13,
            height: 1.35,
          ),
          child: column.cellBuilder(context, row),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final allowedPageSizes = const <int>[10, 25, 50];
    final resolvedPageSize = allowedPageSizes.contains(widget.pageSize)
        ? widget.pageSize
        : allowedPageSizes.first;
    final totalPages = widget.pageSize <= 0
        ? 1
        : ((widget.totalRowCount + widget.pageSize - 1) / widget.pageSize)
              .ceil()
              .clamp(1, 999999);
    final canGoBack = widget.pageIndex > 0;
    final canGoNext = widget.pageIndex + 1 < totalPages;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFCFDFF),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactFooter = constraints.maxWidth < 720;
          final rangeLabel =
              '${_pageStart == 0 ? 0 : _pageStart} - $_pageEnd / ${widget.totalRowCount}';
          final pageSizePicker = Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD9E2EC)),
            ),
            child: DropdownButton<int>(
              value: resolvedPageSize,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: allowedPageSizes
                  .map(
                    (size) => DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size satir'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: widget.onPageSizeChanged,
            ),
          );
          final pager = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Onceki sayfa',
                visualDensity: VisualDensity.compact,
                onPressed: canGoBack
                    ? () => widget.onPageChanged?.call(widget.pageIndex - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${widget.pageIndex + 1} / $totalPages',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: 'Sonraki sayfa',
                visualDensity: VisualDensity.compact,
                onPressed: canGoNext
                    ? () => widget.onPageChanged?.call(widget.pageIndex + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          );

          if (compactFooter) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rangeLabel,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [pageSizePicker, pager],
                ),
              ],
            );
          }

          return Row(
            children: [
              Text(
                rangeLabel,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              pageSizePicker,
              const SizedBox(width: 12),
              pager,
            ],
          );
        },
      ),
    );
  }
}

extension on AdsTableDensity {
  double get headingRowHeight {
    return switch (this) {
      AdsTableDensity.compact => 44,
      AdsTableDensity.comfortable => 52,
      AdsTableDensity.spacious => 60,
    };
  }

  double get dataRowMinHeight {
    return switch (this) {
      AdsTableDensity.compact => 48,
      AdsTableDensity.comfortable => 62,
      AdsTableDensity.spacious => 78,
    };
  }

  double get dataRowMaxHeight {
    return switch (this) {
      AdsTableDensity.compact => 56,
      AdsTableDensity.comfortable => 72,
      AdsTableDensity.spacious => 88,
    };
  }

  double get horizontalMargin {
    return switch (this) {
      AdsTableDensity.compact => 14,
      AdsTableDensity.comfortable => 18,
      AdsTableDensity.spacious => 24,
    };
  }

  double get columnSpacing {
    return switch (this) {
      AdsTableDensity.compact => 14,
      AdsTableDensity.comfortable => 20,
      AdsTableDensity.spacious => 28,
    };
  }
}
