import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _strictDirs = <String>[
  'lib/features/checkout',
  'lib/features/investor',
  'lib/features/ihiz',
  'lib/screens/coming_soon',
  'lib/screens/legal',
  'lib/features/seller/panel/cargo',
  'lib/features/seller/panel/printer_center',
];

void main() {
  test('root analyzer does not promote empty_catches or avoid_print', () {
    final root = File('analysis_options.yaml').readAsStringSync();
    expect(root, contains('package:flutter_lints/flutter.yaml'));
    expect(root, isNot(contains('empty_catches:')));
    expect(root, isNot(contains('avoid_print: true')));
    expect(root, contains('tool/analysis_options_new_code.yaml'));
  });

  test('new-code analyzer promotes empty_catches and avoid_print to error', () {
    final strict = File('tool/analysis_options_new_code.yaml').readAsStringSync();
    expect(strict, contains('empty_catches: error'));
    expect(strict, contains('avoid_print: error'));

    for (final dir in _strictDirs) {
      final nested = File('$dir/analysis_options.yaml').readAsStringSync();
      expect(
        nested,
        contains('analysis_options_new_code.yaml'),
        reason: '$dir must include the new-code analyzer',
      );
    }
  });

  test('seller panel god file is outside the new-code analyzer', () {
    expect(
      File('lib/screens/seller_panel_page.dart').existsSync(),
      isTrue,
    );
    expect(
      File('lib/screens/analysis_options.yaml').existsSync(),
      isFalse,
    );
  });

  test('ihiz dashboard stays exempt until the god-file split', () {
    final dashboard = File(
      'lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart',
    ).readAsStringSync();
    expect(dashboard, contains('ignore_for_file:'));
    expect(dashboard, contains('empty_catches'));
  });
}
