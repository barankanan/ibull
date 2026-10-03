import 'package:ibul_app/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ibul_app/core/env.dart';
import 'dart:convert';

void main() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  final categories = await SupabaseService.instance.getCategoriesWithSubsStrict();
  final decodedMain = Uri.decodeComponent('Elektronik');
  final decodedSub = Uri.decodeComponent('Telefonlar');
  final mainId = int.tryParse(decodedMain);
  final subId = int.tryParse(decodedSub);
  
  final isMainMatch = (node) => 
      (mainId != null && node.mainCategory.id == mainId) || 
      (node.mainCategory.name == decodedMain);
      
  final isSubMatch = (sub, resolvedMainId) => 
      (subId != null && sub.id == subId) || 
      (sub.name == decodedSub && sub.parentId == resolvedMainId);

  bool found = false;
  for (final node in categories) {
    if (!isMainMatch(node) || !node.mainCategory.isActive) {
      continue;
    }
    print("Found main category: ${node.mainCategory.name}");
    for (final sub in node.subCategories) {
      if (!isSubMatch(sub, node.mainCategory.id) || !sub.isActive) {
        continue;
      }
      print("Found sub category: ${sub.name}");
      found = true;
      break;
    }
  }
  print("Found: $found");
}
