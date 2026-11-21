import 'package:flutter/material.dart';

import '../../../models/sub_admin.dart';
import '../../../services/store_service.dart';
import '../panel/helpers/seller_panel_module_helpers.dart';
import '../panel/models/seller_panel_types.dart';
import 'staff_business_catalog.dart';

class StaffAccountDraft {
  const StaffAccountDraft({
    required this.name,
    required this.email,
    required this.password,
    required this.staffRole,
    required this.branchId,
    required this.permissions,
    required this.jobTitle,
    this.visibleModules = const <String>[],
    this.revokedPermissions = const <SellerPermission>[],
  });

  final String name;
  final String email;
  final String password;
  final String staffRole;
  final String jobTitle;
  final String branchId;
  final List<SellerPermission> permissions;
  final List<String> visibleModules;
  final List<SellerPermission> revokedPermissions;
}

const _staffAccent = Color(0xFF6C63FF);

Future<void> showStaffAccountDialog({
  required BuildContext context,
  required StaffBusinessKind kind,
  required bool isOwner,
  required Set<String> heldPermissions,
  required List<Map<String, dynamic>> branches,
  required Future<void> Function(StaffAccountDraft draft) onSubmit,
  SubAdmin? editing,
  Set<SellerPermission> retainedPermissions = const <SellerPermission>{},
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _StaffAccountDialog(
      kind: kind,
      isOwner: isOwner,
      heldPermissions: heldPermissions,
      branches: branches,
      onSubmit: onSubmit,
      editing: editing,
      retainedPermissions: retainedPermissions,
    ),
  );
}

class _StaffAccountDialog extends StatefulWidget {
  const _StaffAccountDialog({
    required this.kind,
    required this.isOwner,
    required this.heldPermissions,
    required this.branches,
    required this.onSubmit,
    required this.retainedPermissions,
    this.editing,
  });

  final StaffBusinessKind kind;
  final bool isOwner;
  final Set<String> heldPermissions;
  final List<Map<String, dynamic>> branches;
  final Future<void> Function(StaffAccountDraft draft) onSubmit;
  final SubAdmin? editing;
  final Set<SellerPermission> retainedPermissions;

  @override
  State<_StaffAccountDialog> createState() => _StaffAccountDialogState();
}

