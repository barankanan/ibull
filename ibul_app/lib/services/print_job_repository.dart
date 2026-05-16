import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/print_job_model.dart';

class PrintJobRepository {
  PrintJobRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  bool _matchesStatus(PrintJobModel job, String status) {
    final normalizedFilter = status.trim().toLowerCase();
    if (normalizedFilter == 'completed' || normalizedFilter == 'printed') {
      return job.normalizedStatus == 'completed';
    }
    return job.normalizedStatus == normalizedFilter;
  }

  Stream<List<PrintJobModel>> watchJobs(String restaurantId, {String? status}) {
    final base = _client
        .from('print_jobs')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false);

    return base.map((rows) {
      final mapped = rows
          .map((row) => PrintJobModel.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      if (status == null || status == 'all') {
        return mapped;
      }
      return mapped
          .where((job) => _matchesStatus(job, status))
          .toList(growable: false);
    });
  }

  Future<List<PrintJobModel>> fetchJobs(
    String restaurantId, {
    String? status,
    int limit = 200,
  }) async {
    dynamic query = _client
        .from('print_jobs')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false)
        .limit(limit);

    if (status != null && status != 'all') {
      final normalizedStatus = status.trim().toLowerCase();
      if (normalizedStatus == 'completed' || normalizedStatus == 'printed') {
        query = query.inFilter('status', ['completed', 'printed']);
      } else {
        query = query.eq('status', normalizedStatus);
      }
    }

    final rows = await query;
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(PrintJobModel.fromMap).toList(growable: false);
  }

  Future<void> retryJob(String printJobId) async {
    final current = await _client
        .from('print_jobs')
        .select('retry_count')
        .eq('id', printJobId)
        .maybeSingle();
    final nextRetry = ((current?['retry_count'] as num?)?.toInt() ?? 0) + 1;

    await _client
        .from('print_jobs')
        .update({
          'status': 'pending',
          'retry_count': nextRetry,
          'last_error': null,
          'printed_at': null,
        })
        .eq('id', printJobId);
  }
}
