import 'dart:io';

import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    AppRuntimeConfig.supabaseUrl,
    AppRuntimeConfig.supabaseAnonKey,
  );

  stdout.writeln('Connecting to Supabase...');

  try {
    // Note: In newer supabase versions, select() returns a PostgrestTransformBuilder
    // which needs to be awaited to get the List<Map<String, dynamic>>
    final response = await client.from('system_layouts').select();

    stdout.writeln('--- Current system_layouts ---');
    if (response.isEmpty) {
      stdout.writeln('Table is EMPTY.');
    } else {
      stdout.writeln('Found ${response.length} rows:');
      for (var row in response) {
        stdout.writeln(
          'ID: ${row['id']}, Title: ${row['title']}, Slot: ${row['slot']}',
        );
      }
    }
    stdout.writeln('------------------------------');
  } catch (e) {
    stderr.writeln('Error querying database: $e');
  }
}
