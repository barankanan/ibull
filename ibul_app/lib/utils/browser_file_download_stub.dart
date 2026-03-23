import 'dart:io';

class BrowserFileDownload {
  static void saveBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    final file = File('${Directory.systemTemp.path}/$fileName');
    file.writeAsBytesSync(bytes, flush: true);
  }

  static void openPrintHtml({
    required String title,
    required String htmlBody,
  }) {}
}
