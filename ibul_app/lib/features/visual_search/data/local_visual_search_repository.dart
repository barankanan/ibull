import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/visual_search_models.dart';
import 'visual_search_repository.dart';

class LocalVisualSearchRepository implements VisualSearchRepository {
  LocalVisualSearchRepository({SharedPreferences? preferences})
    : _preferences = preferences;

  static const storageKey = 'visual_search_jobs_v1';
  static const feedbackKey = 'visual_search_feedback_v1';
  static const maxJobs = 40;

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<void> saveJob(VisualSearchJob job) async {
    final jobs = await _read();
    final index = jobs.indexWhere((item) => item.id == job.id);
    if (index >= 0) {
      jobs[index] = job;
    } else {
      jobs.insert(0, job);
    }
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final trimmed = jobs.length > maxJobs ? jobs.sublist(0, maxJobs) : jobs;
    await _write(trimmed);
  }

  @override
  Future<VisualSearchJob?> getJob(String id) async {
    for (final job in await _read()) {
      if (job.id == id) return job;
    }
    return null;
  }

  @override
  Future<List<VisualSearchJob>> listJobs({
    String? userId,
    VisualSearchJobType? type,
  }) async {
    return (await _read()).where((job) {
      if (userId != null && job.userId != userId) return false;
      if (type != null && job.jobType != type) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> deleteJob(String id) async {
    final jobs = await _read();
    jobs.removeWhere((job) => job.id == id);
    await _write(jobs);
  }

  @override
  Future<String?> uploadImage({
    required String jobId,
    required String? userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    return null;
  }

  @override
  Future<void> saveFeedback(VisualSearchFeedback feedback) async {
    final prefs = await _prefs();
    final raw = prefs.getString(feedbackKey);
    final list = raw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
    list.insert(0, feedback.toJson());
    await prefs.setString(feedbackKey, jsonEncode(list.take(80).toList()));
  }

  Future<List<VisualSearchJob>> _read() async {
    final raw = (await _prefs()).getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => VisualSearchJob.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _write(List<VisualSearchJob> jobs) async {
    final prefs = await _prefs();
    await prefs.setString(
      storageKey,
      jsonEncode(jobs.map((job) => job.toJson()).toList()),
    );
  }
}
