import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart';
import '../../../features/seller/contracts/store_contract.dart';
import '../../../features/seller/contracts/store_contract_repository.dart';
import '../../../widgets/ibul_page_state.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/turkish_national_id.dart';
import '../domain/vehicle_catalog.dart';
import '../domain/vehicle_pricing.dart';
import '../domain/vehicle_rental_account.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_enums.dart';
import '../services/vehicle_service.dart';
import '../widgets/vehicle_rental_chrome.dart';
import '../widgets/vehicle_rental_payment_bar.dart';

class VehicleRentalDetailPage extends StatefulWidget {
  const VehicleRentalDetailPage({super.key, required this.reservation});

  final VehicleReservation reservation;

  @override
  State<VehicleRentalDetailPage> createState() => _VehicleRentalDetailPageState();
}

class _VehicleRentalDetailPageState extends State<VehicleRentalDetailPage> {
  late VehicleReservation _item = widget.reservation;
  List<Map<String, dynamic>> _docs = const [];
  StoreContractVersion? _contract;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final latest = await VehicleService.instance.reservations.getMineById(
      _item.id,
    );
    final docs = await VehicleService.instance.reservations.listDocuments(
      _item.id,
    );
    StoreContractVersion? contract;
    try {
      contract = await StoreContractRepository().acceptedForRental(_item.id);
    } catch (_) {
      contract = null;
    }
    if (!mounted) return;
    setState(() {
      if (latest != null) _item = latest;
      _docs = docs;
      _contract = contract;
      _loading = false;
    });
  }

  int get _days => VehicleRentalPricing.rentalDays(
        pickupAt: _item.pickupAt,
        returnAt: _item.returnAt,
      );

  bool get _showPayBar =>
      VehicleRentalPaymentCopy.canPay(_item) ||
      _item.status.canCustomerCancel ||
      VehicleRentalPaymentCopy.isPaid(_item.paymentStatus);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiralama detayı'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
      ),
      body: _loading
          ? const IbulPageState.loading()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if ((_item.listingCoverUrl ?? '').isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: OptimizedImage(
                        imageUrlOrPath: _item.listingCoverUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  _item.listingTitle ?? 'Araç kiralama',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                if ((_item.rentalCode ?? '').isNotEmpty)
                  Text('Kiralama No  ${_item.rentalCode}'),
                Text(
                  _item.status.labelTr,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Divider(height: 28),
                Text(
                  '${rentalDateLabel(_item.pickupAt)} ${rentalTimeLabel(_item.pickupAt)}'
                  '  →  ${rentalDateLabel(_item.returnAt)} ${rentalTimeLabel(_item.returnAt)}',
                ),
                Text('$_days gün', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Teslim: ${_item.deliveryAddress ?? _item.deliveryMode.wire}'),
                Text(
                  'İade: ${_item.dropoffAddress ?? _item.dropoffMode?.wire ?? ''}',
                ),
                const SizedBox(height: 12),
                Text('Kiralama  ${VehicleMoney.format(_item.rentalSubtotal)}'),
                Text('Teslim    ${VehicleMoney.format(_item.deliveryFee)}'),
                Text('Depozito  ${VehicleMoney.format(_item.deposit)}  ·  İade edilebilir'),
                Text(
                  'Toplam    ${VehicleMoney.format(_item.total)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Ödeme: ${VehicleRentalPaymentCopy.statusLabel(_item.paymentStatus)}',
                ),
                if ((_item.customerNationalId ?? '').isNotEmpty)
                  Text(
                    'TC  ${TurkishNationalId.mask(_item.customerNationalId!)}',
                  ),
                const Divider(height: 28),
                const Text(
                  'Belgeler',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final doc in _docs)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      VehicleDocumentTypeX.labelOf(doc['doc_type']?.toString()),
                    ),
                    subtitle: Text(
                      (doc['status']?.toString() ?? '') == 'submitted'
                          ? 'Yüklendi'
                          : (doc['status']?.toString() ?? ''),
                    ),
                    trailing: TextButton(
                      onPressed: () => _viewDoc(doc['id']?.toString()),
                      child: const Text('Görüntüle'),
                    ),
                  ),
                if (_docs.isEmpty) const Text('Belge kaydı yok'),
                const Divider(height: 28),
                const Text(
                  'Kabul edilen sözleşme',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (_contract == null)
                  const Text('Sözleşme kaydı yok')
                else ...[
                  Text(_contract!.title),
                  Text('Sürüm ${_contract!.version}'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _viewContract,
                      child: const Text('Sözleşmeyi Gör'),
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: _loading || !_showPayBar
          ? null
          : VehicleRentalClock(
              builder: (context, now) => VehicleRentalPaymentActionBar(
                item: _item,
                now: now,
                busy: _busy,
                onPay: _pay,
                onCancel: _cancel,
              ),
            ),
    );
  }

  Future<void> _pay() async {
    if (!VehicleRentalPaymentCopy.canPay(_item)) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ödeme'),
        content: const Text(
          'Online ödeme altyapısı henüz aktif değil.\n'
          'Kart bilgisi alınmaz ve satıcı bakiyesi değişmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewDoc(String? id) async {
    if (id == null) return;
    final url = await VehicleService.instance.reservations.documentPreviewUrl(
      id,
    );
    if (url == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  Future<void> _viewContract() async {
    final contract = _contract;
    if (contract == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contract.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('Sürüm ${contract.version}'),
                const SizedBox(height: 12),
                Expanded(
                  child: contract.isText
                      ? SingleChildScrollView(
                          child: SelectableText(contract.bodyText ?? ''),
                        )
                      : Center(
                          child: FilledButton(
                            onPressed: () async {
                              final url = await StoreContractRepository()
                                  .signedPdfUrl(contract);
                              if (url == null) return;
                              await launchUrl(Uri.parse(url));
                            },
                            child: const Text('PDF görüntüle'),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İptal onayı'),
        content: const Text(
          'Kiralama talebini iptal etmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final result = await VehicleService.instance.reservations.cancel(
        reservationId: _item.id,
      );
      if (!mounted) return;
      final status = VehicleReservationStatusX.parse(
        result['status']?.toString(),
      );
      setState(() {
        _item = _item.copyWith(status: status);
        _busy = false;
      });
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İptal tamamlanamadı. Lütfen tekrar deneyin.')),
      );
    }
  }
}
