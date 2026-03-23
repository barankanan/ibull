import 'package:flutter/material.dart';

import 'admin_panel_state_widgets.dart';

class AdminPanelLoadingState extends StatelessWidget {
  const AdminPanelLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPanelStatusScaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
