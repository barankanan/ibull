import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/garson_operation_rules.dart';
import '../../models/restaurant_ops_models.dart';

/// 3-tab bottom sheet for previewing a single order.
///
/// Tabs:
///   0 — Adisyon Önizleme  (receipt template)
///   1 — Mutfak Fişi       (kitchen ticket)
///   2 — Sipariş Detayı    (operational metadata + session timeline)
///
/// Three distinct print/dispatch actions — never conflated:
///   • [onPrintAdisyon]       — generate & download/print the receipt HTML
///   • [onPrintKitchenTicket] — fire a thermal printer job for kitchen ticket
///   • [onResendToKitchen]    — re-dispatch the order through the kitchen
///                             order pipeline (service call, not just a print)
///
/// Reusable for live orders (`OrderPreviewRecord.fromTableOrder`) and history
/// records (`OrderPreviewRecord.fromHistory`).
class OrderPreviewSheet extends StatefulWidget {
  const OrderPreviewSheet({
    super.key,
    required this.record,
    this.onPrintAdisyon,
    this.onPrintKitchenTicket,
    this.onResendToKitchen,
    this.initialTab = 0,
  });

  final OrderPreviewRecord record;

  /// Tab 0 → "Adisyon Yazdır"
  /// Generate and print/download the adisyon receipt (web: HTML, native: PDF).
  final VoidCallback? onPrintAdisyon;

  /// Tab 1 → "Mutfak Fişi Yazdır"
  /// Fire a thermal-printer print job for the kitchen ticket.
  /// Does NOT re-dispatch the order through the service pipeline; only prints.
  final VoidCallback? onPrintKitchenTicket;

  /// Tab 1 → "Mutfağa Yeniden Yolla"
  /// Re-dispatch the order through the kitchen order pipeline (status updates
  /// included). Conceptually different from [onPrintKitchenTicket] — this is a
  /// service-level dispatch, not merely a local print action.
  final VoidCallback? onResendToKitchen;

  /// 0 = Adisyon, 1 = Mutfak Fişi, 2 = Detay
  final int initialTab;

  @override
  State<OrderPreviewSheet> createState() => _OrderPreviewSheetState();
}

