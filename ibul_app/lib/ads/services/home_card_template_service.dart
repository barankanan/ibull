import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/home_card_template.dart';

class HomeCardTemplateService {
  HomeCardTemplateService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _table = 'home_card_templates';

  Future<List<HomeCardTemplate>> getActiveTemplates() async {
    try {
      final res = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .order('sort_order')
          .order('title');
      return _parseList(res);
    } catch (e) {
      debugPrint('HomeCardTemplateService.getActiveTemplates: $e');
      return [];
    }
  }

  Future<List<HomeCardTemplate>> getAllTemplates() async {
    try {
      final res = await _client
          .from(_table)
          .select()
          .order('category_name')
          .order('sort_order')
          .order('title');
      return _parseList(res);
    } catch (e) {
      debugPrint('HomeCardTemplateService.getAllTemplates: $e');
      return [];
    }
  }

  Future<HomeCardTemplate?> getById(String id) async {
    try {
      final res = await _client.from(_table).select().eq('id', id).maybeSingle();
      if (res == null) return null;
      return HomeCardTemplate.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('HomeCardTemplateService.getById: $e');
      return null;
    }
  }

  Future<HomeCardTemplate> saveTemplate(HomeCardTemplate template) async {
    final payload = template.toJson();
    if (template.id.isEmpty) {
      payload.remove('id');
    }
    final res = await _client
        .from(_table)
        .upsert(payload)
        .select()
        .single();
    return HomeCardTemplate.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> deleteTemplate(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  List<HomeCardTemplate> _parseList(dynamic res) {
    if (res is! List) return [];
    return res
        .map((e) => HomeCardTemplate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
