import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/restaurant_lan_waiter_page.dart';

/// Opens the existing waiter device screen against the isolated LAN host.
/// It does not start Supabase and does not create another order system.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İBUL Garson Test',
      home: RestaurantLanWaiterPage(restaurantId: 'offline-test-restaurant'),
    ),
  );
}
