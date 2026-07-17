import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_motion.dart';
import '../../../../core/app_state.dart';
import '../../../../core/auth/ibul_auth_context.dart';
import '../../../../core/home_navigation.dart';
import '../../../../screens/home_screen.dart';
import '../../../../services/auth_service.dart';
import 'seller_exit_destination.dart';

/// Guards seller-panel logout against double-tap and sign-out hangs.
class SellerLogoutGuard {
  SellerLogoutGuard({
    AuthService? authService,
    Future<SellerExitResult> Function()? performExit,
  })  : _authService = authService ?? AuthService(),
        _performExit = performExit;

  static const Duration signOutTimeout = Duration(seconds: 8);
  static const Duration stopLiveWorkTimeout = Duration(seconds: 8);

  final AuthService _authService;
  final Future<SellerExitResult> Function()? _performExit;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> execute({
    required BuildContext context,
    Future<void> Function()? stopLiveWork,
    bool Function()? isMounted,
  }) async {
    debugPrint('[SellerLogout] tap');
    if (_isRunning) {
      debugPrint('[SellerLogout] already_running ignored');
      return;
    }
    _isRunning = true;
    debugPrint('[SellerLogout] start');
    try {
      if (stopLiveWork != null) {
        debugPrint('[SellerLogout] stop_live_work_start');
        try {
          // Canlı iş durdurma (realtime cancel, print hub stop) ağ koptuğunda
          // sonsuza kadar askıda kalabilir; timeout olmadan buton "donuyor"
          // gibi görünürdü. Timeout sonrası çıkışa devam edilir.
          await stopLiveWork().timeout(stopLiveWorkTimeout);
          debugPrint('[SellerLogout] stop_live_work_success');
        } on TimeoutException {
          debugPrint('[SellerLogout] error message=stop_live_work_timeout');
        } catch (e) {
          debugPrint('[SellerLogout] error message=stop_live_work:$e');
        }
      }

      final exitResult = await (_performExit ?? _defaultPerformExit)();

      debugPrint('[SellerLogout] clear_state_start');
      try {
        AppState().clearCustomerSessionView();
        debugPrint('[SellerLogout] clear_state_success');
      } catch (e) {
        debugPrint('[SellerLogout] error message=clear_state:$e');
      }

      if (isMounted != null && !isMounted()) return;
      if (!context.mounted) return;

      final destination = SellerExitDestination.resolve(
        customerSessionActive: exitResult.customerSessionActive,
        hasSupabaseSession: exitResult.hasSupabaseSession,
      );
      debugPrint(
        '[SellerLogout] navigate_resolve '
        'customerSession=${exitResult.customerSessionActive} '
        'route=${destination.logLabel}',
      );
      debugPrint('[SellerLogout] navigate_start route=${destination.logLabel}');

      final navigator = Navigator.of(context, rootNavigator: true);
      try {
        await navigator.pushNamedAndRemoveUntil(
          destination.route,
          (route) => false,
          arguments: destination.arguments,
        );
      } catch (_) {
        final tabIndex = destination.arguments is HomeRouteArgs
            ? (destination.arguments! as HomeRouteArgs).initialIndex
            : 0;
        await navigator.pushAndRemoveUntil(
          buildAppPageRoute<void>(
            builder: (_) => HomeScreen(initialIndex: tabIndex),
          ),
          (route) => false,
        );
      }
      debugPrint('[SellerLogout] navigate_success route=${destination.logLabel}');
    } catch (e) {
      debugPrint('[SellerLogout] error message=$e');
      if (isMounted != null && !isMounted()) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çıkış yapılamadı. Lütfen tekrar deneyin.')),
      );
    } finally {
      _isRunning = false;
      debugPrint('[SellerLogout] finished');
    }
  }

  Future<SellerExitResult> _defaultPerformExit() async {
    final hasBackup = await _authService.hasSellerSwitchBackup();
    var restoredCustomerSession = false;

    if (hasBackup) {
      debugPrint('[SellerLogout] restore_start');
      debugPrint('[SellerLogout] signout_start type=restore_consumer');
      try {
        restoredCustomerSession = await _authService
            .restoreUserSessionAfterSellerExit()
            .timeout(signOutTimeout);
        debugPrint('[SellerLogout] signout_success type=restore_consumer');
      } on TimeoutException {
        debugPrint('[SellerLogout] signout_timeout type=restore_consumer');
        await _authService.clearSellerSwitchBackup();
        try {
          await _authService.signOutSeller().timeout(signOutTimeout);
        } catch (_) {}
      } catch (e) {
        debugPrint('[SellerLogout] error message=restore:$e');
      }
    } else {
      debugPrint('[SellerLogout] signout_start type=seller');
      try {
        await _authService.signOutSeller().timeout(signOutTimeout);
        debugPrint('[SellerLogout] signout_success type=seller');
      } on TimeoutException {
        debugPrint('[SellerLogout] signout_timeout type=seller');
      } catch (e) {
        debugPrint('[SellerLogout] error message=signout:$e');
      }
    }

    await IbulAuthContextService.instance.ensureLoaded();
    var hasSession = false;
    try {
      hasSession = _authService.currentUser != null;
    } catch (_) {
      hasSession = false;
    }
    final customerActive = IbulAuthContextService.instance
        .isCustomerSessionActive(hasSupabaseSession: hasSession);

    return SellerExitResult(
      restoredCustomerSession: restoredCustomerSession,
      hasSupabaseSession: hasSession,
      customerSessionActive: customerActive || restoredCustomerSession,
    );
  }
}
