import '../core/product_filter_audit.dart';
import '../models/db_product.dart';

enum HomeProductsFetchOutcome {
  success,
  empty,
  filterEmpty,
  queryError,
  configMissing,
  parseError,
}

/// Structured result from the home products Supabase fetch.
class HomeProductsFetchReport {
  const HomeProductsFetchReport({
    required this.outcome,
    required this.products,
    required this.table,
    required this.querySummary,
    required this.selectFields,
    this.filterAudit,
    this.parseSuccessCount = 0,
    this.parseFailCount = 0,
    this.lastParseError,
    this.error,
    this.stackTrace,
  });

  final HomeProductsFetchOutcome outcome;
  final List<DBProduct> products;
  final String table;
  final String querySummary;
  final String selectFields;
  final ProductFilterAudit? filterAudit;
  final int parseSuccessCount;
  final int parseFailCount;
  final String? lastParseError;
  final Object? error;
  final StackTrace? stackTrace;

  int get rawCount => filterAudit?.rawCount ?? 0;
  int get filteredCount => filterAudit?.afterVisibilityFilterCount ?? 0;

  bool get hasProducts => products.isNotEmpty;

  factory HomeProductsFetchReport.configMissing() {
    return const HomeProductsFetchReport(
      outcome: HomeProductsFetchOutcome.configMissing,
      products: [],
      table: 'products',
      querySummary: '(skipped — Supabase config missing)',
      selectFields: '',
    );
  }

  Map<String, dynamic> toTraceJson({String? stage, String? error}) {
    return {
      if (stage != null) 'stage': stage,
      'table': table,
      'query': querySummary,
      'selectFields': selectFields,
      'rawCount': rawCount,
      'filteredCount': filteredCount,
      if (filterAudit != null) 'filterAudit': filterAudit!.toJson(),
      'parseSuccessCount': parseSuccessCount,
      'parseFailCount': parseFailCount,
      if (lastParseError != null) 'lastParseError': lastParseError,
      'outcome': outcome.name,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
