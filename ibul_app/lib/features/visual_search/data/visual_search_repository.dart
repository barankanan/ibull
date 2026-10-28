import '../domain/visual_search_models.dart';

abstract class VisualSearchRepository {
  Future<void> saveJob(VisualSearchJob job);

  Future<VisualSearchJob?> getJob(String id);

  Future<List<VisualSearchJob>> listJobs({
    String? userId,
    VisualSearchJobType? type,
  });

  Future<void> deleteJob(String id);

  Future<String?> uploadImage({
    required String jobId,
    required String? userId,
    required List<int> bytes,
    required String fileName,
  });

  Future<void> saveFeedback(VisualSearchFeedback feedback);
}

class MemoryVisualSearchRepository implements VisualSearchRepository {
  final List<VisualSearchJob> _jobs = [];
  final List<VisualSearchFeedback> feedback = [];

  @override
  Future<void> saveJob(VisualSearchJob job) async {
    final index = _jobs.indexWhere((item) => item.id == job.id);
    if (index >= 0) {
      _jobs[index] = job;
    } else {
      _jobs.add(job);
    }
  }

  @override
  Future<VisualSearchJob?> getJob(String id) async {
    for (final job in _jobs) {
      if (job.id == id) return job;
    }
    return null;
  }

  @override
  Future<List<VisualSearchJob>> listJobs({
    String? userId,
    VisualSearchJobType? type,
  }) async {
    final jobs = _jobs.where((job) {
      if (userId != null && job.userId != userId) return false;
      if (type != null && job.jobType != type) return false;
      return true;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs;
  }

  @override
  Future<void> deleteJob(String id) async {
    _jobs.removeWhere((job) => job.id == id);
    feedback.removeWhere((item) => item.jobId == id);
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
    this.feedback.add(feedback);
  }
}
