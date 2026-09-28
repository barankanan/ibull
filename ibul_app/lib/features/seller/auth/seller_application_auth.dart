import '../../../services/auth_service.dart';

/// Satıcı başvurusunda formdaki şifrenin Auth hesabına yazılmasını sağlar.
///
/// Google ile açık müşteri oturumu varken "Satıcı Ol" doldurulursa eski kod
/// şifre alanını yok sayıyordu. Galeri başvuruları bu yüzden onaylansa bile
/// satıcı paneline parola ile giremiyordu.
class SellerApplicationAuth {
  const SellerApplicationAuth._();

  static bool isAlreadyRegistered(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('already registered') ||
        text.contains('already been registered') ||
        text.contains('user_already_exists') ||
        text.contains('email_exists')) {
      return true;
    }
    return false;
  }

  static Future<void> ensureAccount({
    required AuthService auth,
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    if (password.trim().length < 6) {
      throw Exception('Şifre alanı zorunludur');
    }

    final target = email.trim().toLowerCase();
    final currentEmail = auth.currentUser?.email?.trim().toLowerCase();

    if (auth.currentUser != null && currentEmail == target) {
      final profile = await auth.getUserProfile();
      final role = (profile?['role'] ?? auth.currentUser?.userMetadata?['role'])
          ?.toString();
      if (AuthService.isAdminRole(role)) {
        throw Exception(
          'Admin hesabıyla satıcı başvurusu yapılamaz. Satıcı için ayrı bir e-posta kullanın.',
        );
      }
      await auth.updateUserPassword(password);
      return;
    }

    if (auth.currentUser != null && currentEmail != target) {
      await auth.signOut(logoutType: 'seller_application_switch');
    }

    try {
      await auth.signUpWithEmailPassword(
        email.trim(),
        password,
        displayName,
        phone: phone,
      );
    } catch (error) {
      if (!isAlreadyRegistered(error)) rethrow;
      try {
        await auth.signInWithEmailPassword(
          email.trim(),
          password,
          authArea: 'seller',
        );
      } catch (_) {
        throw Exception(
          'Bu e-posta zaten kayıtlı. Google ile açıldıysa satıcı paneline '
          'yazılan şifreyle giriş çalışmaz. Şifremi unuttum ile şifre belirleyin.',
        );
      }
    }

    if (auth.currentUser == null) {
      throw Exception('Kullanıcı oluşturuldu fakat giriş yapılamadı.');
    }
  }
}
