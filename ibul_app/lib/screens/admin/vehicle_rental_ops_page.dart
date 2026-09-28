import 'package:flutter/material.dart';

import '../../features/vehicle/models/vehicle_commerce.dart';
import '../../features/vehicle/models/vehicle_enums.dart';
import '../../features/vehicle/services/vehicle_service.dart';
import '../../widgets/ibul_page_state.dart';

class VehicleRentalOpsPage extends StatefulWidget {
  const VehicleRentalOpsPage({super.key});

  @override
  State<VehicleRentalOpsPage> createState() => _VehicleRentalOpsPageState();
}

class _VehicleRentalOpsPageState extends State<VehicleRentalOpsPage> {
  bool _loading = true;
  String? _error;
  List<VehicleReservation> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await VehicleService.instance.reservations.listAllForAdmin();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
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
    if (_loading) return const IbulPageState.loading();
    if (_error != null) {
      return IbulPageState.error(title: _error!, onAction: _load);
    }
    if (_items.isEmpty) {
      return const IbulPageState.empty(
        icon: Icons.car_rental,
        title: 'Kiralama kaydı yok',
        message: 'Seller operasyonu yönetir. Admin yalnızca görünürlük sağlar.',
      );
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          title: Text(item.rentalCode ?? item.id),
          subtitle: Text(
            '${item.status.labelTr} · ödeme ${item.paymentStatus}\n'
            'müşteri ${item.customerId} · satıcı ${item.sellerId}',
          ),
          isThreeLine: true,
        );
      },
    );
  }
}
