import '../../models/admin_permissions.dart';

const Set<String> adminRolesWithDefaultIhizAccess = <String>{
  'super_admin',
  'admin',
  'admin_store_ops',
  'admin_support',
  'admin_finance',
};

List<String> normalizeAdminModules(Iterable<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => AdminModules.all.contains(value))
      .toSet()
      .toList()
    ..sort();
}

List<String> withDefaultIhizAccess(
  String roleKey,
  Iterable<String> modules,
) {
  final resolved = normalizeAdminModules(modules);
  if (!adminRolesWithDefaultIhizAccess.contains(roleKey)) {
    return resolved;
  }
  if (resolved.contains(AdminModules.ihiz)) {
    return resolved;
  }
  return normalizeAdminModules(<String>[...resolved, AdminModules.ihiz]);
}
