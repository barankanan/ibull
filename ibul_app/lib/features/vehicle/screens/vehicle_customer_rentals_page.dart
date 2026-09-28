import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../../../screens/login_page.dart';
import '../../../widgets/ibul_page_state.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_enums.dart';
import '../services/vehicle_service.dart';
import '../widgets/vehicle_rental_booking_card.dart';
import 'vehicle_rental_detail_page.dart';

class VehicleCustomerRentalsPage extends StatefulWidget {
  const VehicleCustomerRentalsPage({super.key});

  @override
  State<VehicleCustomerRentalsPage> createState() =>
      _VehicleCustomerRentalsPageState();
}

class _VehicleCustomerRentalsPageState extends State<VehicleCustomerRentalsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<VehicleReservation> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!context.read<AppState>().isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    final items = await VehicleService.instance.reservations.listMine(
      asSeller: false,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AppState>().isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Araç Kiralamalarım')),
        body: IbulPageState.empty(
          icon: Icons.lock_outline,
          title: 'Giriş yapın',
          actionLabel: 'Giriş',
          onAction: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LoginPage()),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Kiralamalarım'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Yaklaşan'),
            Tab(text: 'Aktif'),
            Tab(text: 'Tamamlanan'),
            Tab(text: 'İptal'),
          ],
        ),
      ),
      body: _loading
          ? const IbulPageState.loading()
          : TabBarView(
              controller: _tabs,
              children: [
                _list(_upcoming),
                _list(_active),
                _list(_done),
                _list(_cancelled),
              ],
            ),
    );
  }

  List<VehicleReservation> get _upcoming => _items
      .where(
        (item) =>
            item.status == VehicleReservationStatus.pendingSellerReview ||
            item.status == VehicleReservationStatus.pendingPayment ||
            item.status == VehicleReservationStatus.confirmed ||
            item.status == VehicleReservationStatus.reserved,
      )
      .toList();

  List<VehicleReservation> get _active => _items
      .where(
        (item) =>
            item.status == VehicleReservationStatus.activeRental ||
            item.status == VehicleReservationStatus.returnPending,
      )
      .toList();

  List<VehicleReservation> get _done => _items
      .where((item) => item.status == VehicleReservationStatus.completed)
      .toList();

  List<VehicleReservation> get _cancelled => _items
      .where(
        (item) =>
            item.status == VehicleReservationStatus.cancelled ||
            item.status == VehicleReservationStatus.rejected ||
            item.status == VehicleReservationStatus.sellerCancelled ||
            item.status == VehicleReservationStatus.refundPending,
      )
      .toList();

  Widget _list(List<VehicleReservation> rows) {
    if (rows.isEmpty) {
      return const IbulPageState.empty(
        icon: Icons.directions_car_outlined,
        title: 'Kiralama yok',
      );
    }
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final item = rows[index];
        return VehicleRentalBookingCard(
          item: item,
          title: item.listingTitle ?? item.rentalCode ?? item.status.labelTr,
          docsReady: true,
          onDetail: () => _openDetail(item),
          onCancel: item.status == VehicleReservationStatus.pendingSellerReview ||
                  item.status == VehicleReservationStatus.pendingPayment ||
                  item.status == VehicleReservationStatus.confirmed ||
                  item.status == VehicleReservationStatus.reserved
              ? () => _cancel(item)
              : null,
        );
      },
    );
  }

  Future<void> _openDetail(VehicleReservation item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleRentalDetailPage(reservation: item),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _cancel(VehicleReservation item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezervasyonu iptal et'),
        content: const Text(
          'İade tutarı satıcının iptal politikasına göre hesaplanır.',
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
    if (ok == true) {
      await VehicleService.instance.reservations.cancel(reservationId: item.id);
      await _load();
    }
  }
}
