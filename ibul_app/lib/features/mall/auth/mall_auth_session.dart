import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/runtime_config.dart';
import '../../../core/secure_local_store.dart';

/// Where the AVM session JSON lives. Separate from the marketplace session that
/// supabase_flutter keeps under its own `sb-<ref>-auth-token` key.
abstract class MallSessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureMallSessionStorage implements MallSessionStorage {
  const SecureMallSessionStorage();

  static const key = 'ibul_mall_auth_session_v1';

  @override
  Future<String?> read() => SecureLocalStore.instance.readString(key);

  @override
  Future<void> write(String value) => SecureLocalStore.instance.writeString(key, value);

  @override
  Future<void> delete() => SecureLocalStore.instance.delete(key);
}

/// AVM management identity. Owns its own [SupabaseClient] (own JWT, own
/// refresh token, own storage), so signing in/out here never changes the
/// marketplace customer session of `Supabase.instance.client` and vice versa.
/// RLS still sees `auth.uid()` = the AVM user for every request made with
/// [client].
class MallAuthSession extends ChangeNotifier {
  MallAuthSession({SupabaseClient Function()? clientFactory, MallSessionStorage? storage})
      : _clientFactory = clientFactory ?? _defaultClient,
        _storage = storage ?? const SecureMallSessionStorage();

  static MallAuthSession? _instance;

  static MallAuthSession get instance => _instance ??= MallAuthSession();

  @visibleForTesting
  static set instance(MallAuthSession value) => _instance = value;

  final SupabaseClient Function() _clientFactory;
  final MallSessionStorage _storage;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;
  Future<User?>? _restoring;

  static SupabaseClient _defaultClient() => SupabaseClient(
        AppRuntimeConfig.supabaseUrl,
        AppRuntimeConfig.supabaseAnonKey,
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      );

  SupabaseClient get client {
    final existing = _client;
    if (existing != null) return existing;
    final created = _clientFactory();
    _client = created;
    _subscription = created.auth.onAuthStateChange.listen(_onAuthChange, onError: (Object error) {
      debugPrint('[MALL][AUTH] auth stream error: $error');
    });
    return created;
  }

  User? get currentUser => _client?.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  /// Loads the stored AVM session once. Call before reading [currentUser].
  Future<User?> restore() => _restoring ??= _restore();

  Future<User?> _restore() async {
    final auth = client.auth;
    String? raw;
    try {
      raw = await _storage.read();
    } catch (error) {
      debugPrint('[MALL][AUTH] storage read failed: $error');
    }
    if (raw != null && raw.isNotEmpty && auth.currentUser == null) {
      try {
        await auth.recoverSession(raw);
      } catch (error) {
        debugPrint('[MALL][AUTH] restore failed: $error');
        await _storage.delete();
      }
    }
    debugPrint('[MALL][AUTH] restored uid=${auth.currentUser?.id} email=${auth.currentUser?.email}');
    notifyListeners();
    return auth.currentUser;
  }

  Future<User?> signIn({required String email, required String password}) async {
    await restore();
    final response = await client.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
    await _persist(response.session);
    debugPrint('[MALL][AUTH] signed in uid=${response.user?.id} email=${response.user?.email}');
    notifyListeners();
    return response.user;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    await restore();
    final response = await client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'display_name': displayName, 'phone': phone},
    );
    await _persist(response.session);
    notifyListeners();
    return response;
  }

  /// Ends only the AVM session (local scope: this refresh token only).
  Future<void> signOut() async {
    final uid = currentUser?.id;
    try {
      if (_client?.auth.currentSession != null) {
        await _client!.auth.signOut(scope: SignOutScope.local);
      }
    } catch (error) {
      debugPrint('[MALL][AUTH] remote sign out failed: $error');
    }
    await _storage.delete();
    debugPrint('[MALL][AUTH] signed out uid=$uid');
    notifyListeners();
  }

  /// `users` row for the AVM account, written with the AVM JWT.
  Future<void> ensureUserRow({String? displayName, String? phone}) async {
    final user = currentUser;
    if (user == null) return;
    final db = client;
    final existing = await db.from('users').select('id').eq('id', user.id).maybeSingle();
    final row = <String, dynamic>{
      'id': user.id,
      'email': user.email,
      'display_name': displayName ?? user.userMetadata?['display_name'] ?? user.userMetadata?['name'],
      'updated_at': DateTime.now().toIso8601String(),
      'phone': ?phone,
      if (existing == null) 'role': 'user',
    };
    await db.from('users').upsert(row, onConflict: 'id');
  }

  Future<void> _persist(Session? session) async {
    if (session == null) return;
    await _storage.write(jsonEncode(session.toJson()));
  }

  void _onAuthChange(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.initialSession:
        return;
      case AuthChangeEvent.signedOut:
        unawaited(_storage.delete());
      default:
        unawaited(_persist(state.session));
    }
    notifyListeners();
  }

  static String describeError(Object error) {
    if (error is AuthApiException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'E-posta veya şifre hatalı.';
        case 'email_not_confirmed':
          return 'E-posta adresiniz henüz doğrulanmamış.';
        case 'too_many_requests':
          return 'Çok fazla deneme yapıldı. Lütfen kısa süre sonra tekrar deneyin.';
      }
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('invalid_credentials') || raw.contains('invalid login')) {
      return 'E-posta veya şifre hatalı.';
    }
    return 'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edin.';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    final client = _client;
    if (client != null) unawaited(client.dispose());
    super.dispose();
  }
}
