import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/ibul_chrome.dart';
import '../../../widgets/ibul_page_state.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_listing.dart';
import '../navigation/vehicle_routes.dart';
import '../services/vehicle_service.dart';
import '../widgets/vehicle_card.dart';

class VehicleHubPage extends StatefulWidget {
  const VehicleHubPage({super.key});

  @override
  State<VehicleHubPage> createState() => _VehicleHubPageState();
}

class _VehicleHubPageState extends State<VehicleHubPage> {
  bool _loading = true;
  String? _error;
  List<VehicleListing> _sale = const [];
  List<VehicleListing> _rental = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = VehicleService.instance;
      final sale = await service.listings.search(
        const VehicleSearchQuery(saleOnly: true, limit: 24),
      );
      final rental = await service.listings.search(
        const VehicleSearchQuery(rentalOnly: true, limit: 24),
      );
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _rental = rental;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Araçlar yüklenemedi. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text(
          'Araç',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Arama',
            icon: const Icon(Icons.search),
            onPressed: () => VehicleRoutes.openSearch(context),
          ),
        ],
      ),
      body: _loading
          ? const IbulPageState.loading(loadingMessage: 'Araçlar yükleniyor')
          : _error != null
          ? IbulPageState.error(title: _error!, onAction: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                children: [
                  _entryRow(context),
                  const SizedBox(height: 20),
                  _rail('Satılık araçlar', _sale),
                  const SizedBox(height: 20),
                  _rail('Kiralık araçlar', _rental),
                ],
              ),
            ),
    );
  }

  Widget _entryRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _tile(
            icon: Icons.search,
            label: 'Araç ara',
            onTap: () => VehicleRoutes.openSearch(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _tile(
            icon: Icons.map_outlined,
            label: 'Yakınımdaki galeriler',
            onTap: () => VehicleRoutes.openMap(context),
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rail(String title, List<VehicleListing> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Henüz ilan yok.',
              style: TextStyle(color: AppColors.textGrey),
            ),
          )
        else
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  VehicleCard(listing: items[index]),
            ),
          ),
        if (IbulChrome.isWebOf(context)) const SizedBox(height: 4),
      ],
    );
  }
}
