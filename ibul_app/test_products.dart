import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  final env = await File('.env').readAsString();
  final url = RegExp(r'SUPABASE_URL=(.+)').firstMatch(env)!.group(1)!;
  final key = RegExp(r'SUPABASE_ANON_KEY=(.+)').firstMatch(env)!.group(1)!;
  
  final client = SupabaseClient(url, key);
  
  final products = await client.from('products').select('name, main_category, sub_category');
  print('--- PRODUCTS ---');
  print('Count: ${products.length}');
  
  final Map<String, int> categories = {};
  for (var p in products) {
    final cat = '${p['main_category']} -> ${p['sub_category']}';
    categories[cat] = (categories[cat] ?? 0) + 1;
  }
  
  categories.forEach((k, v) => print('$k : $v'));
}
