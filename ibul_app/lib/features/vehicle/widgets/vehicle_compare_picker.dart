import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/vehicle_compare_fields.dart';
import '../domain/vehicle_compare_recommend.dart';
import '../domain/vehicle_compare_store.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_listing.dart';
import '../services/vehicle_service.dart';

class VehicleComparisonModal extends StatefulWidget {
  const VehicleComparisonModal({
    super.key,
    required this.current,
    this.similarVehicles = const [],
    this.search,
  });

  final VehicleListing current;
  final List<VehicleListing> similarVehicles;
  final Future<List<VehicleListing>> Function(String query)? search;

  static Future<bool> open(
    BuildContext context, {
    required VehicleListing current,
    List<VehicleListing> similarVehicles = const [],
    Future<List<VehicleListing>> Function(String query)? search,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleComparisonModal(
        current: current,
        similarVehicles: similarVehicles,
        search: search,
      ),
    );
    return confirmed == true;
  }

  @override
  State<VehicleComparisonModal> createState() => _VehicleComparisonModalState();
}

class _VehicleComparisonModalState extends State<VehicleComparisonModal> {
  final TextEditingController _searchController = TextEditingController();
  VehicleListing? _selected;
  List<VehicleListing> _suggested = const [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _suggested = VehicleCompareRecommend.rank(
      current: widget.current,
      candidates: widget.similarVehicles,
    );
    unawaited(_loadRecommended());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<VehicleListing>> _query(String text) async {
    if (widget.search != null) return widget.search!(text);
    try {
      return await VehicleService.instance.listings.search(
        VehicleSearchQuery(
          text: text.trim().isEmpty ? null : text.trim(),
          limit: 40,
        ),
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadRecommended() async {
    final current = widget.current;
    if (widget.search != null) {
      final hits = await widget.search!('');
      if (!mounted) return;
      setState(() {
        _suggested = VehicleCompareRecommend.rank(
          current: current,
          candidates: [...widget.similarVehicles, ...hits],
        );
      });
      return;
    }
    final merged = [...widget.similarVehicles];
    try {
      final brand = current.specs.brand.trim();
      final model = current.specs.model.trim();
      if (brand.isNotEmpty && model.isNotEmpty) {
        merged.addAll(
          await VehicleService.instance.listings.search(
            VehicleSearchQuery(brand: brand, model: model, limit: 20),
          ),
        );
      }
      if (brand.isNotEmpty) {
        merged.addAll(
          await VehicleService.instance.listings.search(
            VehicleSearchQuery(brand: brand, limit: 20),
          ),
        );
      }
      merged.addAll(
        await _query('${current.specs.brand} ${current.specs.model}'),
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _suggested = VehicleCompareRecommend.rank(
        current: current,
        candidates: merged,
      );
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_runSearch(value));
    });
  }

  Future<void> _runSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      await _loadRecommended();
      return;
    }
    setState(() => _loading = true);
    final hits = await _query(query);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _suggested = VehicleCompareRecommend.rank(
        current: widget.current,
        candidates: hits,
      );
    });
  }

  void _confirm() {
    final selected = _selected;
    if (selected == null) return;
    VehicleCompareStore.instance.setSelection([widget.current, selected]);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Araç Karşılaştırma',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _slotCard(widget.current, removable: false)),
                const SizedBox(width: 12),
                const Icon(
                  Icons.compare_arrows,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selected == null
                      ? _emptySlot()
                      : _slotCard(_selected!, removable: true),
                ),
              ],
            ),
          ),
          const Divider(thickness: 4, color: Color(0xFFF5F5F5)),
          Expanded(child: _suggestionList()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _selected == null ? null : _confirm,
                  child: const Text('Karşılaştır'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotCard(VehicleListing listing, {required bool removable}) {
    final image = listing.coverUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 72,
                width: double.infinity,
                child: image == null || image.isEmpty
                    ? const Icon(
                        Icons.directions_car_outlined,
                        color: Colors.grey,
                      )
                    : OptimizedImage(imageUrlOrPath: image, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              Text(
                listing.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (listing.specs.year > 0)
                Text(
                  '${listing.specs.year}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                VehicleCompareFields.headlinePrice(listing),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        if (removable)
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: () => setState(() => _selected = null),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptySlot() {
    return Container(
      constraints: const BoxConstraints(minHeight: 148),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary, size: 32),
            SizedBox(height: 8),
            Text(
              'Araç Seç',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            key: const ValueKey('vehicle-compare-search'),
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Karşılaştırmak için araç ara...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Önerilen Araçlar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _suggested.isEmpty
              ? Center(
                  child: Text(
                    'Sonuç bulunamadı',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _suggested.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final listing = _suggested[index];
                    return ListTile(
                      key: ValueKey('vehicle-compare-pick-${listing.id}'),
                      onTap: () => setState(() => _selected = listing),
                      contentPadding: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: SizedBox(
                        width: 60,
                        height: 60,
                        child:
                            listing.coverUrl == null ||
                                listing.coverUrl!.isEmpty
                            ? const Icon(Icons.directions_car_outlined)
                            : OptimizedImage(
                                imageUrlOrPath: listing.coverUrl!,
                                fit: BoxFit.cover,
                              ),
                      ),
                      title: Text(
                        listing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        [
                          VehicleCompareFields.listingKind(listing),
                          VehicleCompareFields.headlinePrice(listing),
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
