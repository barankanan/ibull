import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'phase13_boot.dart';

/// Web initial URL only, via the same package initialize uses.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  mark('phase13_deeplink_start');
  try {
    await AppLinks().getInitialLink();
  } catch (_) {}
  mark('phase13_deeplink_return');
  await bootRouter('w7');
}
