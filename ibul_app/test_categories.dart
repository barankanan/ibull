import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  final env = await File('.env').readAsString();
  final url = RegExp(r'SUPABASE_URL=(.+)').firstMatch(env)!.group(1)!;
  final key = RegExp(r'SUPABASE_ANON_KEY=(.+)').firstMatch(env)!.group(1)!;
  
  final client = SupabaseClient(url, key);
  
  final categories = await client.from('categories').select();
  print('--- CATEGORIES ---');
  print('Count: ${categories.length}');
  
  for (var c in categories) {
    print('${c['id']}: ${c['name']} (parent_id: ${c['parent_id']})');
  }
}
