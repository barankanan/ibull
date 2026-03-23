import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
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
  GoogleSignIn? _googleSignIn;

  AuthService();

  static bool isAdminRole(String? role) {
    if (role == null) return false;
    return role == 'admin' ||
        role == 'super_admin' ||
        role.startsWith('admin_');
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

  GoogleSignIn get _googleSignInClient {
    return _googleSignIn ??= kIsWeb
        ? GoogleSignIn(
            clientId:
                '926056125070-vhmpff59pmeg9b917h39ug7ecqmi36da.apps.googleusercontent.com',
          )
        : GoogleSignIn(
            clientId:
                '926056125070-vhmpff59pmeg9b917h39ug7ecqmi36da.apps.googleusercontent.com',
            serverClientId:
                '926056125070-vhmpff59pmeg9b917h39ug7ecqmi36da.apps.googleusercontent.com',
          );
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
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignInClient.signIn();
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

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
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
      print('Google Sign-In Error: $e');
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
      print('Email Sign-In Error: $e');
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
      print('Sign-Up Error: $e');
      rethrow;
    }
  }

  String describeSignInError(Object error, {bool adminMode = false}) {
    if (error is AuthApiException) {
      switch (error.code) {
        case 'invalid_credentials':
          return adminMode
              ? 'E-posta veya şifre Supabase Auth tarafında doğrulanamadı. Bu hesap Google ile açıldıysa parola ile admin girişi çalışmaz.'
              : 'E-posta veya şifre Supabase Auth tarafında doğrulanamadı. Bu hesap Google ile açıldıysa parola ile giriş çalışmaz.';
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
    } catch (_) {}
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      print('Google sign-out skipped: $e');
    }
    await _supabase.auth.signOut();
    await clearSellerSwitchBackup();
  }

  Future<void> backupCurrentSessionForSellerSwitch() async {
    final session = _supabase.auth.currentSession;
    final prefs = await SharedPreferences.getInstance();
    if (session == null) {
      await prefs.remove(_sellerSwitchSessionBackupKey);
      return;
    }
    await prefs.setString(
      _sellerSwitchSessionBackupKey,
      jsonEncode(session.toJson()),
    );
  }

  Future<bool> hasSellerSwitchBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sellerSwitchSessionBackupKey);
    return raw != null && raw.trim().isNotEmpty;
  }

  Future<void> clearSellerSwitchBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sellerSwitchSessionBackupKey);
  }

  Future<bool> restoreUserSessionAfterSellerExit() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString(_sellerSwitchSessionBackupKey);

    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      print('Google sign-out skipped during seller restore: $e');
    }
    await _supabase.auth.signOut();

    if (rawSession == null || rawSession.trim().isEmpty) {
      await prefs.remove(_sellerSwitchSessionBackupKey);
      return false;
    }

    await _supabase.auth.recoverSession(rawSession);
    await prefs.remove(_sellerSwitchSessionBackupKey);
    return true;
  }

  // Save/Update User in Supabase 'users' table
  Future<void> _saveUserToSupabase(
    User? user, {
    String? phone,
    String? displayName,
  }) async {
    if (user == null) return;

    final updates = {
      'id': user.id,
      'email': user.email,
      'display_name': displayName ?? user.userMetadata?['display_name'],
      'photo_url':
          user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
      'role': 'user', // default role
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Only add phone if provided
    if (phone != null) updates['phone'] = phone;

    // Upsert: Insert if not exists, update if exists
    await _supabase.from('users').upsert(updates);
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
      'photo_url':
          resolvedUser.userMetadata?['avatar_url'] ??
          resolvedUser.userMetadata?['picture'],
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (phone != null) {
      updates['phone'] = phone;
    }

    if (existing == null) {
      updates['role'] = resolvedUser.userMetadata?['role'] ?? 'user';
    }

    await _supabase.from('users').upsert(updates, onConflict: 'id');
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
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{};

    if (weight != null) updates['weight'] = weight;
    if (height != null) updates['height'] = height;
    if (gender != null) updates['gender'] = gender;
    if (birthDate != null) updates['birth_date'] = birthDate;
    if (style != null) updates['style'] = style;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;
    if (displayName != null) updates['display_name'] = displayName;

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('users').update(updates).eq('id', user.id);
    }

    // Update Auth Metadata as well for display name
    if (displayName != null) {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'display_name': displayName}),
      );
    }
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
      print('Seller Registration Error: $e');
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

    // 3. Update User Status
    await _supabase
        .from('users')
        .update({'is_seller_approved': true, 'role': 'seller'})
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
    if (appData['store_lat'] != null)
      storeData['store_lat'] = appData['store_lat'];
    if (appData['store_lng'] != null)
      storeData['store_lng'] = appData['store_lng'];
    if (appData['logo_url'] != null)
      storeData['logo_url'] = appData['logo_url'];
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

    // Delete from Database (Cascade usually handles this, but explicit delete is safer)
    await _supabase.from('users').delete().eq('id', user.id);

    // Delete from Authentication (Admin SDK usually required for this, but user can delete self if configured)
    // Note: Supabase Client SDK doesn't have deleteUser() for self unless using RPC or Edge Function usually.
    // For now, we will rely on database deletion or implementing an Edge Function.
    // However, to keep it simple, we'll try to call the management endpoint if available or just sign out.
    // Actually, Supabase doesn't allow self-deletion via client SDK by default security.
    // We will just sign out for now and mark as deleted in DB.
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
