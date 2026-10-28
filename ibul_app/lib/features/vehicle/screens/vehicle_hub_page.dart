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
  VehicleHubBrowse _browse = const VehicleHubBrowse();

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
                  const SizedBox(height: 12),
                  _browseBar(),
                  const SizedBox(height: 20),
                  if (!_browse.rentalOnly)
                    _rail('Satılık araçlar', _browse.apply(_sale, rental: false)),
                  if (!_browse.saleOnly) ...[
                    const SizedBox(height: 20),
                    _rail(
                      'Kiralık araçlar',
                      _browse.apply(_rental, rental: true),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _browseBar() {
    final pool = [..._sale, ..._rental];
    return Row(
      children: [
        TextButton.icon(
          key: const ValueKey('vehicle-hub-filter'),
          onPressed: () => _openFilter(pool),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Filtrele'),
        ),
        TextButton.icon(
          key: const ValueKey('vehicle-hub-sort'),
          onPressed: _openSort,
          icon: const Icon(Icons.swap_vert_rounded, size: 18),
          label: const Text('Sırala'),
        ),
      ],
    );
  }

  Future<void> _openFilter(List<VehicleListing> pool) async {
    final next = await showModalBottomSheet<VehicleHubBrowse>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _VehicleFilterSheet(initial: _browse, pool: pool),
    );
    if (next == null || !mounted) return;
    setState(() => _browse = next);
  }

  Future<void> _openSort() async {
    final next = await showModalBottomSheet<VehicleHubSort>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _VehicleSortSheet(initial: _browse.sort),
    );
    if (next == null || !mounted) return;
    setState(() => _browse = _browse.copyWith(sort: next));
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

enum VehicleHubSort { recommended, priceAsc, priceDesc, newest, yearDesc, kmAsc }

class VehicleHubBrowse {
  const VehicleHubBrowse({
    this.saleOnly = false,
    this.rentalOnly = false,
    this.brand,
    this.sort = VehicleHubSort.recommended,
  });

  final bool saleOnly;
  final bool rentalOnly;
  final String? brand;
  final VehicleHubSort sort;

  VehicleHubBrowse copyWith({
    bool? saleOnly,
    bool? rentalOnly,
    String? brand,
    bool clearBrand = false,
    VehicleHubSort? sort,
  }) {
    return VehicleHubBrowse(
      saleOnly: saleOnly ?? this.saleOnly,
      rentalOnly: rentalOnly ?? this.rentalOnly,
      brand: clearBrand ? null : (brand ?? this.brand),
      sort: sort ?? this.sort,
    );
  }

  List<VehicleListing> apply(List<VehicleListing> source, {required bool rental}) {
    final filtered = source.where((listing) {
      final wanted = brand?.trim();
      if (wanted != null && wanted.isNotEmpty && listing.specs.brand != wanted) {
        return false;
      }
      return true;
    }).toList();
    filtered.sort((a, b) => _compare(a, b, rental: rental));
    return filtered;
  }

  int _compare(VehicleListing a, VehicleListing b, {required bool rental}) {
    switch (sort) {
      case VehicleHubSort.recommended:
        return 0;
      case VehicleHubSort.priceAsc:
        return _price(a, rental).compareTo(_price(b, rental));
      case VehicleHubSort.priceDesc:
        return _price(b, rental).compareTo(_price(a, rental));
      case VehicleHubSort.newest:
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      case VehicleHubSort.yearDesc:
        return b.specs.year.compareTo(a.specs.year);
      case VehicleHubSort.kmAsc:
        return (a.specs.mileageKm ?? 1 << 30).compareTo(b.specs.mileageKm ?? 1 << 30);
    }
  }

  double _price(VehicleListing listing, bool rental) {
    if (rental) return listing.rental?.dailyPrice ?? double.infinity;
    return listing.salePrice ?? double.infinity;
  }
}

class _VehicleSortSheet extends StatelessWidget {
  const _VehicleSortSheet({required this.initial});

  final VehicleHubSort initial;

  @override
  Widget build(BuildContext context) {
    const options = <(VehicleHubSort, String)>[
      (VehicleHubSort.recommended, 'Önerilen'),
      (VehicleHubSort.priceAsc, 'Fiyat artan'),
      (VehicleHubSort.priceDesc, 'Fiyat azalan'),
      (VehicleHubSort.newest, 'En yeni ilan'),
      (VehicleHubSort.yearDesc, 'Yıl yeni'),
      (VehicleHubSort.kmAsc, 'KM düşük'),
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            ListTile(
              title: Text(option.$2),
              trailing: option.$1 == initial
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, option.$1),
            ),
        ],
      ),
    );
  }
}

class _VehicleFilterSheet extends StatefulWidget {
  const _VehicleFilterSheet({required this.initial, required this.pool});

  final VehicleHubBrowse initial;
  final List<VehicleListing> pool;

  @override
  State<_VehicleFilterSheet> createState() => _VehicleFilterSheetState();
}

class _VehicleFilterSheetState extends State<_VehicleFilterSheet> {
  late VehicleHubBrowse _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final brands = widget.pool
        .map((listing) => listing.specs.brand.trim())
        .where((brand) => brand.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtrele', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Satılık'),
                  selected: _draft.saleOnly,
                  onSelected: (value) => setState(() {
                    _draft = _draft.copyWith(saleOnly: value, rentalOnly: value ? false : _draft.rentalOnly);
                  }),
                ),
                FilterChip(
                  label: const Text('Kiralık'),
                  selected: _draft.rentalOnly,
                  onSelected: (value) => setState(() {
                    _draft = _draft.copyWith(rentalOnly: value, saleOnly: value ? false : _draft.saleOnly);
                  }),
                ),
                for (final brand in brands)
                  FilterChip(
                    label: Text(brand),
                    selected: _draft.brand == brand,
                    onSelected: (value) => setState(() {
                      _draft = value
                          ? _draft.copyWith(brand: brand)
                          : _draft.copyWith(clearBrand: true);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _draft),
                child: const Text('Uygula'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
