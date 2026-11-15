/// Chooses which SMAppService plist the seller app may register.
///
/// The live agent label is selected only when a separate approval flag is set.
/// An isolated test never falls through to that label.
class PrintAgentPolicy {
  static const livePlistName = 'com.ibul.localprint.plist';
  static const isolatedPlistName = 'com.ibul.localprint.isolated-test.plist';

  static String? plistForEnvironment(Map<String, String> env) {
    if (env['IBUL_ISOLATED_PRINT_TEST'] == '1') {
      return isolatedPlistName;
    }
    if (env['IBUL_ALLOW_LIVE_PRINT_AGENT'] == '1') {
      return livePlistName;
    }
    return null;
  }

  static String userMessage({required String status, int? code}) {
    if (code == 1 || status == 'operation_not_permitted') {
      return 'Yazıcı servisi, uygulamanın korumalı alanı job-creation iznini reddettiği için kaydedilemedi. İzin penceresi açılmadı.';
    }
    switch (status) {
      case 'enabled':
        return 'Yazıcı servisi sisteme kayıtlı.';
      case 'requiresApproval':
      case 'launch_denied':
        return 'Yazıcı servisinin açılışta çalışması için Sistem Ayarları’nda izin vermeniz gerekiyor. İzin verilmeden servis başlatılmaz.';
      case 'invalid_signature':
        return 'Yazıcı servisi kaydı tamamlanamadı. Uygulamanın geçerli bir imzası yok.';
      case 'live_label_blocked':
        return 'Canlı yazıcı servisi kaydı bu kurulumda kapalı.';
      case 'unsupported':
        return 'Yazıcı servisi kaydı macOS 13 ve sonrasında kullanılabilir.';
      case 'notRegistered':
        return 'Yazıcı servisi henüz sisteme kayıtlı değil.';
      case 'notFound':
      case 'invalid_plist':
        return 'Yazıcı servisi kaydı uygulama paketinde bulunamadı.';
      default:
        if (code == 3) {
          return 'Yazıcı servisi kaydı tamamlanamadı. Uygulamanın geçerli bir imzası yok.';
        }
        return 'Yazıcı servisi kaydı tamamlanamadı.';
    }
  }
}
