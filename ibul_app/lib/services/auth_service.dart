import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        defaultTargetPlatform,
        debugPrint,
        debugPrintStack,
        kIsWeb;
import '../core/auth/auth_debug_logger.dart';
import '../core/auth/ibul_auth_context.dart';
import '../core/runtime_diagnostic_logger.dart';
import '../core/secure_local_store.dart';
import '../features/seller/domain/store_vertical.dart';
import 'google_sign_in_gateway.dart' deferred as google_sign_in_gateway;
import 'google_sign_in_result.dart';
import 'store_service.dart' deferred as store_service_lib;

enum LoginResolvedRole { seller, waiter, admin, user, unknown }

class LoginRouteResolution {
  const LoginRouteResolution({
    required this.userId,
    required this.userEmail,
    required this.profile,
    required this.rawRole,
    required this.resolvedRole,
    required this.isSellerApproved,
    required this.storeProfile,
  });

  final String? userId;
  final String? userEmail;
  final Map<String, dynamic>? profile;
  final String? rawRole;
  final LoginResolvedRole resolvedRole;
  final bool isSellerApproved;
  final Map<String, dynamic>? storeProfile;

  bool get profileFound => profile != null;
  bool get storeProfileFound => storeProfile != null;

  String get chosenRoute {
    if (resolvedRole == LoginResolvedRole.waiter) {
      return '/seller[garson]';
    }
    return SellerDashboardResolver.routeFor(
      resolvedRoleName: resolvedRole.name,
      vertical: resolveStoreVertical(
        storeProfile?['category']?.toString(),
      ),
    );
  }
}

class AuthService {
  SupabaseClient get _supabase => Supabase.instance.client;
  static const String _sellerSwitchSessionBackupKey =
      'auth.user_session_before_seller_switch';
  static const List<String> adminRoles = [
    'admin',
    'super_admin',
    'admin_marketing',
    'admin_support',
    'admin_store_ops',
    'admin_investor',
    'admin_finance',
    'admin_security',
  ];
  bool _googleAuthLoaded = false;

  AuthService();

  static bool isAdminRole(String? role) {
    if (role == null) return false;
    return role == 'admin' ||
        role == 'super_admin' ||
        role.startsWith('admin_');
  }

