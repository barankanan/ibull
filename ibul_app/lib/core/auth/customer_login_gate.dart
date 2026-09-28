import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../screens/login_page.dart';
import '../app_state.dart';
import '../app_motion.dart';

/// Opens customer login and returns whether the session is authenticated.
abstract final class CustomerLoginGate {
  static Future<bool> open(BuildContext context) async {
    if (context.read<AppState>().isLoggedIn) return true;
    final result = await Navigator.of(context).push<bool>(
      buildAppPageRoute<bool>(
        builder: (_) => const LoginPage(),
      ),
    );
    if (!context.mounted) return false;
    return result == true;
  }
}
