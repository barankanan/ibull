import 'macos_admin_release_models.dart';

Future<AdminCupsReleaseResult> runAdminCupsReleaseCommand() async {
  return const AdminCupsReleaseResult(
    ok: false,
    message: 'Bu platformda yönetici izniyle CUPS yeniden başlatılamıyor.',
    error: 'platform_unsupported',
  );
}
