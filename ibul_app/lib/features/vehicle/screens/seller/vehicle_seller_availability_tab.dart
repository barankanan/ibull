import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../widgets/ibul_page_state.dart';
import '../../models/vehicle_enums.dart';
import '../../models/vehicle_listing.dart';
import '../../services/vehicle_service.dart';

class VehicleSellerAvailabilityTab extends StatefulWidget {
  const VehicleSellerAvailabilityTab({
    super.key,
    required this.sellerId,
    required this.stock,
  });

  final String sellerId;
  final List<VehicleListing> stock;

  @override
  State<VehicleSellerAvailabilityTab> createState() =>
      _VehicleSellerAvailabilityTabState();
}

class _VehicleSellerAvailabilityTabState
    extends State<VehicleSellerAvailabilityTab> {
  String? _listingId;
  String _blockKind = 'blocked';
  List<Map<String, dynamic>> _blocks = const [];
  bool _loading = false;

  List<VehicleListing> get _rentable =>
      widget.stock.where((row) => row.listingType.allowsRental).toList();

  @override
  void initState() {
    super.initState();
    if (_rentable.isNotEmpty) {
      _listingId = _rentable.first.id;
      _load();
    }
  }

  Future<void> _load() async {
    final id = _listingId;
    if (id == null) return;
    setState(() => _loading = true);
    final blocks = await VehicleService.instance.reservations.listBlocks(id);
    if (!mounted) return;
    setState(() {
      _blocks = blocks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_rentable.isEmpty) {
      return const IbulPageState.empty(
        icon: Icons.event_busy,
        title: 'Kiralık araç yok',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _listingId,
          items: [
            for (final listing in _rentable)
              DropdownMenuItem(value: listing.id, child: Text(listing.title)),
          ],
          onChanged: (v) {
            setState(() => _listingId = v);
            _load();
          },
          decoration: const InputDecoration(labelText: 'Araç'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _blockKind,
          items: const [
            DropdownMenuItem(value: 'blocked', child: Text('Kapalı')),
            DropdownMenuItem(value: 'maintenance', child: Text('Bakımda')),
          ],
          onChanged: (v) => setState(() => _blockKind = v ?? 'blocked'),
          decoration: const InputDecoration(labelText: 'Gün durumu'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _addBlock,
          child: const Text('Günü kapat / bakım'),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(),
        for (final block in _blocks)
          ListTile(
            title: Text(
              block['kind'] == 'maintenance' ? 'Bakımda' : 'Kapalı',
            ),
            subtitle: Text('${block['start_at']} → ${block['end_at']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () async {
                await VehicleService.instance.reservations.deleteBlock(
                  block['id'].toString(),
                );
                await _load();
              },
            ),
          ),
      ],
    );
  }

  Future<void> _addBlock() async {
    final id = _listingId;
    if (id == null) return;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      initialDate: DateTime.now(),
    );
    if (date == null) return;
    final start = DateTime(date.year, date.month, date.day);
    await VehicleService.instance.reservations.upsertBlock(
      listingId: id,
      sellerId: widget.sellerId,
      startAt: start,
      endAt: start.add(const Duration(days: 1)),
      kind: _blockKind,
    );
    await _load();
  }
}
