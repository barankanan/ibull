import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../services/desktop_print_hub.dart';

List<SingleChildWidget> buildDesktopPrintProviders() => [
  ChangeNotifierProvider(create: (_) => DesktopPrintHub()),
];
