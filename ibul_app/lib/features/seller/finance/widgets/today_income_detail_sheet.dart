import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/finance_models.dart';
import '../helpers/store_table_area_resolver.dart';
import '../widgets/finance_widgets.dart';

/// Bugünkü gelir detayı — yalnızca sunum katmanı.
/// Veri: [TodayRevenueBreakdown] ← `buildTodayRevenueBreakdown` ← FinanceRepository.
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

  static const _titleStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Color(0xFF0F172A),
  );

  static const _sectionStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF64748B),
    letterSpacing: 0.2,
  );

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
          insetPadding: const EdgeInsets.symmetric(horizontal: 56, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
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
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.88,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
        _buildHeader(context),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (!breakdown.hasPersistedPaymentMethods ||
                    !breakdown.hasPersistedAreaNames)
                  _buildDataNotice(),
                _buildSummaryChips(),
                const SizedBox(height: 10),
                _buildInsightRow(),
                const SizedBox(height: 12),
                _buildBreakdownSection(
                  title: 'Alan Bazlı Gelir',
                  slices: breakdown.byArea,
                  accent: const Color(0xFF6366F1),
                  emptyMessage: 'Bugün kapanan masa kaydı yok.',
                ),
                const SizedBox(height: 10),
                _buildBreakdownSection(
                  title: 'Ödeme Tipi Bazlı Gelir',
                  slices: breakdown.byPaymentMethod,
                  accent: const Color(0xFF0EA5E9),
                  emptyMessage: 'Ödeme tipi bilgisi henüz kaydedilmemiş.',
                ),
                const SizedBox(height: 10),
                const Text('Masa / Kaynak Bazlı Gelir', style: _sectionStyle),
                const SizedBox(height: 6),
                if (breakdown.tableLines.isEmpty)
                  _emptyHint('Bugün için gelir kaydı bulunamadı.')
                else
                  _buildSourceList(
                    breakdown.tableLines,
                    timeFmt,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bugünkü Gelir Detayı', style: _titleStyle),
                const SizedBox(height: 2),
                Text(
                  fmtCurrency(breakdown.totalRevenue),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: kFinancePrimary,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Kapanan masa + online + manuel gelir',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChips() {
    final labels = <String>[
      '${breakdown.tableLines.length} kayıt',
      '$_tableRecordCount masa',
      if (breakdown.byArea.isNotEmpty) '$_distinctAreaCount alan',
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: labels.map(_summaryChip).toList(growable: false),
    );
  }

  Widget _summaryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kFinanceDivider),
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

  Widget _buildDataNotice() {
    final parts = <String>[];
    if (!breakdown.hasPersistedAreaNames) {
      parts.add('Eski kayıtlarda alan adı boş olabilir');
    }
    if (!breakdown.hasPersistedPaymentMethods) {
      parts.add('Ödeme tipi eski kapanışlarda kaydedilmemiş olabilir');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Text(
          parts.join(' · '),
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF92400E),
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildInsightRow() {
    return Row(
      children: [
        Expanded(
          child: _compactStatCard(
            title: 'En Çok Kazandıran Alan',
            value: breakdown.topArea?.label ?? '—',
            amount: breakdown.topArea?.amount,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _compactStatCard(
            title: 'En Çok Kullanılan Ödeme',
            value: breakdown.topPaymentMethod?.label ?? '—',
            amount: breakdown.topPaymentMethod?.amount,
          ),
        ),
      ],
    );
  }

  Widget _compactStatCard({
    required String title,
    required String value,
    double? amount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kFinanceDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          if (amount != null) ...[
            const SizedBox(height: 2),
            Text(
              fmtCurrency(amount),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kFinanceAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownSection({
    required String title,
    required List<RevenueSlice> slices,
    required Color accent,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _sectionStyle),
        const SizedBox(height: 6),
        if (slices.isEmpty)
          _emptyHint(emptyMessage)
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: kFinanceDivider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (var i = 0; i < slices.length; i++) ...[
                  _breakdownRow(slices[i], accent),
                  if (i < slices.length - 1)
                    const Divider(height: 1, color: kFinanceDivider),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _breakdownRow(RevenueSlice slice, Color accent) {
    final share = breakdown.totalRevenue <= 0
        ? 0.0
        : (slice.amount / breakdown.totalRevenue).clamp(0, 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  slice.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                fmtCurrency(slice.amount),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: share.toDouble(),
              minHeight: 3,
              backgroundColor: const Color(0xFFE2E8F0),
              color: accent,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${slice.count} kayıt · %${(share * 100).toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceList(
    List<TableRevenueLine> lines,
    DateFormat timeFmt,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kFinanceDivider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            _sourceRow(
              lines[i],
              lines[i].closedAt == null ? '-' : timeFmt.format(lines[i].closedAt!),
            ),
            if (i < lines.length - 1)
              const Divider(height: 1, color: kFinanceDivider),
          ],
        ],
      ),
    );
  }

  Widget _sourceRow(TableRevenueLine line, String closedLabel) {
    final meta = <String>[
      line.areaName,
      line.paymentLabel,
      'Saat $closedLabel',
      if (line.orderItemCount > 0) '${line.orderItemCount} kalem',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.tableName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                fmtCurrency(line.amount),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            meta.join(' · '),
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kFinanceDivider),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
