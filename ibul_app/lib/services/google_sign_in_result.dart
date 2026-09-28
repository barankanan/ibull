/// Google oturum alanları. `google_sign_in` paketinden ayrı tutulur; böylece
/// auth servisi sonucu adlandırabilir, paketin kendisi ise deferred kalır.
class GoogleSignInResult {
  const GoogleSignInResult({
    required this.email,
    this.idToken,
    this.accessToken,
  });

  final String email;
  final String? idToken;
  final String? accessToken;
}
