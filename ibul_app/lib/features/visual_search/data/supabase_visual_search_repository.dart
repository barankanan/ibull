import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/visual_search_models.dart';
import 'visual_search_repository.dart';
import 'visual_search_supabase.dart';

class SupabaseVisualSearchRepository implements VisualSearchRepository {
  static const bucket = 'visual-search-uploads';

  SupabaseClient? get _client => VisualSearchSupabase.clientOrNull();

  @override
  Future<void> saveJob(VisualSearchJob job) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null || job.userId != userId) return;
    await client.from('visual_search_jobs').upsert({
      'id': job.id,
      'user_id': userId,
      'image_url': job.imageUrl,
      'file_name': job.fileName,
      'job_type': job.jobType.wireName,
      'status': job.status.name,
      'analysis_result_json': job.analysis?.toJson(),
      'error_message': job.errorMessage,
      'created_at': job.createdAt.toUtc().toIso8601String(),
      'updated_at': job.updatedAt.toUtc().toIso8601String(),
    });
    if (job.status == VisualSearchJobStatus.completed && job.analysis != null) {
      await _replaceChildren(client, job);
      await client.from('visual_search_history').upsert({
        'id': job.id,
        'user_id': userId,
        'job_id': job.id,
        'created_at': job.createdAt.toUtc().toIso8601String(),
      });
    }
  }

  Future<void> _replaceChildren(
    SupabaseClient client,
    VisualSearchJob job,
  ) async {
    final analysis = job.analysis;
    if (analysis == null) return;
    await client.from('damage_reports').delete().eq('job_id', job.id);
    await client.from('missing_parts_reports').delete().eq('job_id', job.id);
    await client.from('product_matches').delete().eq('job_id', job.id);
    if (analysis.damages.isNotEmpty) {
      await client.from('damage_reports').insert([
        for (final damage in analysis.damages)
          {
            'id': damage.id,
            'job_id': job.id,
            'label': damage.label,
            'confidence': damage.confidence,
            'bbox_json': damage.bbox.toJson(),
            'description': damage.description,
          },
      ]);
    }
    if (analysis.missingParts.isNotEmpty) {
      await client.from('missing_parts_reports').insert([
        for (final part in analysis.missingParts)
          {
            'id': part.id,
            'job_id': job.id,
            'part_name': part.partName,
            'confidence': part.confidence,
            'bbox_json': part.bbox.toJson(),
            'details': part.details,
          },
      ]);
    }
    if (analysis.matches.isNotEmpty) {
      await client.from('product_matches').insert([
        for (final match in analysis.matches)
          {
            'id': match.id,
            'job_id': job.id,
            'product_id': match.productId,
            'similarity_score': match.similarityScore,
            'match_type': match.matchType.name,
            'metadata_json': match.toJson(),
          },
      ]);
    }
  }

  @override
  Future<VisualSearchJob?> getJob(String id) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return null;
    final row = await client
        .from('visual_search_jobs')
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return VisualSearchJob.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<VisualSearchJob>> listJobs({
    String? userId,
    VisualSearchJobType? type,
  }) async {
    final client = _client;
    final current = client?.auth.currentUser?.id;
    if (client == null || current == null) return const [];
    final rows = await client
        .from('visual_search_jobs')
        .select()
        .eq('user_id', current)
        .order('created_at', ascending: false)
        .limit(40);
    final jobs = <VisualSearchJob>[];
    for (final row in rows) {
      final job = VisualSearchJob.fromJson(Map<String, dynamic>.from(row));
      if (type != null && job.jobType != type) continue;
      jobs.add(job);
    }
    return jobs;
  }

  @override
  Future<void> deleteJob(String id) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    await client
        .from('visual_search_jobs')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  @override
  Future<String?> uploadImage({
    required String jobId,
    required String? userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final client = _client;
    final current = client?.auth.currentUser?.id;
    if (client == null || current == null || userId != current) return null;
    final extension = _extension(fileName);
    final path = '$current/$jobId.$extension';
    await client.storage.from(bucket).uploadBinary(
      path,
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      fileOptions: FileOptions(upsert: true, contentType: _mime(extension)),
    );
    return client.storage.from(bucket).createSignedUrl(path, 60 * 60 * 24 * 7);
  }

  @override
  Future<void> saveFeedback(VisualSearchFeedback feedback) async {
    final client = _client;
    if (client == null || feedback.userId == null) return;
    await client.from('user_visual_feedback').insert(feedback.toJson());
  }

  void logFailure(String action, Object error) {
    developer.log('visual search $action: $error', name: 'visual_search');
  }
}

String _extension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return 'jpg';
  return fileName.substring(dot + 1).toLowerCase();
}

String _mime(String extension) {
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
    case 'heif':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}
