// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class BrowserFileDownload {
  static void saveBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    final base64Data = base64Encode(bytes);
    final url = 'data:$mimeType;base64,$base64Data';
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  static void openPrintHtml({required String title, required String htmlBody}) {
    final safeTitle = const HtmlEscape().convert(title);
    final htmlContent =
        '''
      <!doctype html>
      <html lang="tr">
        <head>
          <meta charset="utf-8">
          <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>$safeTitle</title>
          <style>
            body { font-family: Arial, sans-serif; background: #f6f3ff; padding: 24px; }
            .sheet { width: 900px; margin: 0 auto; background: white; border-radius: 24px; border: 1px solid #e7e0fa; padding: 28px; }
            .muted { color: #6f6888; }
            .chip { display:inline-block; margin-right: 8px; margin-bottom: 8px; padding: 8px 12px; border-radius: 999px; background:#f3edff; color:#6b2cff; font-weight:700; }
            .section { margin-top: 20px; padding: 16px; border-radius: 18px; background:#faf8ff; border:1px solid #ece5ff; }
            .grid { display:grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
            .row { margin-bottom: 8px; }
            .label { font-size: 12px; color: #8b84a2; }
            .value { font-size: 16px; color: #241c3c; font-weight:700; }
            @media print {
              body { background: white; padding: 0; }
              .sheet { width: auto; margin: 0; border: none; box-shadow: none; }
            }
          </style>
        </head>
        <body>
          <div class="sheet">$htmlBody</div>
          <script>
            setTimeout(() => window.print(), 250);
          </script>
        </body>
      </html>
    ''';
    final bytes = Uint8List.fromList(utf8.encode(htmlContent));
    final blob = html.Blob([bytes], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Future<void>.delayed(
      const Duration(seconds: 15),
      () => html.Url.revokeObjectUrl(url),
    );
  }

  static void openExternalUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    html.window.open(normalized, '_blank');
  }
}
