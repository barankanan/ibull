part of 'visual_search_models.dart';

extension VisualSearchJobTypeWire on VisualSearchJobType {
  String get wireName {
    switch (this) {
      case VisualSearchJobType.visualSearch:
        return 'visual_search';
      case VisualSearchJobType.damageAnalysis:
        return 'damage_analysis';
      case VisualSearchJobType.missingPartsAnalysis:
        return 'missing_parts_analysis';
      case VisualSearchJobType.combined:
        return 'combined';
    }
  }

  String get label {
    switch (this) {
      case VisualSearchJobType.visualSearch:
        return 'Görsel arama';
      case VisualSearchJobType.damageAnalysis:
        return 'Hasar analizi';
      case VisualSearchJobType.missingPartsAnalysis:
        return 'Eksik parça';
      case VisualSearchJobType.combined:
        return 'Görsel zeka';
    }
  }

  static VisualSearchJobType fromWire(String? value) {
    switch (value) {
      case 'visual_search':
        return VisualSearchJobType.visualSearch;
      case 'damage_analysis':
        return VisualSearchJobType.damageAnalysis;
      case 'missing_parts_analysis':
        return VisualSearchJobType.missingPartsAnalysis;
      default:
        return VisualSearchJobType.combined;
    }
  }
}

extension VisualSearchJobStatusLabel on VisualSearchJobStatus {
  String get label {
    switch (this) {
      case VisualSearchJobStatus.pending:
        return 'Sırada';
      case VisualSearchJobStatus.processing:
        return 'İşleniyor';
      case VisualSearchJobStatus.completed:
        return 'Tamamlandı';
      case VisualSearchJobStatus.failed:
        return 'Başarısız';
    }
  }
}

List<VisualSearchJob> filterVisualSearchHistory(
  List<VisualSearchJob> jobs,
  VisualSearchHistoryFilter filter,
) {
  switch (filter) {
    case VisualSearchHistoryFilter.all:
      return jobs;
    case VisualSearchHistoryFilter.visualSearch:
      return jobs
          .where((job) => job.jobType == VisualSearchJobType.visualSearch)
          .toList();
    case VisualSearchHistoryFilter.intelligence:
      return jobs
          .where((job) => job.jobType == VisualSearchJobType.combined)
          .toList();
    case VisualSearchHistoryFilter.damage:
      return jobs
          .where((job) => job.jobType == VisualSearchJobType.damageAnalysis)
          .toList();
    case VisualSearchHistoryFilter.missingParts:
      return jobs
          .where(
            (job) => job.jobType == VisualSearchJobType.missingPartsAnalysis,
          )
          .toList();
  }
}

String formatVisualSearchDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String newVisualSearchId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String visualSearchSummaryLine(VisualSearchJob job) {
  final analysis = job.analysis;
  if (job.status == VisualSearchJobStatus.failed) {
    return job.errorMessage ?? 'Analiz tamamlanamadı';
  }
  if (analysis == null) return 'Sonuç bekleniyor';
  if (job.isEmptyResult) return 'Sonuç bulunamadı';
  return analysis.summary;
}
