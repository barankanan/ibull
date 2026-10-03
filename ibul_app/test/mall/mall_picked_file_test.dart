import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/mall/services/mall_picked_file_io.dart';

void main() {
  test('desktop path fallback reads bytes when the picker omits them', () async {
    final file = File('${Directory.systemTemp.path}/mall_pick_test.bin');
    await file.writeAsBytes(const [9, 8, 7, 6]);
    addTearDown(() => file.delete());
    final bytes = await readMallFilePath(file.path);
    expect(bytes, const [9, 8, 7, 6]);
    expect(await readMallFilePath(null), isNull);
  });
}
