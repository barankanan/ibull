import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Release-safe diagnostic logging for product/map runtime issues.
class RuntimeDiagnosticLogger {
  RuntimeDiagnosticLogger._();

  static void products(String message) {
    _emit('Products', message);
  }

  static void map(String message) {
    _emit('Map', message);
  }

  static void mapFallback(String message) {
    _emit('MapFallback', message);
  }

  static void mapProximity(String message) {
    _emit('MapProximity', message);
  }

  static void startup(String message) {
    _emit('Startup', message);
  }

  static void home(String message) {
    _emit('Home', message);
  }

  static void auth(String message) {
    _emit('Auth', message);
  }

  static void fcm(String message) {
    _emit('FCM', message);
  }

  static void localPrint(String message) {
    _emit('LocalPrint', message);
  }

  static void forYou(String message) {
    _emit('ForYou', message);
  }

  static void productDetailAds(String message) {
    _emit('ProductDetailAds', message);
  }

  static void supabase(String message) {
    _emit('Supabase', message);
  }

  static void images(String message) {
    _emit('Images', message);
  }

  static void logFailure(
    String channel,
    Object error,
    StackTrace? stackTrace, {
    String? context,
  }) {
    final prefix = context == null || context.isEmpty ? '' : ' context=$context';
    _emit(channel, 'failed: ${_describeError(error)}$prefix');
    if (error is PostgrestException) {
      _emit(
        channel,
        'PostgrestException code=${error.code ?? '-'} '
        'message=${error.message} details=${error.details} hint=${error.hint}',
      );
    }
    if (stackTrace != null && (kDebugMode || kProfileMode)) {
      debugPrintStack(stackTrace: stackTrace, label: '[$channel]');
    }
  }

  static String _describeError(Object error) {
    if (error is PostgrestException) {
      return 'PostgrestException(${error.code ?? 'unknown'}): ${error.message}';
    }
    if (error is TimeoutException) {
      return 'TimeoutException: ${error.message ?? 'timeout'}';
    }
    if (isNetworkError(error)) {
      return 'NetworkError: $error';
    }
    return '${error.runtimeType}: $error';
  }

  static void _emit(String channel, String message) {
    final line = '[$channel] $message';
    // ignore: avoid_print
    print(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }
}

bool isNetworkError(Object error) {
  if (error is TimeoutException) return true;
  return _looksLikeNetworkError(error);
}

String resolveProductLoadUserMessage(
  Object error, {
  required bool isOnline,
}) {
  if (error is TimeoutException) {
    return 'Ürünler şu an yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.';
  }
  if (!isOnline || isNetworkError(error)) {
    return 'İnternet bağlantınızı kontrol edin.';
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == '42501' || error.message.toLowerCase().contains('policy')) {
      return 'Ürünler yüklenemedi: erişim izni (RLS) reddedildi.';
    }
    return 'Ürünler yüklenemedi: sunucu sorgu hatası.';
  }
  if (error is StateError &&
      error.message.contains('IBUL_SUPABASE')) {
    return 'Supabase config eksik: IBUL_SUPABASE_URL / IBUL_SUPABASE_ANON_KEY';
  }
  return 'Ürünler yüklenemedi. Tekrar deneyin.';
}

bool _looksLikeNetworkError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('network') ||
      text.contains('connection') ||
      text.contains('socket') ||
      text.contains('host lookup') ||
      text.contains('failed host lookup');
}

/// Debug detail shown in web panel / expanded error banner.
String formatProductLoadDebugDetail({
  required String table,
  required String query,
  Object? error,
  StackTrace? stackTrace,
  int? rawCount,
  int? filteredCount,
  int? afterActiveCount,
  int? afterApprovalCount,
  String? selectFields,
}) {
  final lines = <String>[
    'table: $table',
    'query: $query',
    if (selectFields != null && selectFields.isNotEmpty)
      'select: ${selectFields.length > 120 ? '${selectFields.substring(0, 120)}...' : selectFields}',
    if (rawCount != null) 'rawCount: $rawCount',
    if (afterActiveCount != null) 'afterActive: $afterActiveCount',
    if (afterApprovalCount != null) 'afterApproval: $afterApprovalCount',
    if (filteredCount != null) 'filteredCount: $filteredCount',
  ];
  if (error != null) {
    lines.add('errorType: ${error.runtimeType}');
    lines.add('error: ${describeProductLoadError(error)}');
    if (error is PostgrestException) {
      lines.add('postgrestCode: ${error.code ?? '-'}');
    }
  }
  if (stackTrace != null) {
    final stackLines = stackTrace.toString().split('\n').take(5);
    lines.add('stack:');
    lines.addAll(stackLines);
  }
  return lines.join('\n');
}

String describeProductLoadError(Object error) {
  if (error is PostgrestException) {
    return 'PostgrestException(${error.code ?? 'unknown'}): ${error.message}';
  }
  if (error is TimeoutException) {
    return 'TimeoutException: ${error.message ?? 'timeout'}';
  }
  return '${error.runtimeType}: $error';
}

String productFilterEmptyUserMessage({
  required int rawCount,
  required int afterActiveCount,
  required int afterApprovalCount,
}) {
  if (rawCount == 0) {
    return 'Henüz ürün bulunmuyor.';
  }
  if (afterActiveCount == 0) {
    return 'Ürünler var ($rawCount) ancak hiçbiri aktif durumda değil.';
  }
  if (afterApprovalCount == 0) {
    return 'Ürünler var ($rawCount aktif) ancak onay bekliyor — vitrinde gösterilmiyor.';
  }
  return 'Ürünler filtrelendi; vitrinde gösterilecek ürün kalmadı.';
}

String productEmptyStateMessage({
  String? loadNotice,
  bool isError = false,
}) {
  if (loadNotice != null && loadNotice.isNotEmpty && isError) {
    return loadNotice;
  }
  if (loadNotice != null && loadNotice.isNotEmpty && !isError) {
    return loadNotice;
  }
  return 'Henüz ürün bulunmuyor.';
}