class _StaffAccountDialogState extends State<_StaffAccountDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _jobTitle;
  late final List<StaffRoleTemplate> _roles;
  late final List<SellerModule> _pageChoices;
  late String? _branchId;
  late Set<SellerPermission> _selected;
  late Set<String> _pages;
  late Set<String> _fullAccess;
  late Set<SellerPermission> _grantCeiling;
  final Set<String> _openGroups = <String>{};
  var _hidePassword = true;
  var _busy = false;
  String? _error;

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final member = widget.editing;
    _name = TextEditingController(text: member?.displayName ?? '');
    _email = TextEditingController(text: member?.email ?? '');
    _password = TextEditingController();
    _roles = staffRoleTemplates(widget.kind);
    _pageChoices = pagesForStaffKind(widget.kind)
        .where((module) => module != SellerModule.downloadApp)
        .toList(growable: false);
    _jobTitle = TextEditingController(
      text: member?.jobTitle?.trim().isNotEmpty == true
          ? member!.jobTitle!.trim()
          : '',
    );
    _branchId = member?.branchId ??
        (widget.branches.length == 1
            ? widget.branches.first['id'].toString()
            : null);
    if (_editing) {
      _selected = member!.permissions.toSet();
    } else {
      _selected = <SellerPermission>{};
    }
    if (member == null && _roles.isNotEmpty) {
      _applyTemplate(_roles.first, fillTitle: true);
    } else {
      _pages = member?.visibleModules?.toSet() ??
          _pagesFor(grants: _selected, existingRole: member?.staffRole);
      if ((member?.jobTitle ?? '').trim().isEmpty && member != null) {
        _jobTitle.text = staffMemberRoleLabel(
          kind: widget.kind,
          storedRole: member.staffRole,
          permissions: member.permissions.toSet(),
        );
      }
    }
    _grantCeiling = staffGrantCeiling(
      isOwner: widget.isOwner,
      held: widget.heldPermissions,
    );
    _fullAccess = <String>{
      for (final module in _pageChoices)
        if (_pageOperations(module).isNotEmpty &&
            _pageOperations(module).every(_selected.contains))
          module.name,
    };
    _openGroups.addAll(sellerPermissionGroups.map((group) => group.title));
  }

  Set<SellerPermission> _pageOperations(SellerModule module) {
    return pageFullAccessOperations(module)
        .where(
          (permission) =>
              staffPermissionPersists(permission) &&
              _grantCeiling.contains(permission),
        )
        .toSet();
  }

  void _applyFullAccess(SellerModule module, bool enabled) {
    final operations = _pageOperations(module);
    if (enabled) {
      _pages.add(module.name);
      _fullAccess.add(module.name);
      _selected.addAll(operations);
      return;
    }
    _fullAccess.remove(module.name);
    for (final operation in operations) {
      final stillRequired = _fullAccess.any((name) {
        final other = _pageChoices.where((item) => item.name == name);
        if (other.isEmpty) return false;
        return _pageOperations(other.first).contains(operation);
      });
      if (!stillRequired) _selected.remove(operation);
    }
  }

  Set<String> _pagesFor({
    required Set<SellerPermission> grants,
    String? existingRole,
  }) {
    final role = securityRoleForStaffGrants(
      kind: widget.kind,
      grants: grants,
      existingRole: existingRole,
    );
    return modulesForStaff(
      modules: _pageChoices,
      isOwner: false,
      staffRole: role,
      permissions: grants.map((permission) => permission.name).toSet(),
    ).map((module) => module.name).toSet();
  }

  void _applyTemplate(StaffRoleTemplate template, {required bool fillTitle}) {
    final selected = staffTemplateSelection(
      template: template,
      isOwner: widget.isOwner,
      held: widget.heldPermissions,
    );
    _selected = selected;
    if (fillTitle) _jobTitle.text = template.label;
    _pages = _pagesFor(grants: selected);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _jobTitle.dispose();
    super.dispose();
  }

  List<SellerPermissionGroup> get _groups => staffGroupsForBusiness(
        kind: widget.kind,
        isOwner: widget.isOwner,
        held: widget.heldPermissions,
      );

  String _permissionSubtitle(SellerPermission permission) {
    final description = sellerPermissionDescription(permission);
    if (staffPermissionPersists(permission)) return description;
    final stored = widget.editing?.permissions.contains(permission) ?? false;
    if (stored && _selected.contains(permission)) {
      return '$description Kayıtlı yetki. Kaldırırsanız bir sonraki kayıtta silinir.';
    }
    return '$description Sunucu kaydı henüz açık değil.';
  }

  bool _canEditPermission(SellerPermission permission) {
    if (staffPermissionPersists(permission)) return true;
    final stored = widget.editing?.permissions.contains(permission) ?? false;
    return stored && _selected.contains(permission);
  }

  Future<void> _toggle(SellerPermission permission, bool value) async {
    if (!_canEditPermission(permission)) return;
    if (!value && !staffPermissionPersists(permission)) {
      setState(() => _selected.remove(permission));
      return;
    }
    if (!staffPermissionPersists(permission)) return;
    if (value && staffPermissionNeedsConfirm(permission)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(sellerPermissionLabel(permission)),
          content: Text(
            '${sellerPermissionDescription(permission)} Bu yetki ayrıca verilir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yetkiyi ver'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      if (value) {
        _selected.add(permission);
      } else {
        _selected.remove(permission);
      }
      _fullAccess = <String>{
        for (final module in _pageChoices)
          if (_pageOperations(module).isNotEmpty &&
              _pageOperations(module).every(_selected.contains))
            module.name,
      };
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final passwordError = _editing
        ? null
        : staffTemporaryPasswordError(_password.text);
    final email = _email.text.trim();
    final name = _name.text.trim();
    if (!_editing &&
        (passwordError != null ||
            name.isEmpty ||
            !email.contains('@') ||
            !email.contains('.'))) {
      setState(() {
        _error = passwordError ?? 'Ad ve geçerli e-posta gerekli.';
      });
      return;
    }
    if (_branchId == null) {
      setState(() => _error = 'Aktif bir şube seçin.');
      return;
    }
    final jobTitle = _jobTitle.text.trim();
    if (jobTitle.isEmpty) {
      setState(() => _error = 'Görev adı yazın. Bu ad güvenlik rolü değildir.');
      return;
    }
    if (_pages.isEmpty) {
      setState(() => _error = 'En az bir sayfa seçin.');
      return;
    }
    final withinCeiling = permissionsWithinRoleCeiling(
      storedRole: 'sub_admin',
      permissions: _selected,
    );
    const floorPermissions = <SellerPermission>{
      SellerPermission.transferTable,
      SellerPermission.splitBill,
      SellerPermission.takePartialPayment,
      SellerPermission.closeBill,
      SellerPermission.managePrintSettings,
      SellerPermission.manageStaff,
    };
    final revoked = (_editing ? widget.editing!.permissions : const <SellerPermission>[])
        .where(
          (permission) =>
              floorPermissions.contains(permission) &&
              !withinCeiling.contains(permission),
        )
        .toList(growable: false);
    final requested = <SellerPermission>{
      ...withinCeiling.where(staffPermissionPersists),
      ...withinCeiling.where((permission) => !staffPermissionPersists(permission)),
      ...widget.retainedPermissions.where(withinCeiling.contains),
    };
    final storedRole = securityRoleForStaffGrants(
      kind: widget.kind,
      grants: requested,
      existingRole: widget.editing?.staffRole,
    );
    if (requested.isEmpty || storedRole.isEmpty) {
      setState(() => _error = 'En az bir kaydedilebilir yetki seçin.');
      return;
    }
    if (!staffGrantWithinCeiling(
      isOwner: widget.isOwner,
      held: widget.heldPermissions,
      requested: requested.map((permission) => permission.name),
    )) {
      setState(() => _error = 'Sahip olmadığınız yetki verilemez.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        StaffAccountDraft(
          name: name,
          email: email,
          password: _password.text,
          staffRole: storedRole,
          jobTitle: jobTitle,
          branchId: _branchId!,
          permissions: requested.toList(growable: false),
          visibleModules: _pages.toList(growable: false),
          revokedPermissions: revoked,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    const inset = EdgeInsets.symmetric(horizontal: 16, vertical: 20);
    final maxWidth = media.width - inset.horizontal;
    final maxHeight = media.height - inset.vertical;
    return Dialog(
      insetPadding: inset,
      backgroundColor: const Color(0xFFF7F7F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth > 760 ? 760 : maxWidth,
          maxHeight: maxHeight > 640 ? 640 : maxHeight,
        ),
        child: SizedBox(
          width: maxWidth > 760 ? 760 : maxWidth,
          height: maxHeight > 640 ? 640 : maxHeight,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  if (widget.kind == StaffBusinessKind.unknown)
                    const _Note(
                      text:
                          'Mağaza kategorisi yüklenmeden personel hesabı açılmaz.',
                    ),
                  _field(
                    controller: _name,
                    label: 'Ad Soyad',
                    enabled: !_busy && !_editing,
                  ),
                  _field(
                    controller: _email,
                    label: 'E-posta',
                    enabled: !_busy && !_editing,
                    keyboard: TextInputType.emailAddress,
                  ),
                  if (!_editing) _passwordField(),
                  _field(
                    controller: _jobTitle,
                    label: 'Görev Adı / Ünvan',
                    enabled: !_busy,
                  ),
                  const _Note(
                    text:
                        'Görev adı yalnızca görünen etikettir. Sayfa seçimi işlem yetkisi vermez.',
                  ),
                  if (_roles.isNotEmpty) _suggestionChips(),
                  _branchField(),
                  const SizedBox(height: 8),
                  const Text(
                    'Görebileceği Sayfalar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final module in _pageChoices) ...[
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(sellerModuleLabel(module)),
                      value: _pages.contains(module.name),
                      onChanged: _busy
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  _pages.add(module.name);
                                } else {
                                  _pages.remove(module.name);
                                  if (_fullAccess.contains(module.name)) {
                                    _applyFullAccess(module, false);
                                  }
                                }
                              });
                            },
                    ),
                    if (_pageOperations(module).isNotEmpty)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 28),
                        title: const Text('Tam Erişim'),
                        subtitle: Text(
                          _pageOperations(module)
                              .map(sellerPermissionShortLabel)
                              .join(' · '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _fullAccess.contains(module.name),
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _applyFullAccess(module, value == true),
                              ),
                      )
                    else if (module == SellerModule.team ||
                        module == SellerModule.store)
                      const Padding(
                        padding: EdgeInsets.only(left: 28, bottom: 6),
                        child: Text(
                          'Mağaza profili ve personel yönetimi bu seçimle açılmaz.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  for (final gap in staffCapabilityGaps(widget.kind))
                    _Note(text: gap),
                  for (final group in _groups) _group(group),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ),
                ],
              ),
            ),
            _footer(),
          ],
        ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _editing ? 'Personel yetkileri' : 'Personel hesabı oluştur',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _busy || widget.kind == StaffBusinessKind.unknown
                ? null
                : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _staffAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(_busy ? 'Kaydediliyor...' : 'Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _password,
        enabled: !_busy,
        obscureText: _hidePassword,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'Şifre',
          helperText: 'En az 8 karakter.',
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
            icon: Icon(
              _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
    );
  }

  Widget _suggestionChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final role in _roles)
            ActionChip(
              label: Text(role.label),
              onPressed: _busy
                  ? null
                  : () => setState(
                        () => _applyTemplate(role, fillTitle: true),
                      ),
            ),
        ],
      ),
    );
  }

  Widget _branchField() {
    if (widget.branches.isEmpty && !_editing) {
      return const _Note(text: 'Önce işletmenize aktif bir şube tanımlayın.');
    }
    final branchIds = widget.branches
        .map((branch) => branch['id'].toString())
        .toSet();
    if (_editing && (_branchId == null || !branchIds.contains(_branchId))) {
      return _readonly('Şube', widget.editing?.branchId ?? 'Kayıtlı şube');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: _branchId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Şube',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
        items: [
          for (final branch in widget.branches)
            DropdownMenuItem(
              value: branch['id'].toString(),
              child: Text(branch['name']?.toString() ?? 'Şube'),
            ),
        ],
        onChanged: _busy
            ? null
            : (value) => setState(() => _branchId = value),
      ),
    );
  }

  Widget _readonly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
        ),
        child: Text(value),
      ),
    );
  }

  Widget _group(SellerPermissionGroup group) {
    final open = _openGroups.contains(group.title);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6EA)),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              group.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() {
              if (open) {
                _openGroups.remove(group.title);
              } else {
                _openGroups.add(group.title);
              }
            }),
          ),
          if (open)
            for (final permission in group.permissions)
              CheckboxListTile(
                value: _selected.contains(permission),
                dense: true,
                title: Text(sellerPermissionLabel(permission)),
                subtitle: Text(_permissionSubtitle(permission)),
                onChanged: _busy || !_canEditPermission(permission)
                    ? null
                    : (value) => _toggle(permission, value == true),
              ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
