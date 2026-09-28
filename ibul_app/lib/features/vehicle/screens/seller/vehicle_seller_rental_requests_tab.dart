import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../widgets/ibul_page_state.dart';
import '../../domain/turkish_national_id.dart';
import '../../domain/vehicle_pricing.dart';
import '../../domain/vehicle_rental_account.dart';
import '../../models/vehicle_commerce.dart';
import '../../models/vehicle_enums.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/vehicle_rental_booking_card.dart';
import '../../widgets/vehicle_rental_chrome.dart';

class VehicleSellerRentalRequestsTab extends StatefulWidget {
  const VehicleSellerRentalRequestsTab({super.key, this.sellerId});

  final String? sellerId;

  @override
  State<VehicleSellerRentalRequestsTab> createState() =>
      _VehicleSellerRentalRequestsTabState();
}

class _VehicleSellerRentalRequestsTabState
    extends State<VehicleSellerRentalRequestsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<VehicleReservation> _items = const [];
  bool _loading = true;

  static const _filters = [
    ('Bekleyen', VehicleReservationStatus.pendingSellerReview),
    ('Onaylanan', VehicleReservationStatus.pendingPayment),
    ('Aktif', VehicleReservationStatus.activeRental),
    ('Tamamlanan', VehicleReservationStatus.completed),
    ('İptal', VehicleReservationStatus.cancelled),
    ('Reddedilen', VehicleReservationStatus.rejected),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await VehicleService.instance.reservations.listMine(
      asSeller: true,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const IbulPageState.loading();
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.primary,
          tabs: [for (final filter in _filters) Tab(text: filter.$1)],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final filter in _filters) _listFor(filter.$2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _listFor(VehicleReservationStatus status) {
    final rows = _items.where((item) {
      if (status == VehicleReservationStatus.cancelled) {
        return item.status == VehicleReservationStatus.cancelled ||
            item.status == VehicleReservationStatus.sellerCancelled ||
            item.status == VehicleReservationStatus.refundPending;
      }
      if (status == VehicleReservationStatus.pendingPayment) {
        return item.status == VehicleReservationStatus.pendingPayment;
      }
      if (status == VehicleReservationStatus.activeRental) {
        return item.status == VehicleReservationStatus.activeRental ||
            item.status == VehicleReservationStatus.reserved ||
            item.status == VehicleReservationStatus.confirmed;
      }
      return item.status == status;
    }).toList();
    if (rows.isEmpty) {
      return const IbulPageState.empty(
        icon: Icons.key_outlined,
        title: 'Kayıt yok',
      );
    }
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final item = rows[index];
        final pending = item.status == VehicleReservationStatus.pendingSellerReview;
        final reserved = item.status == VehicleReservationStatus.reserved ||
            item.status == VehicleReservationStatus.confirmed;
        return VehicleRentalBookingCard(
          item: item,
          docsReady: pending ||
              item.status == VehicleReservationStatus.pendingPayment ||
              reserved,
          onDetail: () => _openDetail(item),
          onApprove: pending ? () => _respond(item, 'approve') : null,
          onReject: pending ? () => _reject(item) : null,
          onHandover: reserved ? () => _handover(item) : null,
        );
      },
    );
  }

  Future<void> _openDetail(VehicleReservation item) async {
    final docs = await VehicleService.instance.reservations.listDocuments(
      item.id,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                item.listingTitle ?? 'Araç',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Kiralayan', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(item.customerName ?? 'Müşteri'),
              Text(item.customerPhone ?? ''),
              Text(item.customerEmail ?? ''),
              if ((item.customerNationalId ?? '').isNotEmpty)
                Text('TC  ${TurkishNationalId.mask(item.customerNationalId!)}'),
              const SizedBox(height: 8),
              Text('${rentalDateLabel(item.pickupAt)} → ${rentalDateLabel(item.returnAt)}'),
              Text('${VehicleRentalPricing.rentalDays(pickupAt: item.pickupAt, returnAt: item.returnAt)} gün'),
              Text('Teslim: ${item.deliveryAddress ?? item.deliveryMode.wire}'),
              Text('İade: ${item.dropoffAddress ?? item.dropoffMode?.wire ?? ''}'),
              Text('Kiralama ₺${item.rentalSubtotal.round()}'),
              Text('Teslimat ₺${item.deliveryFee.round()}'),
              Text('Depozito ₺${item.deposit.round()}  ·  İade edilebilir'),
              Text('Toplam ₺${item.total.round()}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('Ödeme: ${VehicleRentalPaymentCopy.statusLabel(item.paymentStatus)}'),
              if (VehicleRentalPaymentCopy.isPaid(item.paymentStatus))
                const Text('Ödeme: ✓ Tamamlandı'),
              if (item.rentalCode != null) Text('Kod: ${item.rentalCode}'),
              Text(
                item.termsAcceptedAt == null
                    ? 'Sözleşme kabul kaydı yok'
                    : 'Sözleşme kabul edildi',
              ),
              const SizedBox(height: 8),
              Text('Belgeler: ${docs.length}'),
              for (final doc in docs)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    VehicleDocumentTypeX.labelOf(doc['doc_type']?.toString()),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final id = doc['id']?.toString();
                      if (id == null) return;
                      final url = await VehicleService.instance.reservations
                          .documentPreviewUrl(id);
                      if (url == null || !context.mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(url),
                          ),
                        ),
                      );
                    },
                    child: const Text('Görüntüle'),
                  ),
                ),
              if (item.status == VehicleReservationStatus.pendingSellerReview)
                Row(
                  children: [
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _respond(item, 'approve');
                      },
                      child: const Text('Onayla'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _reject(item);
                      },
                      child: const Text('Reddet'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _respond(VehicleReservation item, String action, {String? reason}) async {
    await VehicleService.instance.reservations.respond(
      reservationId: item.id,
      action: action,
      reason: reason,
    );
    await _load();
  }

  Future<void> _reject(VehicleReservation item) async {
    const reasons = [
      'Araç uygun değil',
      'Belge eksik',
      'Kimlik doğrulama sorunu',
      'Tarih uygun değil',
      'Diğer',
    ];
    var selected = reasons.first;
    final extra = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Red nedeni'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final reason in reasons)
                  RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: selected,
                    onChanged: (v) => setLocal(() => selected = v ?? reason),
                  ),
                if (selected == 'Diğer')
                  TextField(controller: extra, autofocus: true, decoration: const InputDecoration(labelText: 'Açıklama')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reddet')),
            ],
          );
        },
      ),
    );
    final reason = selected == 'Diğer' ? extra.text.trim() : selected;
    extra.dispose();
    if (ok == true && reason.isNotEmpty) {
      await _respond(item, 'reject', reason: reason);
    }
  }

  Future<void> _handover(VehicleReservation item) async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teslim kodu'),
        content: TextField(controller: code),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Teslim et'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await VehicleService.instance.reservations.handover(
        reservationId: item.id,
        code: code.text.trim(),
      );
      await _load();
    }
    code.dispose();
  }
}
