import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/ads/repositories/ads_repository.dart';

void main() async {
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  
  final repo = AdsRepository();
  try {
    final res = await repo.getActiveHomeCollectionCampaigns();
    print("Success: \${res.length}");
  } catch (e) {
    print("Error: \$e");
  }
}
