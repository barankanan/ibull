import 'dart:io';

class ExternalNavigation {
  static bool openIhizSite() {
    return false;
  }

  static Future<bool> openUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) return false;

    try {
      if (Platform.isMacOS) {
        final result = await Process.run('open', [normalized]);
        return result.exitCode == 0;
      }
      if (Platform.isIOS) {
        final uri = Uri.tryParse(normalized);
        if (uri == null) return false;
        final result = await Process.run('open', [uri.toString()]);
        return result.exitCode == 0;
      }
      if (Platform.isWindows) {
        final result = await Process.run('cmd', ['/c', 'start', '', normalized]);
        return result.exitCode == 0;
      }
      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [normalized]);
        return result.exitCode == 0;
      }
      if (Platform.isAndroid) {
        final result = await Process.run(
          'am',
          ['start', '-a', 'android.intent.action.VIEW', '-d', normalized],
        );
        return result.exitCode == 0;
      }
    } catch (_) {
      return false;
    }

    return false;
  }
}
