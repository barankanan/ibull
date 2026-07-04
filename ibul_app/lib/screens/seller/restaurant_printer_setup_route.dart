import 'package:flutter/material.dart';

import '../../features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import '../../services/auth_service.dart';
import '../../services/store_service.dart';
import 'kitchen_print_management_page.dart';

/// Guarded entry for seller desktop `/printer-setup` route.
///
/// Non-food sellers see an ineligible message instead of bridge/printer setup.
class RestaurantPrinterSetupRoute extends StatefulWidget {
  const RestaurantPrinterSetupRoute({super.key});

  @override
  State<RestaurantPrinterSetupRoute> createState() =>
      _RestaurantPrinterSetupRouteState();
}

class _RestaurantPrinterSetupRouteState extends State<RestaurantPrinterSetupRoute> {
  bool _loading = true;
  bool _allowed = false;
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _resolveEligibility();
  }

  Future<void> _resolveEligibility() async {
    final sellerId = AuthService().currentUser?.id.trim() ?? '';
    if (sellerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _allowed = false;
        _restaurantId = null;
      });
      return;
    }

    try {
      final profile = await StoreService().getStoreProfileForSellerId(sellerId);
      final category = profile?['category']?.toString();
      if (!mounted) return;
      setState(() {
        _restaurantId = sellerId;
        _allowed = canUseRestaurantPrinterSystem(category);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restaurantId = sellerId;
        _allowed = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_allowed || _restaurantId == null || _restaurantId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yazıcı Ayarları')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.restaurant_outlined,
                  size: 48,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 16),
                Text(
                  restaurantPrinterIneligibleMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Geri dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return KitchenPrintManagementPage(restaurantId: _restaurantId!);
  }
}

/// Inline guard widget for [KitchenPrintManagementPage].
class RestaurantPrinterEligibilityGate extends StatelessWidget {
  const RestaurantPrinterEligibilityGate({
    super.key,
    required this.loading,
    required this.allowed,
    required this.child,
  });

  final bool loading;
  final bool allowed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yazıcı Ayarları')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.restaurant_outlined,
                  size: 48,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 16),
                Text(
                  restaurantPrinterIneligibleMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Geri dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return child;
  }
}
