import 'package:flutter/material.dart';

import '../../../../app/ibul_router.dart';
import '../../../../core/app_motion.dart';
import '../../../../core/auth/ibul_auth_context.dart';
import '../../../../core/home_navigation.dart';
import '../../../../screens/home_screen_gate.dart';
import '../../../../services/auth_service.dart';
import 'seller_exit_destination.dart';

/// Seller-login top-left back: pop when possible, otherwise customer-safe fallback.
abstract final class SellerLoginBackNavigation {
  SellerLoginBackNavigation._();

  static Future<void> handle(
    BuildContext context, {
    AuthService? authService,
    bool? hasSupabaseSessionOverride,
  }) async {
    debugPrint('[SellerLoginBack] tap');
    final navigator = Navigator.of(context);
    final canPop = navigator.canPop();
    debugPrint('[SellerLoginBack] can_pop=$canPop');
    if (canPop) {
      navigator.pop();
      debugPrint('[SellerLoginBack] navigate_success');
      return;
    }

    final auth = authService ?? AuthService();
    try {
      await IbulAuthContextService.instance.ensureLoaded();
    } catch (e) {
      debugPrint('[SellerLoginBack] error message=auth_context_load:$e');
    }
    if (!context.mounted) return;

    var hasSession = hasSupabaseSessionOverride ?? false;
    if (hasSupabaseSessionOverride == null) {
      try {
        hasSession = auth.currentUser != null;
      } catch (_) {
        hasSession = false;
      }
    }
    final customerActive = IbulAuthContextService.instance.isCustomerSessionActive(
      hasSupabaseSession: hasSession,
    );
    final destination = SellerExitDestination.resolve(
      customerSessionActive: customerActive,
      hasSupabaseSession: hasSession,
    );
    debugPrint('[SellerLoginBack] fallback_route=${destination.logLabel}');

    if (!context.mounted) return;
    try {
      IbulRouter.go(
        context,
        destination.route,
        extra: destination.arguments,
      );
    } catch (_) {
      final tabIndex = destination.arguments is HomeRouteArgs
          ? (destination.arguments! as HomeRouteArgs).initialIndex
          : 0;
      await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        buildAppPageRoute<void>(
          builder: (_) => HomeScreenGate(initialIndex: tabIndex),
        ),
        (route) => false,
      );
    }
    debugPrint('[SellerLoginBack] navigate_success');
  }
}
