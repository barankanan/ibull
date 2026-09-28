import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../features/vehicle/models/vehicle_enums.dart';
import '../../features/vehicle/models/vehicle_listing.dart';
import '../../features/vehicle/services/vehicle_service.dart';
import '../../features/vehicle/widgets/vehicle_listing_detail_view.dart';
import '../../widgets/optimized_image.dart';

class VehicleListingApprovalPage extends StatefulWidget {
  const VehicleListingApprovalPage({super.key});

  @override
  State<VehicleListingApprovalPage> createState() =>
      _VehicleListingApprovalPageState();
}

class _VehicleListingApprovalPageState
    extends State<VehicleListingApprovalPage> {
  String _filter = 'pending_review';
  bool _loading = true;
  String? _error;
  List<VehicleListing> _items = const [];
  VehicleListing? _selected;

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
      final status = switch (_filter) {
        'pending_review' => 'pending_review',
        'approved' => 'active',
        'active' => 'active',
        'inactive' => 'inactive',
        'rejected' => 'draft',
        'draft' => 'draft',
        _ => null,
      };
      var items = await VehicleService.instance.listings.listForAdmin(
        status: status,
      );
      if (_filter == 'rejected') {
        items = items.where((e) => e.isRejected).toList(growable: false);
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        if (_selected != null) {
          _selected = items.where((e) => e.id == _selected!.id).firstOrNull;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Araç İlanları',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final entry in const [
                ('pending_review', 'Bekleyen'),
                ('approved', 'Onaylanan'),
                ('rejected', 'Reddedilen'),
                ('active', 'Yayında'),
                ('inactive', 'Yayından Kaldırılan'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: _filter == entry.$1,
                  selectedColor: AppColors.softPurple,
                  onSelected: (_) {
                    setState(() => _filter = entry.$1);
                    _load();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : _selected != null
              ? _detail(_selected!)
              : _list(),
        ),
      ],
    );
  }

  Widget _list() {
    if (_items.isEmpty) {
      return const Center(child: Text('Kayıt yok'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: SizedBox(
                  width: 92,
                  height: 68,
                  child: (item.coverUrl ?? '').isEmpty
                      ? const ColoredBox(
                          color: AppColors.surfaceMuted,
                          child: Icon(Icons.directions_car_outlined),
                        )
                      : OptimizedImage(
                          imageUrlOrPath: item.coverUrl!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      [
                        item.gallery?.name ?? item.sellerId,
                        if (item.salePrice != null)
                          '${item.salePrice!.round()} TL',
                        item.vehicleClass,
                        item.statusLabelTr,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                    Text(
                      'İlan ID: ${item.id}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selected = item),
                child: const Text('Detay'),
              ),
              if (item.status == VehicleListingStatus.pendingReview) ...[
                TextButton(
                  onPressed: () => _moderate(item, approve: true),
                  child: const Text('Onayla'),
                ),
                TextButton(
                  onPressed: () => _reject(item),
                  child: const Text('Reddet'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _detail(VehicleListing listing) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: VehicleListingDetailView(listing: listing, previewMode: true),
        ),
        SizedBox(
          width: 320,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextButton(
                onPressed: () => setState(() => _selected = null),
                child: const Text('Listeye dön'),
              ),
              Text('Mağaza: ${listing.gallery?.name ?? '-'}'),
              Text('Satıcı: ${listing.sellerId}'),
              Text('İlan ID: ${listing.id}'),
              Text('Durum: ${listing.statusLabelTr}'),
              Text('Oluşturma: ${listing.createdAt}'),
              const SizedBox(height: 16),
              if (listing.status == VehicleListingStatus.pendingReview) ...[
                FilledButton(
                  onPressed: () => _moderate(listing, approve: true),
                  child: const Text('ONAYLA'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _reject(listing),
                  child: const Text('REDDET'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reject(VehicleListing listing) async {
    String? selected = 'Eksik fotoğraf';
    final extra = TextEditingController();
    const reasons = [
      'Eksik fotoğraf',
      'Yanlış bilgi',
      'Fiyat sorunu',
      'Yasak içerik',
      'Diğer',
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('İlanı reddet'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (v) => setLocal(() => selected = v),
                    child: Column(
                      children: [
                        for (final reason in reasons)
                          RadioListTile<String>(
                            dense: true,
                            title: Text(reason),
                            value: reason,
                          ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: extra,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Açıklama',
                      border: OutlineInputBorder(),
                    ),
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
                  child: const Text('Reddet'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    final note = extra.text.trim().isEmpty
        ? selected!
        : '$selected: ${extra.text.trim()}';
    await _moderate(listing, approve: false, reason: note);
  }

  Future<void> _moderate(
    VehicleListing listing, {
    required bool approve,
    String? reason,
  }) async {
    try {
      await VehicleService.instance.listings.moderate(
        listingId: listing.id,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      _selected = null;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız. $error')));
    }
  }
}