  static LoginResolvedRole normalizeLoginRole(String? rawRole) {
    final normalized = rawRole?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return LoginResolvedRole.unknown;
    }
    if (isAdminRole(normalized)) {
      return LoginResolvedRole.admin;
    }
    switch (normalized) {
      case 'seller':
        return LoginResolvedRole.seller;
      case 'waiter':
      case 'garson':
        return LoginResolvedRole.waiter;
      case 'user':
      case 'customer':
      case 'buyer':
        return LoginResolvedRole.user;
      default:
        return LoginResolvedRole.unknown;
    }
  }

  static String adminRoleLabel(String? role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Genel Operasyon';
      case 'admin_marketing':
        return 'Reklam Ekibi';
      case 'admin_support':
        return 'Destek Ekibi';
      case 'admin_store_ops':
        return 'Magaza Yonetimi';
      case 'admin_investor':
        return 'Yatirimci Iliskileri';
      case 'admin_finance':
        return 'Muhasebe';
      case 'admin_security':
        return 'Siber Guvenlik';
      default:
        final source = role?.trim();
        if (source == null || source.isEmpty) {
          return 'Tanimsiz Rol';
        }
        return source
            .replaceAll('_', ' ')
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  Future<void> _signOutGoogleIfLoaded() async {
    if (!_googleAuthLoaded) return;
    await google_sign_in_gateway.loadLibrary();
    await google_sign_in_gateway.GoogleSignInGateway.instance.signOut();
  }

  String _mapFieldNameToDb(String fieldName) {
    switch (fieldName) {
      case 'isSellerApproved':
        return 'is_seller_approved';
      case 'savedCards':
        return 'savedCards';
      case 'productLists':
        return 'product_lists';
      default:
        return fieldName;
    }
  }

  // Stream of auth changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Sign in with Google
  Future<AuthResponse> signInWithGoogle({String authArea = 'user'}) async {
    GoogleSignInResult? googleUser;
    try {
      _googleAuthLoaded = true;
      await google_sign_in_gateway.loadLibrary();
      googleUser =
          await google_sign_in_gateway.GoogleSignInGateway.instance.signIn();
      if (googleUser == null) {
        await _recordAuthLoginAttempt(
          provider: 'google',
          status: 'cancelled',
          authArea: authArea,
          errorCode: 'cancelled_by_user',
          errorMessage: 'Google sign in canceled',
        );
        throw Exception('Google sign in canceled');
      }

      final idToken = googleUser.idToken;
      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleUser.accessToken,
      );
      await _recordAuthLoginAttempt(
        email: googleUser.email,
        provider: 'google',
        status: 'success',
        authArea: authArea,
        userId: response.user?.id,
        metadata: {'session_present': response.session != null},
      );
      await ensureCurrentUserRow(user: response.user);
      return response;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (!(googleUser == null &&
          e.toString().contains('Google sign in canceled'))) {
        await _recordAuthLoginAttempt(
          email: googleUser?.email,
          provider: 'google',
          status: googleUser == null ? 'cancelled' : 'failed',
          authArea: authArea,
          errorCode:
              _authErrorCode(e) ?? (googleUser == null ? 'cancelled' : null),
          errorMessage: _normalizedAuthErrorMessage(e),
        );
      }
      rethrow;
    }
  }

  // Sign in with Email/Password
  Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password, {
    String authArea = 'user',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      await _recordAuthLoginAttempt(
        email: normalizedEmail,
        provider: 'password',
        status: 'success',
        authArea: authArea,
        userId: response.user?.id,
        metadata: {'session_present': response.session != null},
      );
      await ensureCurrentUserRow(user: response.user);
      return response;
    } catch (e) {
      debugPrint('Email Sign-In Error: $e');
      await _recordAuthLoginAttempt(
        email: normalizedEmail,
        provider: 'password',
        status: 'failed',
        authArea: authArea,
        errorCode: _authErrorCode(e),
        errorMessage: _normalizedAuthErrorMessage(e),
      );
      rethrow;
    }
  }

  // Register with Email/Password
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password,
    String displayName, {
    String? phone,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'display_name': displayName, 'phone': phone},
      );

      // Save to 'users' table
      await _saveUserToSupabase(
        response.user,
        phone: phone,
        displayName: displayName,
      );

      return response;
    } catch (e) {
      debugPrint('Sign-Up Error: $e');
      rethrow;
    }
  }

  String describeSignInError(
    Object error, {
    bool adminMode = false,
    String authArea = 'user',
  }) {
    if (authArea == 'user' && !adminMode) {
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
    if (error is AuthApiException) {
      switch (error.code) {
        case 'invalid_credentials':
          return adminMode
              ? 'E-posta veya şifre Supabase Auth tarafında doğrulanamadı. Bu hesap Google ile açıldıysa parola ile admin girişi çalışmaz.'
              : 'E-posta veya şifre doğrulanamadı. Bu hesap Google ile açıldıysa satıcı paneline o parolayla girilemez. Şifremi unuttum ile e-posta, SMS veya mağaza kodu kullanın.';
        case 'email_not_confirmed':
          return 'E-posta adresiniz henüz doğrulanmamış.';
        case 'too_many_requests':
          return 'Çok fazla deneme yapıldı. Lütfen kısa süre sonra tekrar deneyin.';
      }
    }
    return error.toString().replaceAll('Exception:', '').trim();
  }

  String? _authErrorCode(Object error) {
    if (error is AuthApiException) {
      return error.code;
    }
    return null;
  }

  String _normalizedAuthErrorMessage(Object error) {
    return error.toString().replaceAll('Exception:', '').trim();
  }

  String get _authPlatformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String get _authDeviceLabel {
    if (kIsWeb) return 'browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android_app';
      case TargetPlatform.iOS:
        return 'ios_app';
      case TargetPlatform.macOS:
        return 'macos_app';
      case TargetPlatform.windows:
        return 'windows_app';
      case TargetPlatform.linux:
        return 'linux_app';
      case TargetPlatform.fuchsia:
        return 'fuchsia_app';
    }
  }

  Future<LoginRouteResolution> resolveLoginRoute({
    String diagnosticContext = 'login',
    bool includeStoreProfile = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      const resolution = LoginRouteResolution(
        userId: null,
        userEmail: null,
        profile: null,
        rawRole: null,
        resolvedRole: LoginResolvedRole.unknown,
        isSellerApproved: false,
        storeProfile: null,
      );
      _logLoginRouteResolution(
        diagnosticContext: diagnosticContext,
        resolution: resolution,
      );
      return resolution;
    }

    Map<String, dynamic>? profile;
    Map<String, dynamic>? storeProfile;
    try {
      profile = await getUserProfile();
    } catch (error, stackTrace) {
      debugPrint(
        '[AuthRoute][$diagnosticContext] profile fetch failed for ${user.id}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    var rawRole = await _resolveRawRole(
      user: user,
      profile: profile,
    );
    var resolvedRole = normalizeLoginRole(rawRole);
    var isSellerApproved = _coerceBool(
      profile?['is_seller_approved'] ??
          profile?['isSellerApproved'] ??
          user.userMetadata?['is_seller_approved'] ??
          user.userMetadata?['isSellerApproved'],
    );

    final shouldLoadStore =
        includeStoreProfile &&
        (resolvedRole == LoginResolvedRole.seller ||
            resolvedRole == LoginResolvedRole.waiter ||
            diagnosticContext == 'seller_login');
    if (shouldLoadStore) {
      try {
        await store_service_lib.loadLibrary();
        storeProfile = await store_service_lib.StoreService().getStoreProfile();
      } catch (error, stackTrace) {
        debugPrint(
          '[AuthRoute][$diagnosticContext] store fetch failed for ${user.id}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (diagnosticContext == 'seller_login' &&
        resolvedRole != LoginResolvedRole.admin &&
        resolvedRole != LoginResolvedRole.waiter &&
        SellerLoginAccess.ownedStoreMarksUserAsSeller(storeProfile)) {
      rawRole = 'seller';
      resolvedRole = LoginResolvedRole.seller;
      if (SellerLoginAccess.ownedStoreIsApproved(storeProfile)) {
        isSellerApproved = true;
        unawaited(_repairApprovedSellerRole(userId: user.id));
      }
    }

    final resolution = LoginRouteResolution(
      userId: user.id,
      userEmail: user.email,
      profile: profile,
      rawRole: rawRole,
      resolvedRole: resolvedRole,
      isSellerApproved: isSellerApproved,
      storeProfile: storeProfile,
    );
    _logLoginRouteResolution(
      diagnosticContext: diagnosticContext,
      resolution: resolution,
    );
    return resolution;
  }

  Future<String?> _resolveRawRole({
    required User user,
    required Map<String, dynamic>? profile,
  }) async {
    final fromProfile = profile?['role']?.toString().trim();
    if (isAdminRole(fromProfile)) return fromProfile;

    final restored = await _restoreAdminRoleFromPermissions(user.id);
    if (restored != null) return restored;

    // user_metadata.role is client-controlled (signup `data`). Never copy it
    // into public.users and never treat it as an admin grant.
    final fromMetadata = user.userMetadata?['role']?.toString().trim();
    if (isAdminRole(fromMetadata)) {
      return fromProfile?.isNotEmpty == true ? fromProfile : 'user';
    }
    return (fromProfile?.isNotEmpty == true ? fromProfile : fromMetadata);
  }

  Future<void> _repairApprovedSellerRole({required String userId}) async {
    try {
      await _supabase.from('users').update({
        'role': 'seller',
        'is_seller_approved': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (error) {
      debugPrint('[AuthRoute] seller role repair skipped: $error');
    }
  }

  Future<String?> _restoreAdminRoleFromPermissions(String userId) async {
    try {
      final raw = await _supabase.rpc('restore_own_admin_role');
      final restored = raw?.toString().trim();
      if (isAdminRole(restored)) return restored;
    } catch (error) {
      debugPrint('[AuthRoute] restore_own_admin_role skipped: $error');
    }
    return null;
  }

  bool _coerceBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  void _logLoginRouteResolution({
    required String diagnosticContext,
    required LoginRouteResolution resolution,
  }) {
    debugPrint(
      '[AuthRoute][$diagnosticContext] '
      'authUserId=${resolution.userId ?? '-'} '
      'resolvedRole=${resolution.resolvedRole.name} '
      'rawRole=${resolution.rawRole ?? 'null'} '
      'userProfileFound=${resolution.profileFound} '
      'storeProfileFound=${resolution.storeProfileFound} '
      'chosenRoute=${resolution.chosenRoute}',
    );
  }

  Future<void> _recordAuthLoginAttempt({
    String? email,
    required String provider,
    required String status,
    required String authArea,
    String? errorCode,
    String? errorMessage,
    String? userId,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await _supabase.rpc(
        'record_auth_login_attempt',
        params: {
          'p_email': email?.trim().isEmpty ?? true ? null : email?.trim(),
          'p_provider': provider,
          'p_status': status,
          'p_auth_area': authArea,
          'p_error_code': errorCode,
          'p_error_message': errorMessage,
          'p_user_id': userId,
          'p_platform': _authPlatformLabel,
          'p_device_label': _authDeviceLabel,
          'p_user_agent': null,
          'p_metadata': metadata,
        },
      );
    } catch (error, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'AuthService',
        error,
        stackTrace,
        context: 'recordAuthLoginAttempt',
      );
    }
  }

  IbulAuthContextService get _authContext => IbulAuthContextService.instance;

  // Sign Out — clears Supabase session and active auth context.
  Future<void> signOut({String logoutType = 'global'}) async {
    final userId = currentUser?.id;
    final priorContext = _authContext.activeContext;
    AuthDebugLogger.logoutStart(
      type: logoutType,
      userId: userId,
      activeContext: priorContext,
    );

    try {
      await _signOutGoogleIfLoaded();
    } catch (error, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'AuthService',
        error,
        stackTrace,
        context: 'googleSignOut',
      );
    }
    await _supabase.auth.signOut();
    await clearSellerSwitchBackup();
    await _authContext.setActiveContext(IbulAuthContext.none);

    AuthDebugLogger.logoutFinish(
      type: logoutType,
      hasSupabaseSession: _supabase.auth.currentSession != null,
      customerState: false,
      sellerState: false,
      activeContext: IbulAuthContext.none,
    );
  }

  Future<void> signOutCustomer() => signOut(logoutType: 'customer');

  Future<void> signOutSeller() => signOut(logoutType: 'seller');

  Future<void> backupCurrentSessionForSellerSwitch() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      await SecureLocalStore.instance.delete(_sellerSwitchSessionBackupKey);
      return;
    }
    await SecureLocalStore.instance.writeString(
      _sellerSwitchSessionBackupKey,
      jsonEncode(session.toJson()),
    );
  }

  Future<bool> hasSellerSwitchBackup() async {
    final raw = await SecureLocalStore.instance.readString(
      _sellerSwitchSessionBackupKey,
    );
    return raw != null && raw.trim().isNotEmpty;
  }

  Future<void> clearSellerSwitchBackup() async {
    await SecureLocalStore.instance.delete(_sellerSwitchSessionBackupKey);
  }

  Future<bool> restoreUserSessionAfterSellerExit() async {
    final rawSession = await SecureLocalStore.instance.readString(
      _sellerSwitchSessionBackupKey,
    );

    AuthDebugLogger.logoutStart(
      type: 'seller_restore_consumer',
      userId: currentUser?.id,
    );

    try {
      await _signOutGoogleIfLoaded();
    } catch (e) {
      debugPrint('Google sign-out skipped during seller restore: $e');
    }
    await _supabase.auth.signOut();
    await _authContext.setActiveContext(IbulAuthContext.none);

    if (rawSession == null || rawSession.trim().isEmpty) {
      await SecureLocalStore.instance.delete(_sellerSwitchSessionBackupKey);
      AuthDebugLogger.logoutFinish(
        type: 'seller_restore_consumer',
        hasSupabaseSession: false,
        customerState: false,
        sellerState: false,
      );
      return false;
    }

    await _supabase.auth.recoverSession(rawSession);
    await SecureLocalStore.instance.delete(_sellerSwitchSessionBackupKey);
    await _authContext.setActiveContext(IbulAuthContext.customer);

    AuthDebugLogger.logoutFinish(
      type: 'seller_restore_consumer',
      hasSupabaseSession: _supabase.auth.currentSession != null,
      customerState: true,
      sellerState: false,
      activeContext: IbulAuthContext.customer,
    );
    return true;
  }

  Future<void> markCustomerLoginSuccess({
    required String userId,
    String? role,
  }) async {
    AuthDebugLogger.loginStart(type: 'customer');
    await _authContext.setActiveContext(IbulAuthContext.customer);
    AuthDebugLogger.loginSuccess(
      type: 'customer',
      userId: userId,
      role: role,
      activeContext: IbulAuthContext.customer,
    );
  }

  Future<void> markSellerLoginSuccess({
    required String userId,
    String? role,
    String? storeId,
  }) async {
    AuthDebugLogger.loginStart(type: 'seller');
    await _authContext.setActiveContext(IbulAuthContext.seller);
    AuthDebugLogger.loginSuccess(
      type: 'seller',
      userId: userId,
      role: role,
      storeId: storeId,
      activeContext: IbulAuthContext.seller,
    );
  }

  // Save/Update User in Supabase 'users' table
  Future<void> _saveUserToSupabase(
    User? user, {
    String? phone,
    String? displayName,
  }) async {
    if (user == null) return;

    final existing = await _supabase
        .from('users')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    final updates = <String, dynamic>{
      'id': user.id,
      'email': user.email,
      'display_name': displayName ?? user.userMetadata?['display_name'],
      'photo_url':
          user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (existing == null) {
      updates['role'] = 'user';
    }
    if (phone != null) updates['phone'] = phone;

    await _supabase.from('users').upsert(updates, onConflict: 'id');
  }

  Future<void> ensureCurrentUserRow({
    User? user,
    String? displayName,
    String? phone,
  }) async {
    final resolvedUser = user ?? _supabase.auth.currentUser;
    if (resolvedUser == null) return;

    final existing = await _supabase
        .from('users')
        .select('id')
        .eq('id', resolvedUser.id)
        .maybeSingle();

    final updates = <String, dynamic>{
      'id': resolvedUser.id,
      'email': resolvedUser.email,
      'display_name':
          displayName ??
          resolvedUser.userMetadata?['display_name'] ??
          resolvedUser.userMetadata?['name'],
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (phone != null) {
      updates['phone'] = phone;
    }

    if (existing == null) {
      updates['role'] = 'user';
      final initialPhoto =
          resolvedUser.userMetadata?['avatar_url'] ??
          resolvedUser.userMetadata?['picture'];
      if (initialPhoto != null && initialPhoto.toString().trim().isNotEmpty) {
        updates['photo_url'] = initialPhoto;
      }
    }

    await _supabase.from('users').upsert(updates, onConflict: 'id');
    await _activateMatchingSubAdminInvites(user: resolvedUser, phone: phone);
  }

  Future<void> _activateMatchingSubAdminInvites({
    required User user,
    String? phone,
  }) async {
    final email = user.email?.trim();
    final resolvedPhone = (phone ?? user.phone)?.trim();
    final filters = <String>[];
    if (email != null && email.isNotEmpty) {
      filters.add('email.eq.$email');
    }
    if (resolvedPhone != null && resolvedPhone.isNotEmpty) {
      filters.add('phone.eq.$resolvedPhone');
    }
    if (filters.isEmpty) return;

    try {
      final rows = await _supabase
          .from('store_sub_admins')
          .select('id')
          .eq('status', 'invited')
          .or(filters.join(','));
      final items = List<Map<String, dynamic>>.from(rows as List<dynamic>);
      for (final row in items) {
        final inviteId = row['id']?.toString().trim() ?? '';
        if (inviteId.isEmpty) continue;
        await _supabase
            .from('store_sub_admins')
            .update({'status': 'active'})
            .eq('id', inviteId);
      }
      if (items.isNotEmpty) {
        debugPrint(
          '[SubAdminActivation] activated=${items.length} '
          'userId=${user.id} email=${email ?? '-'}',
        );
      }
    } catch (error) {
      debugPrint(
        '[SubAdminActivation] skipped '
        'userId=${user.id} error=$error',
      );
    }
  }

  // Update User Profile (Weight/Height/Name/etc)
  Future<void> updateUserProfile({
    String? displayName,
    double? weight,
    double? height,
    String? gender,
    String? birthDate,
    String? style,
    String? phone,
    String? address,
    String? photoUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum açık değil');
    }

    final updates = <String, dynamic>{};

    if (weight != null) updates['weight'] = weight;
    if (height != null) updates['height'] = height;
    if (gender != null) updates['gender'] = gender;
    if (birthDate != null) updates['birth_date'] = birthDate;
    if (style != null) updates['style'] = style;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;
    if (displayName != null) updates['display_name'] = displayName;
    if (photoUrl != null) updates['photo_url'] = photoUrl;

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('users').update(updates).eq('id', user.id);
    }

    // Update Auth Metadata as well for display name / avatar
    if (displayName != null || photoUrl != null) {
      final metadata = <String, dynamic>{};
      if (displayName != null) metadata['display_name'] = displayName;
      if (photoUrl != null && photoUrl.startsWith('http')) {
        metadata['avatar_url'] = photoUrl;
      }
      if (metadata.isNotEmpty) {
        await _supabase.auth.updateUser(UserAttributes(data: metadata));
      }
    }
  }

  Future<String> uploadProfilePhotoBytes(
    Uint8List bytes, {
    String fileName = 'profile.jpg',
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum açık değil');
    }

    final normalizedName = fileName.trim().isNotEmpty ? fileName.trim() : 'profile.jpg';
    final extension = normalizedName.contains('.')
        ? normalizedName.split('.').last.toLowerCase()
        : 'jpg';
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
    // store-images RLS: ilk klasör auth.uid() olmalı (bkz. SUPABASE_FIX_SELLER.sql).
    final objectPath =
        '${user.id}/profiles/${DateTime.now().millisecondsSinceEpoch}.$extension';

    try {
      await _supabase.storage.from('store-images').uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
    } on StorageException catch (e) {
      final status = e.statusCode?.toString() ?? '';
      if (status == '403') {
        throw Exception(
          'Profil fotoğrafı depolamaya yüklenemedi: depolama izni reddedildi (403). '
          'Oturumunuzun geçerli olduğundan emin olun.',
        );
      }
      throw Exception(
        'Profil fotoğrafı depolamaya yüklenemedi: ${e.message}',
      );
    }

    return _supabase.storage.from('store-images').getPublicUrl(objectPath);
  }

  Future<void> updateUserEmail(String newEmail) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum açık değil');
    }

    final trimmed = newEmail.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw Exception('Geçerli bir e-posta adresi giriniz');
    }

    await _supabase.auth.updateUser(UserAttributes(email: trimmed));
    await _supabase.from('users').update({
      'email': trimmed,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  Future<void> updateUserPassword(String newPassword) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum açık değil');
    }
    if (newPassword.length < 6) {
      throw Exception('Şifre en az 6 karakter olmalıdır');
    }

    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  bool hasEmailPasswordProvider() {
    return hasEmailPasswordProviderFor(_supabase.auth.currentUser);
  }

  bool hasEmailPasswordProviderFor(User? user) {
    if (user == null) return false;
    final identities = user.identities;
    if (identities != null && identities.isNotEmpty) {
      return identities.any((identity) => identity.provider == 'email');
    }
    return false;
  }

  Future<void> verifyCurrentPassword(String currentPassword) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum açık değil');
    }
    if (!hasEmailPasswordProviderFor(user)) {
      throw Exception(
        'Bu hesap e-posta/şifre ile giriş desteklemiyor. '
        'Google ile giriş yaptıysanız aşağıdaki şifre sıfırlama e-postasını kullanın.',
      );
    }

    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      throw Exception('Hesap e-posta adresi bulunamadı');
    }

    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException catch (error) {
      if (error.code == 'invalid_credentials') {
        throw Exception('Mevcut şifre hatalı');
      }
      throw Exception(describeSignInError(error));
    }
  }

  Future<void> changePasswordWithVerification({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw Exception('Şifre en az 6 karakter olmalıdır');
    }
    if (currentPassword == newPassword) {
      throw Exception('Yeni şifre mevcut şifreden farklı olmalıdır');
    }

    await verifyCurrentPassword(currentPassword);
    await updateUserPassword(newPassword);
  }

  Future<void> sendPasswordResetEmail({String? email}) async {
    final user = _supabase.auth.currentUser;
    final targetEmail = (email ?? user?.email)?.trim().toLowerCase();
    if (targetEmail == null ||
        targetEmail.isEmpty ||
        !targetEmail.contains('@')) {
      throw Exception('Geçerli bir e-posta adresi bulunamadı');
    }

    await _supabase.auth.resetPasswordForEmail(targetEmail);
  }

  // Get User Profile Data
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    await ensureCurrentUserRow(user: user);

    final data = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return data;
  }

  // Submit Seller Application
  Future<void> submitSellerApplication(
    Map<String, dynamic> applicationData,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Kullanıcı girişi yapılmamış');

    final dbData = _mapApplicationToSnakeCase(applicationData);

    await _supabase
        .from('seller_applications')
        .insert({
          ...dbData,
          'user_id': user.id,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'user_email': user.email,
          'user_name': user.userMetadata?['display_name'],
        })
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic>? profile;
    try {
      profile = await getUserProfile();
    } catch (_) {}
    final currentRole = profile?['role']?.toString();
    if (isAdminRole(currentRole)) {
      throw Exception(
        'Admin hesabıyla satıcı başvurusu yapılamaz. Satıcı için ayrı bir e-posta kullanın.',
      );
    }
    final patch = SellerLoginAccess.pendingSellerUserPatch(
      currentRole: currentRole,
      isAdminRole: isAdminRole,
    );
    if (patch != null) {
      await _supabase.from('users').update({
        ...patch,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    }
  }

  // Register New Seller Account
  Future<AuthResponse> registerSeller(
    String email,
    String password,
    Map<String, dynamic> applicationData,
  ) async {
    try {
      // 1. Create Auth User
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': applicationData['contactName']},
      );

      final user = response.user;
      if (user == null) throw Exception('Kullanıcı oluşturulamadı');

      // 2. Create User Document (with seller role and unapproved status)
      await _supabase.from('users').insert({
        'id': user.id,
        'email': user.email,
        'display_name': applicationData['contactName'],
        'role': 'seller',
        'is_seller_approved': false,
        'created_at': DateTime.now().toIso8601String(),
        'phone': applicationData['phone'],
      });

      // 3. Create Application Document
      final dbData = _mapApplicationToSnakeCase(applicationData);

      await _supabase
          .from('seller_applications')
          .insert({
            ...dbData,
            'user_id': user.id,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
            'user_email': email,
            'user_name': applicationData['contactName'],
          })
          .timeout(const Duration(seconds: 30));

      return response;
    } catch (e) {
      debugPrint('Seller Registration Error: $e');
      rethrow;
    }
  }

  // Approve Seller (Admin function)
  Future<void> approveSeller(String applicationId, String userId) async {
    // 1. Get Application Data
    final appData = await _supabase
        .from('seller_applications')
        .select()
        .eq('id', applicationId)
        .single();

    // 2. Update Application Status
    await _supabase
        .from('seller_applications')
        .update({
          'status': 'approved',
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', applicationId);

    // 3. Update User Status without overwriting an admin role.
    String roleToWrite = 'seller';
    try {
      final existing = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final existingRole = existing?['role']?.toString();
      if (isAdminRole(existingRole) && existingRole != null) {
        roleToWrite = existingRole;
      }
    } catch (_) {}
    await _supabase
        .from('users')
        .update({'is_seller_approved': true, 'role': roleToWrite})
        .eq('id', userId);

    // 4. Create/Update Store Profile in 'stores' table (haritada görünsün diye store_lat/store_lng eklenir)
    final storeData = <String, dynamic>{
      'seller_id': userId,
      'business_name': appData['business_name'],
      'business_type': appData['business_type'],
      'tax_number': appData['tax_number'],
      'category': appData['category'],
      'has_physical_store': appData['has_physical_store'],
      'contact_name': appData['contact_name'],
      'email': appData['email'],
      'phone': appData['phone'],
      'address': appData['address'],
      'city': appData['city'],
      'district': appData['district'],
      'postal_code': appData['postal_code'],
      'bank_name': appData['bank_name'],
      'iban': appData['iban'],
      'account_holder': appData['account_holder'],
      'rating': 0.0,
      'is_verified': true,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_store_open': true,
      'accept_new_orders': true,
    };
    if (appData['store_lat'] != null) {
      storeData['store_lat'] = appData['store_lat'];
    }
    if (appData['store_lng'] != null) {
      storeData['store_lng'] = appData['store_lng'];
    }
    if (appData['logo_url'] != null) {
      storeData['logo_url'] = appData['logo_url'];
    }
    await _supabase.from('stores').upsert(storeData);
  }

  // Helper to map camelCase application data to snake_case DB columns
  Map<String, dynamic> _mapApplicationToSnakeCase(Map<String, dynamic> data) {
    final map = <String, dynamic>{
      'business_name': data['businessName'],
      'business_type': data['businessType'],
      'tax_number': data['taxNumber'],
      'category': data['category'],
      'has_physical_store': data['hasPhysicalStore'],
      'contact_name': data['contactName'],
      'email': data['email'],
      'phone': data['phone'],
      'address': data['address'],
      'city': data['city'],
      'district': data['district'],
      'postal_code': data['postalCode'],
      'bank_name': data['bankName'],
      'iban': data['iban'],
      'account_holder': data['accountHolder'],
      'documents': data['documents'], // JSONB column
    };
    if (data['storeLat'] != null) map['store_lat'] = data['storeLat'];
    if (data['storeLng'] != null) map['store_lng'] = data['storeLng'];
    if (data['logoUrl'] != null) map['logo_url'] = data['logoUrl'];
    return map;
  }

  // Delete User Account
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase.functions.invoke('delete-account');
      final status = response.status;
      if (status < 200 || status >= 300) {
        throw Exception('delete-account HTTP $status');
      }
    } catch (error) {
      debugPrint('[Auth] delete-account function failed: $error');
      await _supabase.from('users').delete().eq('id', user.id);
    }
    await signOut();
  }

  // --- USER DATA PERSISTENCE ---

  // Update User Data Field (Generic)
  Future<void> updateUserDataField(String fieldName, dynamic data) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final dbField = _mapFieldNameToDb(fieldName);
    await ensureCurrentUserRow(user: user);
    await _supabase.from('users').upsert({
      'id': user.id,
      'email': user.email,
      dbField: data,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'id');
  }

  // Get User Data Field
  Future<dynamic> getUserDataField(String fieldName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final dbField = _mapFieldNameToDb(fieldName);
    await ensureCurrentUserRow(user: user);
    final data = await _supabase
        .from('users')
        .select(dbField)
        .eq('id', user.id)
        .maybeSingle();
    if (data != null) {
      return data[dbField];
    }
    return null;
  }
}
