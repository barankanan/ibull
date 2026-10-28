import '../domain/visual_search_models.dart';
import 'local_visual_search_repository.dart';
import 'supabase_visual_search_repository.dart';
import 'visual_search_repository.dart';

/// Local history is the source the UI can always read. Supabase is best-effort.
class HybridVisualSearchRepository implements VisualSearchRepository {
  HybridVisualSearchRepository({
    VisualSearchRepository? local,
    SupabaseVisualSearchRepository? remote,
  }) : _local = local ?? LocalVisualSearchRepository(),
       _remote = remote ?? SupabaseVisualSearchRepository();

  final VisualSearchRepository _local;
  final SupabaseVisualSearchRepository _remote;

  @override
  Future<void> saveJob(VisualSearchJob job) async {
    await _local.saveJob(job);
    try {
      await _remote.saveJob(job);
    } catch (error) {
      _remote.logFailure('save', error);
    }
  }

  @override
  Future<VisualSearchJob?> getJob(String id) async {
    final local = await _local.getJob(id);
    if (local != null) return local;
    try {
      return await _remote.getJob(id);
    } catch (error) {
      _remote.logFailure('get', error);
      return null;
    }
  }

  @override
  Future<List<VisualSearchJob>> listJobs({
    String? userId,
    VisualSearchJobType? type,
  }) async {
    final local = await _local.listJobs(userId: userId, type: type);
    List<VisualSearchJob> remote = const [];
    try {
      remote = await _remote.listJobs(userId: userId, type: type);
    } catch (error) {
      _remote.logFailure('list', error);
    }
    if (remote.isEmpty) return local;
    final merged = <String, VisualSearchJob>{
      for (final job in local) job.id: job,
    };
    for (final job in remote) {
      final existing = merged[job.id];
      merged[job.id] = existing == null
          ? job
          : job.copyWith(previewDataUrl: existing.previewDataUrl);
    }
    final jobs = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs;
  }

  @override
  Future<void> deleteJob(String id) async {
    await _local.deleteJob(id);
    try {
      await _remote.deleteJob(id);
    } catch (error) {
      _remote.logFailure('delete', error);
    }
  }

  @override
  Future<String?> uploadImage({
    required String jobId,
    required String? userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      return await _remote.uploadImage(
        jobId: jobId,
        userId: userId,
        bytes: bytes,
        fileName: fileName,
      );
    } catch (error) {
      _remote.logFailure('upload', error);
      return null;
    }
  }

  @override
  Future<void> saveFeedback(VisualSearchFeedback feedback) async {
    await _local.saveFeedback(feedback);
    try {
      await _remote.saveFeedback(feedback);
    } catch (error) {
      _remote.logFailure('feedback', error);
    }
  }
}
