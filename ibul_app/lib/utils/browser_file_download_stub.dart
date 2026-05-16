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

  static void openExternalUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) return;
    try {
      if (Platform.isMacOS) {
        Process.run('open', [normalized]);
        return;
      }
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', '', normalized]);
        return;
      }
      if (Platform.isLinux) {
        Process.run('xdg-open', [normalized]);
      }
    } catch (_) {}
  }
}
