import 'dart:io';

void main() async {
  // Initialize FFI
  // sqfliteFfiInit();
  // databaseFactory = databaseFactoryFfi;

  // final dbPath = join(Directory.current.path, 'ibul_app.db'); // Assuming db is in root for this test, but it's actually in app sandbox
  // We cannot easily access the app's sandbox DB from here.
  
  // Instead, let's verify the JSON content programmatically to be 100% sure
  final file = File('ibul_app/assets/urunler.json');
  final content = await file.readAsString();
  
  print('Content length: ${content.length}');
  
  // Simple regex check
  final pattern = RegExp(r'"isim": "iPhone 15 Pro Max (Mavi|Beyaz)".*?"varyant_grup_id": "(.*?)"', multiLine: true, dotAll: true);
  
  final matches = pattern.allMatches(content);
  for (final match in matches) {
    print('Found: ${match.group(1)} - GroupID: ${match.group(2)}');
  }
}
