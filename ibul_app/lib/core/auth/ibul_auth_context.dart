import 'package:flutter/foundation.dart';

import '../secure_local_store.dart';
import '../../services/auth_service.dart';

/// Explicit customer vs seller auth surface — Supabase shares one session.
enum IbulAuthContext {
  none,
  customer,
  seller,
}

extension IbulAuthContextStorage on IbulAuthContext {
  String get storageValue {
    switch (this) {
      case IbulAuthContext.none:
        return 'none';
      case IbulAuthContext.customer:
        return 'customer';
      case IbulAuthContext.seller:
        return 'seller';
    }
  }

  static IbulAuthContext fromStorage(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'customer':
        return IbulAuthContext.customer;
      case 'seller':
        return IbulAuthContext.seller;
      default:
        return IbulAuthContext.none;
    }
  }
}

/// Persists which auth surface is active (`ibul_active_auth_context`).
class IbulAuthContextService extends ChangeNotifier {
  IbulAuthContextService._();

  static final IbulAuthContextService instance = IbulAuthContextService._();

  static const String storageKey = 'ibul_active_auth_context';

  IbulAuthContext _activeContext = IbulAuthContext.none;
  Future<void>? _loadFuture;

  IbulAuthContext get activeContext => _activeContext;

  bool get isCustomerContext => _activeContext == IbulAuthContext.customer;

  bool get isSellerContext => _activeContext == IbulAuthContext.seller;

  bool get hasExplicitContext => _activeContext != IbulAuthContext.none;

  Future<void> ensureLoaded() {
    return _loadFuture ??= _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final raw = await SecureLocalStore.instance.readString(storageKey);
    _activeContext = IbulAuthContextStorage.fromStorage(raw);
    notifyListeners();
  }

  Future<void> setActiveContext(
    IbulAuthContext context, {
    bool notify = true,
  }) async {
    await ensureLoaded();
    if (_activeContext == context) return;
    _activeContext = context;
    if (context == IbulAuthContext.none) {
      await SecureLocalStore.instance.delete(storageKey);
    } else {
      await SecureLocalStore.instance.writeString(
        storageKey,
        context.storageValue,
      );
    }
    if (notify) {
      notifyListeners();
    }
  }

  /// Customer UI treats the user as logged in only in customer context.
  bool isCustomerSessionActive({required bool hasSupabaseSession}) {
    return hasSupabaseSession && isCustomerContext;
  }

  /// Seller panel treats the user as logged in only in seller context.
  bool isSellerSessionActive({required bool hasSupabaseSession}) {
    return hasSupabaseSession && isSellerContext;
  }

  /// Drop in-memory context without touching Supabase (tests / reset).
  @visibleForTesting
  void resetForTesting({IbulAuthContext context = IbulAuthContext.none}) {
    _activeContext = context;
    _loadFuture = null;
  }
}

/// Role eligibility for customer vs seller login surfaces.
class AuthSessionGuard {
  AuthSessionGuard._();

  static bool acceptsCustomerLogin(LoginResolvedRole role) {
    switch (role) {
      case LoginResolvedRole.user:
      case LoginResolvedRole.seller:
        return true;
      case LoginResolvedRole.waiter:
      case LoginResolvedRole.admin:
      case LoginResolvedRole.unknown:
        return false;
    }
  }

  static bool acceptsSellerLogin(LoginResolvedRole role) {
    switch (role) {
      case LoginResolvedRole.seller:
      case LoginResolvedRole.waiter:
      case LoginResolvedRole.admin:
        return true;
      case LoginResolvedRole.user:
      case LoginResolvedRole.unknown:
        return false;
    }
  }

  static bool isSellerOnlyProfile(LoginResolvedRole role) {
    return role == LoginResolvedRole.waiter ||
        role == LoginResolvedRole.admin;
  }

  static bool isCustomerOnlyProfile(LoginResolvedRole role) {
    return role == LoginResolvedRole.user;
  }

  static String customerLoginRejectionMessage(LoginResolvedRole role) {
    if (role == LoginResolvedRole.waiter) {
      return 'Bu hesap garson hesabı. Satıcı girişi kullanın.';
    }
    if (role == LoginResolvedRole.admin) {
      return 'Bu hesap admin hesabı. Admin girişi kullanın.';
    }
    if (role == LoginResolvedRole.unknown) {
      return 'Rol bilgisi çözümlenemedi. Lütfen tekrar deneyin.';
    }
    return 'Bu hesap müşteri girişi için uygun değil.';
  }

  static String sellerLoginRejectionMessage(LoginResolvedRole role) {
    if (role == LoginResolvedRole.user) {
      return 'Bu hesap satıcı hesabı değil. Müşteri hesabıyla giriş yapın.';
    }
    return 'Bu e-posta adresi satıcı/garson hesabına ait değil.';
  }
}
