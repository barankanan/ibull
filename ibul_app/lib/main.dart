import 'package:ibul_app/app/ibul_main_runner.dart';
import 'package:ibul_app/core/ibul_app_mode.dart';

/// Full IBUL entry — customer + deferred seller/admin/courier routes.
void main() {
  runIbulMain(IbulAppMode.full);
}
