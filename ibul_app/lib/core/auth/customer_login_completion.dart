import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/ibul_router.dart';
import '../app_state.dart';
import '../home_navigation.dart';
import 'auth_flow_logger.dart';

/// Closes a pushed customer [LoginPage] or lands on home when login is a root route.
abstract final class CustomerLoginCompletion {
  static void finish(BuildContext context, {required bool sessionReady}) {
    var loggedIn = false;
    try {
      loggedIn = context.read<AppState>().isLoggedIn;
    } catch (_) {}
    final nav = Navigator.of(context);
    final canPop = nav.canPop();
    debugPrint(
      '[Auth][postLogin] session=$sessionReady '
      'appLoggedIn=$loggedIn canPop=$canPop',
    );
    if (!sessionReady && !loggedIn) {
      debugPrint('[Auth][postLogin] navigationResult=blocked_stale_state');
      return;
    }
    if (canPop) {
      AuthFlowLogger.redirect(target: 'pop:login');
      nav.pop(true);
      debugPrint('[Auth][postLogin] navigationResult=pop');
      return;
    }
    final next = GoRouter.maybeOf(context)?.state.uri.queryParameters['next'];
    if (next != null && next.startsWith('/') && !next.startsWith('//')) {
      AuthFlowLogger.redirect(target: next);
      IbulRouter.go(context, next);
      debugPrint('[Auth][postLogin] navigationResult=next');
      return;
    }
    AuthFlowLogger.redirect(target: '/home?tab=4');
    HomeNavigation.openHome(context, initialIndex: 4);
    debugPrint('[Auth][postLogin] navigationResult=home');
  }
}
