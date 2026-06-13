import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/finance_models.dart';
import '../helpers/store_table_area_resolver.dart';
import '../widgets/finance_widgets.dart';

class TodayIncomeDetailSheet extends StatelessWidget {
  const TodayIncomeDetailSheet({
    super.key,
    required this.breakdown,
    required this.loading,
    this.error,
    this.scrollController,
  });

  final TodayRevenueBreakdown breakdown;
  final bool loading;
  final String? error;
  final ScrollController? scrollController;

  static Future<void> show(
    BuildContext context, {
    required TodayRevenueBreakdown breakdown,
    required bool loading,
    String? error,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) {
      return showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
            child: TodayIncomeDetailSheet(
              breakdown: breakdown,
              loading: loading,
              error: error,
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: kFinanceSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: TodayIncomeDetailSheet(
              breakdown: breakdown,
              loading: loading,
              error: error,
              scrollController: controller,
            ),
          );
        },
      ),
    );
  }

  int get _tableRecordCount =>
      breakdown.tableLines.where((line) => line.source == 'table').length;

  int get _distinctAreaCount => breakdown.byArea
      .where((slice) => slice.label != StoreTableAreaResolver.unresolvedLabel)
      .length;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm', 'tr_TR');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
          child: Row(
            children: [
              Expanded(child: _buildHeader()),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (loading)
          const Expanded(
            child: FinLoadingOverlay(message: 'Gelir detayı yükleniyor...'),
          )
        else if (error != null)
          Expanded(child: FinErrorCard(message: error!))
        else
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (!breakdown.hasPersistedPaymentMethods ||
                    !breakdown.hasPersistedAreaNames)
                  _buildDataNotice(),
                _buildSummaryChips(),
                const SizedBox(height: 14),
                _buildInsightRow(),
                const SizedBox(height: 18),
                _buildSliceSection(
                  title: 'Alan Bazlı Gelir',
                  icon: Icons.place_outlined,
                  accent: const Color(0xFF6366F1),
                  slices: breakdown.byArea,
                  emptyMessage: 'Bugün kapanan masa kaydı yok.',
                ),
                const SizedBox(height: 16),
                _buildSliceSection(
                  title: 'Ödeme Tipi Bazlı Gelir',
                  icon: Icons.payments_outlined,
                  accent: const Color(0xFF0EA5E9),
                  slices: breakdown.byPaymentMethod,
                  emptyMessage: 'Ödeme tipi bilgisi henüz kaydedilmemiş.',
                ),
                const SizedBox(height: 16),
                _sectionTitle('Masa / Kaynak Bazlı Gelir'),
                const SizedBox(height: 10),
                if (breakdown.tableLines.isEmpty)
                  _emptyHint('Bugün için gelir kaydı bulunamadı.')
                else
                  ...breakdown.tableLines.map((line) {
                    final closedLabel = line.closedAt == null
                        ? '-'
                        : timeFmt.format(line.closedAt!);
                    return _buildTableLineCard(line, closedLabel);
                  }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return FinSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bugünkü Gelir Detayı',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fmtCurrency(breakdown.totalRevenue),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: kFinancePrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kapanan masa, online ve manuel gelirler',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChips() {
    final chips = <Widget>[
      _summaryChip(
        icon: Icons.receipt_long_outlined,
        label: '${breakdown.tableLines.length} kayıt',
      ),
      _summaryChip(
        icon: Icons.table_restaurant_outlined,
        label: '$_tableRecordCount masa',
      ),
      if (breakdown.byArea.isNotEmpty)
        _summaryChip(
          icon: Icons.grid_view_rounded,
          label: '$_distinctAreaCount alan',
        ),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _summaryChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kFinanceDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kFinancePrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataNotice() {
    final parts = <String>[];
    if (!breakdown.hasPersistedAreaNames) {
      parts.add(
        'Eski kayıtlarda alan adı boş olabilir; mümkün olanlar store_tables üzerinden çözümlenir',
      );
    }
    if (!breakdown.hasPersistedPaymentMethods) {
      parts.add('Ödeme tipi eski kapanışlarda kaydedilmemiş olabilir');
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join('. '),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow() {
    return Row(
      children: [
        Expanded(
          child: _insightCard(
            title: 'En Çok Kazandıran Alan',
            value: breakdown.topArea?.label ?? 'Veri yok',
            amount: breakdown.topArea?.amount,
            color: const Color(0xFF6366F1),
            icon: Icons.place_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _insightCard(
            title: 'En Çok Kullanılan Ödeme',
            value: breakdown.topPaymentMethod?.label ?? 'Veri yok',
            amount: breakdown.topPaymentMethod?.amount,
            color: const Color(0xFF0EA5E9),
            icon: Icons.payments_outlined,
          ),
        ),
      ],
    );
  }

  Widget _insightCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    double? amount,
  }) {
    return FinSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          if (amount != null) ...[
            const SizedBox(height: 4),
            Text(
              fmtCurrency(amount),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliceSection({
    required String title,
    required IconData icon,
    required Color accent,
    required List<RevenueSlice> slices,
    required String emptyMessage,
  }) {
    return FinSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (slices.isEmpty)
            _emptyHint(emptyMessage)
          else
            ...slices.map((slice) => _sliceTile(slice, accent)),
        ],
      ),
    );
  }

  Widget _sliceTile(RevenueSlice slice, Color accent) {
    final share = breakdown.totalRevenue <= 0
        ? 0.0
        : (slice.amount / breakdown.totalRevenue).clamp(0, 1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kFinanceSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kFinanceDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  slice.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                fmtCurrency(slice.amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: share.toDouble(),
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${slice.count} kayıt · %${(share * 100).toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTableLineCard(TableRevenueLine line, String closedLabel) {
    final isUnresolved = line.areaName == StoreTableAreaResolver.unresolvedLabel;
    final areaColor = isUnresolved
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: FinSurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.tableName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Text(
                  fmtCurrency(line.amount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _areaBadge(line.areaName, areaColor, isUnresolved),
                _metaChip(line.paymentLabel),
                _metaChip('Saat $closedLabel'),
                if (line.orderItemCount > 0)
                  _metaChip('${line.orderItemCount} kalem'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _areaBadge(String label, Color color, bool muted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF1F5F9) : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: muted ? const Color(0xFFE2E8F0) : color.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: muted ? const Color(0xFF64748B) : color,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _emptyHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kFinanceSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kFinanceDivider),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}
