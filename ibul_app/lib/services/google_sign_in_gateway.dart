import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config/runtime_config.dart';
import 'google_sign_in_result.dart';

class GoogleSignInGateway {
  GoogleSignInGateway._();

  static final GoogleSignInGateway instance = GoogleSignInGateway._();

  GoogleSignIn? _client;

  GoogleSignIn get _google {
    final clientId = AppRuntimeConfig.googleClientId;
    final serverClientId = AppRuntimeConfig.googleServerClientId;
    return _client ??= kIsWeb
        ? GoogleSignIn(clientId: clientId)
        : GoogleSignIn(clientId: clientId, serverClientId: serverClientId);
  }

  Future<GoogleSignInResult?> signIn() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    return GoogleSignInResult(
      email: googleUser.email,
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
  }

  Future<void> signOut() => _client?.signOut() ?? Future<void>.value();
}
