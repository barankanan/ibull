import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/desktop_printer_setup_models.dart';

class WorkingPrinterStore {
  static const String _storagePrefix = 'ibul_working_printer_v1_';

  Future<UnifiedPrinterModel?> load(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storagePrefix${restaurantId.trim()}');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return UnifiedPrinterModel.fromJson(decoded);
    } catch (error) {
      return null;
    }
  }

  Future<void> save(
    String restaurantId,
    UnifiedPrinterModel printer,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_storagePrefix${restaurantId.trim()}',
      jsonEncode(printer.toJson()),
    );
  }

  Future<void> clear(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_storagePrefix${restaurantId.trim()}');
  }
}
