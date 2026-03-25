import 'package:flutter/material.dart';

enum AdminPanelOperationMode { defaultPanel, ibul, ihiz }

class AdminPanelMenuDefinition {
  const AdminPanelMenuDefinition({
    required this.icon,
    required this.title,
    required this.groupLabel,
    required this.groupIcon,
    this.moduleKey,
  });

  final IconData icon;
  final String title;
  final String groupLabel;
  final IconData groupIcon;
  final String? moduleKey;
}

class AdminPanelLayoutDefinition {
  const AdminPanelLayoutDefinition({
    required this.panelTitle,
    required this.menuDefinitions,
    this.showSearch = true,
  });

  final String panelTitle;
  final List<AdminPanelMenuDefinition> menuDefinitions;
  final bool showSearch;
}
