import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../widgets/ibul_page_state.dart';
import '../../domain/vehicle_listing_validation.dart';
import '../../models/vehicle_commerce.dart';
import '../../models/vehicle_enums.dart';
import '../../models/vehicle_listing.dart';
import '../../navigation/vehicle_routes.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/vehicle_seller_stock_tile.dart';
import 'vehicle_seller_availability_tab.dart';
import 'vehicle_seller_rental_requests_tab.dart';

class VehicleSellerModulePage extends StatefulWidget {
  const VehicleSellerModulePage({super.key, required this.sellerId});

  final String sellerId;

  @override
  State<VehicleSellerModulePage> createState() =>
      _VehicleSellerModulePageState();
}

class _VehicleSellerModulePageState extends State<VehicleSellerModulePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs;
  VehicleDashboardStats _stats = VehicleDashboardStats.empty;
  List<VehicleListing> _stock = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final stats = await VehicleService.instance.operations.dashboard();
      final stock = await VehicleService.instance.listings.listBySeller(
        widget.sellerId,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _stock = stock;
        _loading = false;
      });
    } catch (error) {
      debugPrint('[vehicle] seller stock load failed: $error');
      if (!mounted) return;
      setState(() {
        _error = VehiclePublishErrorMapper.loadFailure(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const IbulPageState.loading();
    if (_error != null) {
      return IbulPageState.error(title: _error!, onAction: _load);
    }
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Stok'),
            Tab(text: 'Randevu'),
            Tab(text: 'Teklif'),
            Tab(text: 'Kiralama Talepleri'),
            Tab(text: 'Müsaitlik'),
            Tab(text: 'Operasyon'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _stockTab(),
              _appointmentsTab(),
              _quotesTab(),
              const VehicleSellerRentalRequestsTab(),
              VehicleSellerAvailabilityTab(
                sellerId: widget.sellerId,
                stock: _stock,
              ),
              _opsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, int value) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  int _stockCount(VehicleListingStatus status) =>
      _stock.where((e) => e.status == status).length;

  Widget _stockTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('Toplam', _stock.length),
              _metric('Aktif', _stockCount(VehicleListingStatus.active)),
              _metric(
                'Kiralık',
                _stock.where((e) => e.listingType.allowsRental).length,
              ),
              _metric('Rezerve', _stockCount(VehicleListingStatus.reserved)),
              _metric('Satılmış', _stockCount(VehicleListingStatus.sold)),
              _metric('Bakımda', _stats.maintenance),
              _metric('Görüntülenme', _stats.views),
              _metric('Favori', _stats.favorites),
              _metric('Teklif', _stats.quotes),
              _metric('Aktif kiralama', _stats.activeRentals),
              _metric('Bekleyen talep', _stats.newReservations),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () async {
                final created = await VehicleRoutes.openWizard(context);
                if (created == true && mounted) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Araç Ekle'),
            ),
          ),
          const SizedBox(height: 12),
          if (_stock.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('Henüz araç yok. Araç Ekle ile ilan oluşturun.'),
            ),
          for (final listing in _stock)
            VehicleSellerStockTile(
              listing: listing,
              onEdit: () async {
                final updated = await VehicleRoutes.openWizard(
                  context,
                  listingId: listing.id,
                );
                if (updated == true && mounted) _load();
              },
              onPreview: () async {
                await VehicleRoutes.openDetail(
                  context,
                  listing.id,
                  preview: true,
                );
                if (mounted) await _load();
              },
              onPublish: () => _runStatus(() {
                return VehicleService.instance.listings.submitForReview(
                  listing.id,
                );
              }),
              onUnpublish: () => _runStatus(() {
                return VehicleService.instance.listings.unpublish(listing.id);
              }),
              onSold: () => _runStatus(() {
                return VehicleService.instance.listings.markSold(listing.id);
              }),
              onDelete: () => _confirmDelete(listing),
            ),
        ],
      ),
    );
  }

  Widget _appointmentsTab() {
    return FutureBuilder(
      future: VehicleService.instance.appointments.listForSeller(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const IbulPageState.empty(
            icon: Icons.event_outlined,
            title: 'Randevu yok',
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item.status.wire),
              subtitle: Text(item.scheduledAt.toLocal().toString()),
              trailing: Wrap(
                children: [
                  TextButton(
                    onPressed: () => VehicleService.instance.appointments
                        .respond(appointmentId: item.id, action: 'confirm'),
                    child: const Text('Onayla'),
                  ),
                  TextButton(
                    onPressed: () => VehicleService.instance.appointments
                        .respond(appointmentId: item.id, action: 'reject'),
                    child: const Text('Reddet'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _quotesTab() {
    return FutureBuilder(
      future: VehicleService.instance.quotes.listForSeller(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const IbulPageState.empty(
            icon: Icons.request_quote_outlined,
            title: 'Teklif yok',
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text('₺${item.amount.round()}'),
              subtitle: Text(item.status.wire),
              trailing: Wrap(
                children: [
                  TextButton(
                    onPressed: () => VehicleService.instance.quotes.respond(
                      quoteId: item.id,
                      action: 'accept',
                    ),
                    child: const Text('Kabul'),
                  ),
                  TextButton(
                    onPressed: () => VehicleService.instance.quotes.respond(
                      quoteId: item.id,
                      action: 'reject',
                    ),
                    child: const Text('Red'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _opsTab() {
    if (_stock.isEmpty) {
      return const IbulPageState.empty(
        icon: Icons.build_outlined,
        title: 'Önce araç ekleyin',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Servis, bakım, muayene, sigorta, lastik, ekspertiz ve KM',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ..._stock.map((listing) {
          return ListTile(
            title: Text(listing.title),
            subtitle: Text(listing.status.wire),
            trailing: TextButton(
              onPressed: () => _addMaintenance(listing),
              child: const Text('Kayıt ekle'),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addMaintenance(VehicleListing listing) async {
    final title = TextEditingController();
    final kind = ValueNotifier<String>('service');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${listing.title} · operasyon'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kind.value,
                items: const [
                  DropdownMenuItem(value: 'service', child: Text('Servis')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Bakım')),
                  DropdownMenuItem(value: 'inspection', child: Text('Muayene')),
                  DropdownMenuItem(value: 'insurance', child: Text('Sigorta')),
                  DropdownMenuItem(value: 'tire', child: Text('Lastik')),
                  DropdownMenuItem(
                    value: 'expertise',
                    child: Text('Ekspertiz'),
                  ),
                  DropdownMenuItem(value: 'km', child: Text('KM')),
                ],
                onChanged: (v) => kind.value = v ?? 'service',
                decoration: const InputDecoration(labelText: 'Tür'),
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      await VehicleService.instance.operations.addMaintenance(
        listingId: listing.id,
        sellerId: widget.sellerId,
        kind: kind.value,
        title: title.text.trim(),
      );
    }
    title.dispose();
  }

  Future<void> _runStatus(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _load();
    } catch (error) {
      debugPrint('[vehicle] seller status action failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(VehiclePublishErrorMapper.fromObject(error))),
      );
    }
  }

  Future<void> _confirmDelete(VehicleListing listing) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı sil'),
        content: Text('${listing.title} kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _runStatus(() {
      return VehicleService.instance.listings.deleteListing(listing.id);
    });
  }
}
