import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

Future<void> testVehicleQuery(SupabaseClient client) async {
  try {
    final res = await client
        .from('vehicle_listings')
        .select('''
id, seller_id, listing_type, status, sale_price, city, district, cover_url,
vehicle_specs (brand, model, version, year, mileage_km, mileage_verified)
''')
        .eq('status', 'active')
        .order('published_at', ascending: false)
        .limit(5);
    print("TEST OK: \${res.length} rows");
  } catch(e) {
    print("TEST ERROR: \$e");
  }
}
