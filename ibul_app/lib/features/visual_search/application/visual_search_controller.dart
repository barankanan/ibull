import 'package:flutter/foundation.dart';

import '../data/visual_search_image_memory.dart';
import '../data/visual_search_supabase.dart';
import '../domain/visual_search_models.dart';
import 'visual_search_service.dart';

class VisualSearchController extends ChangeNotifier {
  VisualSearchController({VisualSearchService? service, String? userId})
    : _service = service ?? VisualSearchService(),
      _userIdOverride = userId;

  static VisualSearchController? _shared;

  static VisualSearchController shared() {
    return _shared ??= VisualSearchController();
  }

  @visibleForTesting
  static void debugReset([VisualSearchController? next]) {
    _shared = next;
  }

  final VisualSearchService _service;
  final String? _userIdOverride;

  String? get userId => _userIdOverride ?? VisualSearchSupabase.currentUserId();

  VisualSearchPhase phase = VisualSearchPhase.idle;
  VisualSearchJob? activeJob;
  String? errorMessage;
  List<VisualSearchJob> history = const [];
  VisualSearchHistoryFilter filter = VisualSearchHistoryFilter.all;
  bool historyLoading = false;

  Uint8List? _lastBytes;
  String? _lastFileName;
  VisualSearchJobType? _lastType;

  List<VisualSearchJob> get visibleHistory =>
      filterVisualSearchHistory(history, filter);

  Uint8List? imageBytesFor(String jobId) => VisualSearchImageMemory.get(jobId);

  Future<VisualSearchJob?> findJob(String id) async {
    for (final job in history) {
      if (job.id == id) return job;
    }
    return _service.job(id);
  }

  Future<void> loadHistory() async {
    historyLoading = true;
    notifyListeners();
    history = await _service.history(userId: userId);
    historyLoading = false;
    notifyListeners();
  }

  void markSelecting() {
    phase = VisualSearchPhase.selectingImage;
    errorMessage = null;
    notifyListeners();
  }

  void markIdle() {
    if (phase == VisualSearchPhase.selectingImage) {
      phase = VisualSearchPhase.idle;
      notifyListeners();
    }
  }

  void setFilter(VisualSearchHistoryFilter value) {
    filter = value;
    notifyListeners();
  }

  Future<VisualSearchJob?> analyze({
    required VisualSearchJobType type,
    required Uint8List bytes,
    required String fileName,
    List<VisualCatalogItem> catalog = const [],
  }) async {
    _lastBytes = bytes;
    _lastFileName = fileName;
    _lastType = type;
    phase = VisualSearchPhase.uploading;
    errorMessage = null;
    activeJob = null;
    notifyListeners();
    try {
      final job = await _service.submit(
        type: type,
        bytes: bytes,
        fileName: fileName,
        userId: userId,
        catalog: catalog,
        onPhase: (next) {
          phase = next;
          notifyListeners();
        },
      );
      activeJob = job;
      phase = job.isEmptyResult
          ? VisualSearchPhase.empty
          : VisualSearchPhase.success;
      history = await _service.history(userId: userId);
      notifyListeners();
      return job;
    } on VisualSearchException catch (error) {
      phase = VisualSearchPhase.error;
      errorMessage = error.message;
      history = await _service.history(userId: userId);
      notifyListeners();
      return null;
    } catch (_) {
      phase = VisualSearchPhase.error;
      errorMessage = 'Bağlantı sırasında bir sorun oluştu. Tekrar deneyin.';
      notifyListeners();
      return null;
    }
  }

  Future<VisualSearchJob?> retry() {
    final bytes = _lastBytes;
    final name = _lastFileName;
    final type = _lastType;
    if (bytes == null || name == null || type == null) {
      return Future.value(null);
    }
    return analyze(type: type, bytes: bytes, fileName: name);
  }

  Future<void> remove(String id) async {
    await _service.delete(id);
    history = history.where((job) => job.id != id).toList();
    if (activeJob?.id == id) activeJob = null;
    notifyListeners();
  }

  Future<void> sendFeedback(String jobId, String feedbackType) {
    return _service.sendFeedback(
      jobId: jobId,
      feedbackType: feedbackType,
      userId: userId,
    );
  }
}
