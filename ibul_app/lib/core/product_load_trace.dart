import 'package:flutter/foundation.dart';

import 'product_load_trace_stub.dart'
    if (dart.library.html) 'product_load_trace_web.dart' as impl;

/// Product load stages for home grid diagnostics (web production).
abstract final class ProductLoadTraceStage {
  static const fetchStarted = 'products_fetch_started';
  static const fetchSuccess = 'products_fetch_success';
  static const fetchEmpty = 'products_fetch_empty';
  static const parseStarted = 'products_parse_started';
  static const parseFailed = 'products_parse_failed';
  static const filterStarted = 'products_filter_started';
  static const filterEmpty = 'products_filter_empty';
  static const renderStarted = 'products_render_started';
  static const renderCompleted = 'products_render_completed';
  static const fetchError = 'products_fetch_error';
}

class ProductLoadTraceSnapshot {
  const ProductLoadTraceSnapshot({
    required this.stage,
    this.table,
    this.query,
    this.rawCount,
    this.filteredCount,
    this.error,
    this.detail,
    this.timestamp,
  });

  final String stage;
  final String? table;
  final String? query;
  final int? rawCount;
  final int? filteredCount;
  final String? error;
  final String? detail;
  final String? timestamp;

  ProductLoadTraceSnapshot copyWith({
    String? stage,
    String? table,
    String? query,
    int? rawCount,
    int? filteredCount,
    String? error,
    String? detail,
    String? timestamp,
  }) {
    return ProductLoadTraceSnapshot(
      stage: stage ?? this.stage,
      table: table ?? this.table,
      query: query ?? this.query,
      rawCount: rawCount ?? this.rawCount,
      filteredCount: filteredCount ?? this.filteredCount,
      error: error ?? this.error,
      detail: detail ?? this.detail,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'stage': stage,
        if (table != null) 'table': table,
        if (query != null) 'query': query,
        if (rawCount != null) 'rawCount': rawCount,
        if (filteredCount != null) 'filteredCount': filteredCount,
        'error': error,
        if (detail != null) 'detail': detail,
        if (timestamp != null) 'timestamp': timestamp,
      };
}

class ProductLoadTraceNotifier extends ChangeNotifier {
  ProductLoadTraceSnapshot _snapshot = const ProductLoadTraceSnapshot(
    stage: ProductLoadTraceStage.fetchStarted,
  );

  ProductLoadTraceSnapshot get snapshot => _snapshot;

  void update({
    required String stage,
    String? table,
    String? query,
    int? rawCount,
    int? filteredCount,
    String? error,
    String? detail,
  }) {
    _snapshot = _snapshot.copyWith(
      stage: stage,
      table: table,
      query: query,
      rawCount: rawCount,
      filteredCount: filteredCount,
      error: error,
      detail: detail,
      timestamp: DateTime.now().toIso8601String(),
    );
    impl.persistProductLoadTrace(_snapshot);
    notifyListeners();
    if (kIsWeb) {
      // ignore: avoid_print
      print(
        '[ProductLoadTrace][$stage] raw=$rawCount filtered=$filteredCount '
        '${error == null ? '' : 'error=$error'}',
      );
    }
  }
}

String? readProductLoadTraceJson() => impl.readProductLoadTraceJson();

void clearProductLoadTrace() => impl.clearProductLoadTrace();