class _OrderPreviewSheetState extends State<OrderPreviewSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _timeFmt = DateFormat('HH:mm');
  static final _dtFmt = DateFormat('d MMM HH:mm');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _money(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} ₺';

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final color = _statusColor(r.status);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── Header ──────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Masa ${r.tableNumber}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _statusLabel(r.status),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        if (r.revision > 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFFED7AA)),
                            ),
                            child: Text(
                              'Rev.${r.revision}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          padding: EdgeInsets.zero,
                          color: const Color(0xFF6B7280),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.itemCount} ürün • ${_money(r.grandTotal)} • ${_dtFmt.format(r.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Tab bar ──────────────────────────────────────
                    TabBar(
                      controller: _tabs,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle:
                          const TextStyle(fontSize: 12),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: const Color(0xFF6B7280),
                      indicatorColor: AppColors.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: const [
                        Tab(text: 'Adisyon'),
                        Tab(text: 'Mutfak Fişi'),
                        Tab(text: 'Sipariş Detayı'),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Tab views ────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _AdisyonTab(
                      record: r,
                      money: _money,
                      dateFmt: _dateFmt,
                      timeFmt: _timeFmt,
                      onPrintAdisyon: widget.onPrintAdisyon,
                    ),
                    _KitchenTicketTab(
                      record: r,
                      money: _money,
                      timeFmt: _timeFmt,
                      onPrintKitchenTicket: widget.onPrintKitchenTicket,
                      onResendToKitchen: widget.onResendToKitchen,
                    ),
                    _OrderDetailTab(
                      record: r,
                      money: _money,
                      dtFmt: _dtFmt,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 0: Adisyon Önizleme
// ─────────────────────────────────────────────────────────────────────────────

class _AdisyonTab extends StatelessWidget {
  const _AdisyonTab({
    required this.record,
    required this.money,
    required this.dateFmt,
    required this.timeFmt,
    this.onPrintAdisyon,
  });

  final OrderPreviewRecord record;
  final String Function(double) money;
  final DateFormat dateFmt;
  final DateFormat timeFmt;
  final VoidCallback? onPrintAdisyon;

  @override
  Widget build(BuildContext context) {
    final items = record.items;
    const discountTotal = 0.0;
    final netTotal = record.grandTotal - discountTotal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Receipt paper frame ──────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Store name
              Text(
                record.storeName ?? 'Restoran',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              // Branch + phone row
              _DashedDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      record.storeBranch?.toUpperCase() ?? 'MERKEZ ŞUBE',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (record.storePhone != null)
                      Text(
                        'Tel: ${record.storePhone}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              _DashedDivider(),
              const SizedBox(height: 6),
              // Date / time / table
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tarih: ${dateFmt.format(record.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Saat: ${timeFmt.format(record.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Masa: ${record.tableNumber}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Column headers
              const _ReceiptRowHeader(),
              const Divider(thickness: 1.5, height: 8),
              // Items
              ...items.map((item) {
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                final price =
                    (item['price'] as num?)?.toDouble() ?? 0.0;
                final lineTotal = qty * price;
                final name = item['name']?.toString() ?? '-';
                return _ReceiptItemRow(
                  name: name,
                  qty: qty,
                  lineTotal: lineTotal,
                  money: money,
                );
              }),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Ürün yok',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ),
              const Divider(height: 12),
              // Totals
              _TotalRow(label: 'Adisyon Toplam', value: money(record.grandTotal), bold: false),
              _TotalRow(label: 'İndirim', value: money(discountTotal), bold: false),
              _TotalRow(label: 'Net Toplam', value: money(netTotal), bold: false),
              const Divider(thickness: 1.5, height: 12),
              Center(
                child: Text(
                  'Ödenecek Toplam: ${money(netTotal)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Teşekkür Ederiz',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Action button ────────────────────────────────────────────
        if (onPrintAdisyon != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onPrintAdisyon!();
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Adisyon Yazdır'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Mutfak Fişi
// ─────────────────────────────────────────────────────────────────────────────

class _KitchenTicketTab extends StatelessWidget {
  const _KitchenTicketTab({
    required this.record,
    required this.money,
    required this.timeFmt,
    this.onPrintKitchenTicket,
    this.onResendToKitchen,
  });

  final OrderPreviewRecord record;
  final String Function(double) money;
  final DateFormat timeFmt;
  /// "Mutfak Fişi Yazdır" — fires a thermal printer job (local print only).
  final VoidCallback? onPrintKitchenTicket;
  /// "Mutfağa Yeniden Yolla" — re-dispatches via service pipeline (status aware).
  final VoidCallback? onResendToKitchen;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final hasRevision = r.revision > 1;
    final hasAdditions = r.addedItems.isNotEmpty;
    final hasRemovals = r.removedItems.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Kitchen ticket frame (dark theme) ───────────────────────
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.restaurant_menu_rounded,
                      color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'MUTFAK FİŞİ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (hasRevision)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'REV ${r.revision}',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Masa / Sipariş / Saat row
              _KitchenInfoRow(
                  label: 'MASA', value: '${r.tableNumber}'),
              _KitchenInfoRow(
                  label: 'SİPARİŞ',
                  value: r.orderId.length > 8
                      ? '#${r.orderId.substring(0, 8).toUpperCase()}'
                      : '#${r.orderId.toUpperCase()}'),
              _KitchenInfoRow(
                  label: 'SAAT',
                  value: timeFmt.format(r.createdAt)),
              if (r.waiterName != null)
                _KitchenInfoRow(
                    label: 'GARSON', value: r.waiterName!),
              const SizedBox(height: 10),
              // If revised: show additions/removals first; else show all items
              if (hasRevision && (hasAdditions || hasRemovals)) ...[
                if (hasAdditions) ...[
                  _KitchenSectionHeader(
                    label: '✚ EKLENENLER',
                    color: const Color(0xFF22C55E),
                  ),
                  const SizedBox(height: 4),
                  ...r.addedItems.map((item) => _KitchenItemRow(
                        item: item,
                        color: const Color(0xFF22C55E),
                      )),
                  const SizedBox(height: 8),
                ],
                if (hasRemovals) ...[
                  _KitchenSectionHeader(
                    label: '✕ ÇIKARILANLAR',
                    color: const Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 4),
                  ...r.removedItems.map((item) => _KitchenItemRow(
                        item: item,
                        color: const Color(0xFFEF4444),
                      )),
                  const SizedBox(height: 8),
                ],
                // Still show full current items for kitchen reference
                _KitchenSectionHeader(
                  label: 'GÜNCEL SİPARİŞ',
                  color: Colors.white54,
                ),
                const SizedBox(height: 4),
              ],
              // All items
              ...r.items.map((item) => _KitchenItemRow(item: item)),
              // Notes / last edit note
              if (r.lastEditNote != null &&
                  r.lastEditNote!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠ ',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFF59E0B))),
                      Expanded(
                        child: Text(
                          r.lastEditNote!,
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Tab 1 action buttons — two DISTINCT actions ──────────────
        // "Mutfak Fişi Yazdır" = thermal print job only (no status change)
        // "Mutfağa Yeniden Yolla" = service dispatch (status updates included)
        if (onPrintKitchenTicket != null || onResendToKitchen != null)
          Row(
            children: [
              if (onPrintKitchenTicket != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onPrintKitchenTicket!();
                    },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Mutfak Fişi Yazdır'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: const Color(0xFFF97316),
                      side: const BorderSide(color: Color(0xFFF97316)),
                    ),
                  ),
                ),
              if (onPrintKitchenTicket != null && onResendToKitchen != null)
                const SizedBox(width: 10),
              if (onResendToKitchen != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onResendToKitchen!();
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Mutfağa Yeniden Yolla'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Sipariş Detayı
// ─────────────────────────────────────────────────────────────────────────────

class _OrderDetailTab extends StatelessWidget {
  const _OrderDetailTab({
    required this.record,
    required this.money,
    required this.dtFmt,
  });

  final OrderPreviewRecord record;
  final String Function(double) money;
  final DateFormat dtFmt;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final rules = GarsonOperationRules.forStatus(r.status);
    final hasClosedAt = r.closedAt != null;
    final hasOpenedAt = r.openedAt != null || hasClosedAt;
    final sessionDuration = r.sessionDuration;
    final closedBy = r.closedByName ?? r.waiterName;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Sipariş kimliği ──────────────────────────────────────────
        _DetailSection(
          title: 'Sipariş Bilgileri',
          icon: Icons.receipt_outlined,
          children: [
            _DetailRow(label: 'Sipariş ID',
                value: r.orderId.isNotEmpty ? r.orderId : '-'),
            _DetailRow(label: 'Masa No', value: '${r.tableNumber}'),
            _DetailRow(label: 'Durum', value: _statusLabel(r.status)),
            _DetailRow(label: 'Revizyon', value: '${r.revision}'),
            _DetailRow(label: 'Toplam', value: money(r.grandTotal)),
          ],
        ),
        // ── Masa oturum zaman çizelgesi ──────────────────────────────
        if (hasOpenedAt) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Masa Oturumu',
            icon: Icons.timeline_rounded,
            children: [
              _TimelineRow(
                label: 'Masa Açıldı',
                time: dtFmt.format(r.openedAt ?? r.createdAt),
                dotColor: const Color(0xFF16A34A),
              ),
              _TimelineRow(
                label: 'Oluşturuldu',
                time: dtFmt.format(r.createdAt),
                dotColor: const Color(0xFF2563EB),
              ),
              if (r.updatedAt != null && !hasClosedAt)
                _TimelineRow(
                  label: 'Son Güncelleme',
                  time: dtFmt.format(r.updatedAt!),
                  dotColor: const Color(0xFFF59E0B),
                ),
              if (hasClosedAt)
                _TimelineRow(
                  label: 'Masa Kapatıldı',
                  time: dtFmt.format(r.closedAt!),
                  dotColor: const Color(0xFF64748B),
                  isLast: true,
                ),
              if (sessionDuration != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        'Oturum süresi: ${_formatDuration(sessionDuration)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        // Fall-back zaman bloğu for live orders without openedAt
        if (!hasOpenedAt) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Zaman',
            icon: Icons.schedule_rounded,
            children: [
              _DetailRow(
                  label: 'Oluşturuldu', value: dtFmt.format(r.createdAt)),
              if (r.updatedAt != null)
                _DetailRow(
                    label: 'Son Güncelleme',
                    value: dtFmt.format(r.updatedAt!)),
            ],
          ),
        ],
        // ── Kullanıcı / Kim kapattı ──────────────────────────────────
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Kullanıcı',
          icon: Icons.person_outline_rounded,
          children: [
            _DetailRow(
                label: 'Garson / İşlemci',
                value: r.waiterName ?? 'Bilinmiyor'),
            if (r.waiterId != null && r.waiterId!.isNotEmpty)
              _DetailRow(label: 'Garson ID', value: r.waiterId!),
            if (hasClosedAt && closedBy != null)
              _DetailRow(label: 'Kim Kapattı', value: closedBy),
          ],
        ),
        // ── Ödeme detayı ─────────────────────────────────────────────
        if (r.paymentMethod != null) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Ödeme',
            icon: Icons.payments_outlined,
            children: [
              _DetailRow(label: 'Yöntem',
                  value: _paymentLabel(r.paymentMethod)),
              _DetailRow(label: 'Tutar', value: money(r.grandTotal)),
              if (r.paymentNote != null && r.paymentNote!.isNotEmpty)
                _DetailRow(label: 'Not', value: r.paymentNote!),
              if (hasClosedAt)
                _DetailRow(
                    label: 'Tarih', value: dtFmt.format(r.closedAt!)),
            ],
          ),
        ],
        // ── Operasyon kuralları ───────────────────────────────────────
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Operasyon Kuralları',
          icon: Icons.policy_outlined,
          children: [
            _DetailRow(label: 'Düzenlenebilir',
                value: rules.canEdit ? 'Evet' : 'Hayır'),
            _DetailRow(label: 'Geri Alınabilir',
                value: rules.canUndo ? '30 sn içinde' : 'Hayır'),
            _DetailRow(label: 'Mutfağa İletilebilir',
                value: rules.canResend ? 'Evet' : 'Hayır'),
            _DetailRow(label: 'Aktarılabilir',
                value: rules.canTransfer ? 'Evet' : 'Hayır'),
            if (rules.editNote.isNotEmpty)
              _DetailRow(label: 'Kural Notu', value: rules.editNote),
          ],
        ),
        // ── Son revizyon notu ─────────────────────────────────────────
        if (r.lastEditNote != null && r.lastEditNote!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Son Revizyon Notu',
            icon: Icons.edit_note_rounded,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  r.lastEditNote!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        // ── Yazıcı hedefleri ──────────────────────────────────────────
        if (r.printHistory.isNotEmpty || r.printerTarget != null) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: r.printHistory.isNotEmpty
                ? 'Yazıcı Hedefleri & Geçmiş (${r.printHistory.length})'
                : 'Yazıcı Hedefi',
            icon: Icons.print_outlined,
            children: [
              if (r.printerTarget != null)
                _DetailRow(label: 'Hedef', value: r.printerTarget!),
              ...r.printHistory.map((ph) {
                final statusColor = ph.status == 'printed'
                    ? const Color(0xFF16A34A)
                    : ph.status == 'failed'
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFF59E0B);
                final target = [
                  if (ph.stationName != null) ph.stationName!,
                  if (ph.printerName != null) ph.printerName!,
                ].join(' › ');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _jobTypeLabel(ph.jobType),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (target.isNotEmpty)
                              Text(
                                target,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            dtFmt.format(ph.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (ph.retryCount > 0)
                            Text(
                              '${ph.retryCount} yeniden deneme',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ],
    );
  }

  static String _paymentLabel(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'cash':
        return 'Nakit';
      case 'card':
        return 'Kart';
      case 'online':
        return 'Online';
      case 'mixed':
        return 'Karma';
      case 'complimentary':
        return 'İkram';
      default:
        return raw ?? '-';
    }
  }

  static String _jobTypeLabel(String? raw) {
    switch (raw) {
      case 'new_order':
        return 'Yeni Sipariş';
      case 'add_item':
        return 'Ürün Eklendi';
      case 'cancel_item':
        return 'Ürün İptal';
      case 'reprint':
        return 'Tekrar Baskı';
      case 'kitchen_resend':
        return 'Mutfağa Yeniden İletildi';
      default:
        return raw ?? '-';
    }
  }

  static String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '< 1 dk';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m dk';
    if (m == 0) return '$h sa';
    return '$h sa $m dk';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      final count =
          (constraints.maxWidth / (dashWidth + dashSpace)).floor();
      return Row(
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.only(right: dashSpace),
            child: Container(
              width: dashWidth,
              height: 1,
              color: Colors.black,
            ),
          ),
        ),
      );
    });
  }
}

class _ReceiptRowHeader extends StatelessWidget {
  const _ReceiptRowHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Ürünler',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            'Adet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            'Tutar',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptItemRow extends StatelessWidget {
  const _ReceiptItemRow({
    required this.name,
    required this.qty,
    required this.lineTotal,
    required this.money,
  });

  final String name;
  final int qty;
  final double lineTotal;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '$qty adet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              money(lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final w = bold ? FontWeight.w900 : FontWeight.w600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: w)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: w)),
        ],
      ),
    );
  }
}

class _KitchenInfoRow extends StatelessWidget {
  const _KitchenInfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenSectionHeader extends StatelessWidget {
  const _KitchenSectionHeader(
      {required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _KitchenItemRow extends StatelessWidget {
  const _KitchenItemRow({
    required this.item,
    this.color = Colors.white,
  });
  final Map<String, dynamic> item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final name = item['name']?.toString() ?? '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$qty×',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single entry in the session timeline (Masa Oturumu section).
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.time,
    required this.dotColor,
    this.isLast = false,
  });

  final String label;
  final String time;
  final Color dotColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical timeline track
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _statusColor(String? status) {
  switch (GarsonOrderStatus.normalise(status)) {
    case 'waiting':
      return const Color(0xFFEF4444);
    case 'sent':
      return const Color(0xFFF97316);
    case 'preparing':
      return const Color(0xFFF59E0B);
    case 'ready':
      return const Color(0xFF22C55E);
    case 'served':
      return const Color(0xFF2563EB);
    case 'closed':
    case 'completed':
      return const Color(0xFF64748B);
    default:
      return const Color(0xFF7A2FF4);
  }
}

String _statusLabel(String? status) {
  switch (GarsonOrderStatus.normalise(status)) {
    case 'draft':
      return 'Taslak';
    case 'waiting':
      return 'Bekliyor';
    case 'sent':
      return 'Mutfakta';
    case 'preparing':
      return 'Hazırlanıyor';
    case 'ready':
      return 'Hazır';
    case 'served':
      return 'Servis Edildi';
    case 'closed':
      return 'Kapalı';
    case 'completed':
      return 'Tamamlandı';
    default:
      return status ?? '-';
  }
}
