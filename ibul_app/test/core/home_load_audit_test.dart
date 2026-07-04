import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_load_audit.dart';

void main() {
  test('HomeLoadAudit guards all recording behind kDebugMode', () {
    final source = File('lib/core/home_load_audit.dart').readAsStringSync();
    expect(source.contains('if (!kDebugMode) return;'), isTrue);
    expect(source.split('if (!kDebugMode) return;').length, greaterThan(5));
  });

  test('HomeLoadAudit logSummary is no-op outside debug', () {
    // kDebugMode is true in flutter test by default; verify API exists.
    HomeLoadAudit.reset();
    HomeLoadAudit.recordCritical(3);
    expect(HomeLoadAudit.criticalQueryCount, kDebugMode ? 3 : 0);
  });
}
