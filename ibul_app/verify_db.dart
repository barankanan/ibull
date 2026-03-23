import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ihmixxzqnpamcwmrfibx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlobWl4eHpxbnBhbWN3bXJmaWJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDE0NTEsImV4cCI6MjA4NzI3NzQ1MX0.EZkjZAq2mwg-gfBhwotAGp4stb1D-rmWHuzVsz2yzX0',
  );

  print('Connecting to Supabase...');

  try {
    // Note: In newer supabase versions, select() returns a PostgrestTransformBuilder
    // which needs to be awaited to get the List<Map<String, dynamic>>
    final response = await client
        .from('system_layouts')
        .select();
    
    print('--- Current system_layouts ---');
      if (response.isEmpty) {
          print('Table is EMPTY.');
      } else {
          print('Found ${response.length} rows:');
          for (var row in response) {
              print('ID: ${row['id']}, Title: ${row['title']}, Slot: ${row['slot']}');
          }
      }
      print('------------------------------');

  } catch (e) {
    print('Error querying database: $e');
  }
}
