import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/native_file_save.dart';

void main() {
  group('writeBytesToSelectedPath', () {
    test('null path exception fırlatmaz', () async {
      final String? result = await writeBytesToSelectedPath(
        pickedPath: null,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'ibul_toplu_urun_sablonu.csv',
      );
      expect(result, isNull);
    });

    test('boş path exception fırlatmaz', () async {
      final String? result = await writeBytesToSelectedPath(
        pickedPath: '   ',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'ibul_toplu_urun_sablonu.csv',
      );
      expect(result, isNull);
    });

    test('başarıda path döndürür ve yazıcıyı çağırır', () async {
      String? writtenPath;
      Uint8List? writtenBytes;

      final String? result = await writeBytesToSelectedPath(
        pickedPath: '/tmp/test-export',
        bytes: Uint8List.fromList(<int>[9, 8, 7]),
        fileName: 'ibul_toplu_urun_sablonu.csv',
        writeFile: (String path, Uint8List data) async {
          writtenPath = path;
          writtenBytes = data;
        },
      );

      expect(result, '/tmp/test-export.csv');
      expect(writtenPath, '/tmp/test-export.csv');
      expect(writtenBytes, Uint8List.fromList(<int>[9, 8, 7]));
    });
  });

  group('normalizeCsvSavePath', () {
    test('csv uzantısı yoksa ekler', () {
      expect(
        normalizeCsvSavePath('/Users/test/Desktop/export', 'ibul.csv'),
        '/Users/test/Desktop/export.csv',
      );
    });

    test('csv uzantısı varsa korur', () {
      expect(
        normalizeCsvSavePath('/Users/test/Desktop/export.csv', 'ibul.csv'),
        '/Users/test/Desktop/export.csv',
      );
    });
  });

  group('browser_file_download_stub', () {
    test('Downloads fallback kullanılmıyor', () async {
      final String stubSource = await File(
        'lib/utils/browser_file_download_stub.dart',
      ).readAsString();
      expect(stubSource, isNot(contains('getDownloadsDirectory')));
      expect(stubSource, isNot(contains('path_provider')));
      expect(stubSource, isNot(contains('getTemporaryDirectory')));
    });

    test('saveFile çağrısında bytes parametresi yok', () async {
      final String stubSource = await File(
        'lib/utils/browser_file_download_stub.dart',
      ).readAsString();
      final RegExp saveFileCall = RegExp(
        r'FilePicker\.platform\.saveFile\([\s\S]*?\);',
      );
      final Match? match = saveFileCall.firstMatch(stubSource);
      expect(match, isNotNull);
      expect(match!.group(0), isNot(contains('bytes:')));
    });
  });
}
