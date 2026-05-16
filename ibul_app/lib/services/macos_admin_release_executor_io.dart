import 'dart:io';

import 'macos_admin_release_models.dart';

Future<AdminCupsReleaseResult> runAdminCupsReleaseCommand() async {
  if (!Platform.isMacOS) {
    return const AdminCupsReleaseResult(
      ok: false,
      message: 'Bu platformda yönetici izniyle CUPS yeniden başlatılamıyor.',
      error: 'platform_unsupported',
    );
  }

  const activateScript = 'tell application "System Events" to activate';
  const releaseScript =
      'do shell script "killall -USR1 cupsd" with administrator privileges';

  try {
    final result = await Process.run('osascript', <String>[
      '-e',
      activateScript,
      '-e',
      releaseScript,
    ]);
    final stdout = result.stdout.toString().trim();
    final stderr = result.stderr.toString().trim();
    if (result.exitCode != 0) {
      final userCancelled = _isUserCancelled(stderr, stdout);
      return AdminCupsReleaseResult(
        ok: false,
        message: userCancelled
            ? 'Yönetici izni verilmedi.'
            : 'Yönetici izni alınamadı veya CUPS yeniden başlatılamadı.',
        output: stdout.isEmpty ? null : stdout,
        error: userCancelled
            ? 'user_cancelled'
            : (stderr.isEmpty ? 'exit_code_${result.exitCode}' : stderr),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return AdminCupsReleaseResult(
      ok: true,
      message: 'CUPS yeniden başlatıldı.',
      output: stdout.isEmpty ? null : stdout,
      error: stderr.isEmpty ? null : stderr,
    );
  } catch (error) {
    return AdminCupsReleaseResult(
      ok: false,
      message: 'Yönetici izniyle CUPS yeniden başlatılamadı.',
      error: error.toString(),
    );
  }
}

bool _isUserCancelled(String stderr, String stdout) {
  final raw = '$stderr $stdout'.toLowerCase();
  return raw.contains('user canceled') ||
      raw.contains('user cancelled') ||
      raw.contains('kullanici iptal etti') ||
      raw.contains('(-128)');
}
