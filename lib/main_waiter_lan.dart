import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/restaurant_lan_waiter_page.dart';

/// Opens the existing waiter device screen against the isolated LAN host.
/// It does not start Supabase and does not create another order system.
/// The center refuses a device that names another restaurant, so a test
/// build for a real phone is given the test restaurant's id at build time.
const String _restaurantId = String.fromEnvironment(
  'IBUL_WAITER_RESTAURANT_ID',
  defaultValue: 'offline-test-restaurant',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İBUL Garson Test',
      home: RestaurantLanWaiterPage(restaurantId: _restaurantId),
    ),
  );
}
