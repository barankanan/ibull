import 'package:ibul_app/app/ibul_main_runner.dart';
import 'package:ibul_app/core/ibul_app_mode.dart';

/// Customer web/mobile entry — no seller/admin/print/restaurant modules in tree.
void main() {
  runIbulMain(IbulAppMode.customer);
}
