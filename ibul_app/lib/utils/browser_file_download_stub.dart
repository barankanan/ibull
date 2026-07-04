import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'native_file_save.dart';

class BrowserFileDownload {
  /// Dosyayı kaydeder. Başarılıysa kayıt yolu, iptal edildiyse `null` döner.
  /// macOS sandbox: save dialog yolunu döndürür, içerik Dart tarafında yazılır
  /// (`file_picker` macOS'ta `bytes` parametresini desteklemez).
  static Future<String?> saveBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final Uint8List payload = Uint8List.fromList(bytes);

    final String? pickedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'CSV şablonunu kaydet',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
      lockParentWindow: !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.windows,
    );

    return writeBytesToSelectedPath(
      pickedPath: pickedPath,
      bytes: payload,
      fileName: fileName,
    );
  }

  static void openPrintHtml({
    required String title,
    required String htmlBody,
  }) {}

  static void openExternalUrl(String url) {
    final String normalized = url.trim();
    if (normalized.isEmpty) return;
    final Uri? uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) return;
    try {
      if (Platform.isMacOS) {
        Process.run('open', <String>[normalized]);
        return;
      }
      if (Platform.isWindows) {
        Process.run('cmd', <String>['/c', 'start', '', normalized]);
        return;
      }
      if (Platform.isLinux) {
        Process.run('xdg-open', <String>[normalized]);
      }
    } catch (_) {}
  }
}
