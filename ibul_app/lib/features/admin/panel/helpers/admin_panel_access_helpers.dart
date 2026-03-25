import 'package:flutter/material.dart';

import '../models/admin_menu_registry.dart';
import '../models/admin_panel_definitions.dart';
import '../widgets/admin_sidebar.dart';

List<AdminPanelMenuDefinition> visibleAdminPanelMenusFromDefinitions(
  List<AdminPanelMenuDefinition> definitions,
  Set<String> allowedModules,
) {
  if (allowedModules.isEmpty) {
    return const [];
  }

  return definitions
      .where((entry) {
        final moduleKey = entry.moduleKey;
        if (moduleKey == null) {
          return true;
        }
        if (allowedModules.contains('permission_system') &&
            moduleKey == 'permission_system') {
          return true;
        }
        return allowedModules.contains(moduleKey);
      })
      .toList(growable: false);
}

List<AdminPanelMenuDefinition> visibleAdminPanelMenus(
  Set<String> allowedModules,
) {
  return visibleAdminPanelMenusFromDefinitions(
    ibulAdminMenuDefinitions,
    allowedModules,
  );
}

String resolveAdminSelectedMenu({
  required String currentSelectedMenu,
  required List<AdminPanelMenuDefinition> visibleMenus,
}) {
  final hasCurrentSelection = visibleMenus.any(
    (entry) => entry.title == currentSelectedMenu,
  );
  if (hasCurrentSelection) {
    return currentSelectedMenu;
  }
  if (visibleMenus.isNotEmpty) {
    return visibleMenus.first.title;
  }
  return currentSelectedMenu;
}

String adminOperationModeLabel(
  AdminPanelOperationMode mode,
  String adminRoleLabel,
) {
  switch (mode) {
    case AdminPanelOperationMode.defaultPanel:
      return adminRoleLabel;
    case AdminPanelOperationMode.ibul:
      return 'İbul';
    case AdminPanelOperationMode.ihiz:
      return 'İhız';
  }
}

List<AdminPanelMenuEntry> buildAdminPanelMenuEntries({
  required List<AdminPanelMenuDefinition> definitions,
  required String selectedTitle,
  required ValueChanged<String> onSelect,
}) {
  return definitions
      .map(
        (entry) => AdminPanelMenuEntry(
          icon: entry.icon,
          title: entry.title,
          isActive: selectedTitle == entry.title,
          onTap: () => onSelect(entry.title),
        ),
      )
      .toList(growable: false);
}

List<AdminPanelMenuSectionEntry> buildAdminPanelMenuSectionEntries({
  required List<AdminPanelMenuDefinition> definitions,
  required String selectedTitle,
  required ValueChanged<String> onSelect,
}) {
  final groupedEntries = <String, List<AdminPanelMenuDefinition>>{};
  final groupIcons = <String, IconData>{};

  for (final definition in definitions) {
    groupedEntries
        .putIfAbsent(definition.groupLabel, () => <AdminPanelMenuDefinition>[])
        .add(definition);
    groupIcons[definition.groupLabel] = definition.groupIcon;
  }

  return groupedEntries.entries
      .map(
        (group) => AdminPanelMenuSectionEntry(
          label: group.key,
          icon: groupIcons[group.key] ?? Icons.label_outline,
          items: buildAdminPanelMenuEntries(
            definitions: group.value,
            selectedTitle: selectedTitle,
            onSelect: onSelect,
          ),
        ),
      )
      .toList(growable: false);
}
