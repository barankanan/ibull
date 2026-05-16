import 'package:flutter/material.dart';

import '../app/app_navigator.dart';
import 'macos_admin_release_executor_stub.dart'
    if (dart.library.io) 'macos_admin_release_executor_io.dart'
    as admin_release;
import 'macos_admin_release_models.dart';

class MacosUsbPermissionRecoveryService {
  Future<bool> requestAdminUsbRelease({
    required bool hasConflictWarning,
  }) async {
    final context =
        appNavigatorKey.currentContext ??
        appNavigatorKey.currentState?.overlay?.context;
    if (context == null) {
      return false;
    }

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('macOS yazıcıyı kilitledi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'macOS yazıcıyı kilitledi. Kilidi kaldırmak için izin gerekiyor.',
              ),
              if (hasConflictWarning) ...[
                const SizedBox(height: 12),
                const Text(
                  'Bu yazıcı hem CUPS hem USB Direct olarak görünüyor. '
                  'Termal yazıcı için USB Direct kullanılacaksa CUPS kaydı kaldırılmalı.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('USB Kilidini Aç'),
            ),
          ],
        );
      },
    );

    return approved == true;
  }

  Future<AdminCupsReleaseResult> runAdminUsbRelease() {
    return admin_release.runAdminCupsReleaseCommand();
  }

  Future<bool> requestRetryAfterAdminCancelled({
    required bool hasConflictWarning,
  }) async {
    final context =
        appNavigatorKey.currentContext ??
        appNavigatorKey.currentState?.overlay?.context;
    if (context == null) {
      return false;
    }

    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('İzin verilmedi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'İzin verilmedi. USB kilidini açmak için Mac şifrenizi girmeniz gerekiyor.',
              ),
              const SizedBox(height: 12),
              const SelectableText('sudo killall -USR1 cupsd'),
              if (hasConflictWarning) ...[
                const SizedBox(height: 12),
                const Text(
                  'Bu yazıcı hem CUPS hem USB Direct olarak görünüyor. '
                  'Termal yazıcı için USB Direct kullanılacaksa CUPS kaydı kaldırılmalı.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Tekrar Dene'),
            ),
          ],
        );
      },
    );

    return retry == true;
  }

  Future<void> showPostReleaseFailureInstructions({
    required bool hasConflictWarning,
  }) async {
    final context =
        appNavigatorKey.currentContext ??
        appNavigatorKey.currentState?.overlay?.context;
    if (context == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('USB Direct hâlâ kilitli'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sistem Ayarları > Yazıcılar’dan POS58/STMicroelectronics '
                'yazıcısını kaldırın. Bu yazıcı CUPS’a ekliyse USB direct baskıyı kilitler.',
              ),
              if (hasConflictWarning) ...[
                const SizedBox(height: 12),
                const Text(
                  'Bu yazıcı hem CUPS hem USB Direct olarak görünüyor. '
                  'USB Direct kullanılacaksa CUPS kaydı kaldırılmalı.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }
}
