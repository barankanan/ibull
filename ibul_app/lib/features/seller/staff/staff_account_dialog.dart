import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../models/sub_admin.dart';
import '../../../services/store_service.dart';
import '../panel/helpers/seller_panel_module_helpers.dart';
import '../panel/models/seller_panel_types.dart';
import 'staff_business_catalog.dart';
import 'staff_dialog_chrome.dart';
import 'staff_dialog_parts.dart';
import 'staff_page_access_widgets.dart';
import 'staff_live_summary.dart';
import 'staff_permission_summary.dart';

part 'staff_account_dialog_form.dart';

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
  late Set<SellerPermission> _grantCeiling;
  String? _templateId;
  late Set<SellerPermission> _initialSelected;
  late Set<String> _initialPages;
  late String _initialTitle;
  late String _initialName;
  late String _initialEmail;
  String? _initialBranch;
  var _hidePassword = true;
  var _busy = false;
  String? _error;
  final _summaryKey = GlobalKey();
  final _summaryFocus = FocusNode(debugLabel: 'staff-summary');

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
    _initialSelected = <SellerPermission>{..._selected};
    _initialPages = <String>{..._pages};
    _initialTitle = _jobTitle.text;
    _initialName = _name.text;
    _initialEmail = _email.text;
    _initialBranch = _branchId;
    for (final c in [_name, _email, _password, _jobTitle]) {
      c.addListener(_onText);
    }
  }

  void _togglePassword() => setState(() => _hidePassword = !_hidePassword);

  void _setBranch(String? value) => setState(() => _branchId = value);

  void _pickTemplate(StaffRoleTemplate role) {
    setState(() {
      if (role.id == 'custom') {
        // Özel Yetki: mevcut seçimi koru, yalnız şablonu işaretle.
        _templateId = 'custom';
        return;
      }
      _applyTemplate(role, fillTitle: true);
    });
  }

  void _onText() {
    if (mounted) setState(() {});
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
    _templateId = template.id;
    if (fillTitle) _jobTitle.text = template.label;
    _pages = _pagesFor(grants: selected);
  }

  StaffPageLevelPlan _plan(SellerModule module) =>
      staffPageLevelPlan(module, _pageOperations(module));

  StaffPageLevel _levelOf(SellerModule module) => staffCurrentPageLevel(
        plan: _plan(module),
        pageVisible: _pages.contains(module.name),
        selected: _selected,
      );

  /// Sayfa düzeyini değiştirir. Başka bir sayfanın hâlâ ihtiyaç duyduğu izin silinmez.
  void _setPageLevel(SellerModule module, StaffPageLevel level) {
    if (level == StaffPageLevel.custom) return;
    final plan = _plan(module);
    final needed = <SellerPermission>{};
    for (final other in _pageChoices) {
      if (other == module) continue;
      needed.addAll(_plan(other).opsFor(_levelOf(other)));
    }
    setState(() {
      for (final op in <SellerPermission>{...plan.viewOps, ...plan.fullOps}) {
        if (!needed.contains(op)) _selected.remove(op);
      }
      if (level == StaffPageLevel.none) {
        _pages.remove(module.name);
      } else {
        _pages.add(module.name);
        _selected.addAll(plan.opsFor(level));
      }
      _templateId = null;
    });
  }

  /// Açılıştaki duruma döner (yeni hesapta ilk şablona).
  void _revert() {
    setState(() {
      _selected = <SellerPermission>{..._initialSelected};
      _pages = <String>{..._initialPages};
      _jobTitle.text = _initialTitle;
      _name.text = _initialName;
      _email.text = _initialEmail;
      _password.clear();
      _branchId = _initialBranch;
      _templateId = null;
      _error = null;
    });
  }

  bool get _changed =>
      _selected.length != _initialSelected.length ||
      !_selected.containsAll(_initialSelected) ||
      _pages.length != _initialPages.length ||
      !_pages.containsAll(_initialPages) ||
      _jobTitle.text != _initialTitle ||
      _name.text != _initialName ||
      _email.text != _initialEmail ||
      _password.text.isNotEmpty ||
      _branchId != _initialBranch;

  String get _who => _name.text.trim().isNotEmpty
      ? _name.text.trim()
      : (widget.editing?.displayName ?? 'Personel');

  /// Geniş ekranda sağ özet paneline gider; dar ekranda alt sayfa açar.
  void _preview({required bool twoPane}) {
    if (!twoPane) {
      showStaffSummarySheet(context, _summary());
      return;
    }
    final target = _summaryKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
      );
    }
    _summaryFocus.requestFocus();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _jobTitle.dispose();
    _summaryFocus.dispose();
    super.dispose();
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
      _templateId = null;
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
      SellerPermission.manageTables,
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
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 700;
    final twoPane = size.width >= 1000;
    final member = widget.editing;
    final content = Column(
      children: [
        StaffDialogHeader(
          compact: compact,
          title: _editing ? 'Personel yetkileri' : 'Personel hesabı oluştur',
          subtitle: _editing
              ? (member?.displayName?.trim().isNotEmpty == true
                    ? member!.displayName!.trim()
                    : null)
              : null,
          chips: member == null ? const [] : _memberChips(member),
          onClose: _busy ? null : () => Navigator.pop(context),
        ),
        Expanded(
          child: twoPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _formPane(compact: false)),
                    _summaryPane(),
                  ],
                )
              : _formPane(compact: compact),
        ),
        StaffDialogFooter(
          busy: _busy,
          changed: _changed,
          canSave: widget.kind != StaffBusinessKind.unknown,
          error: _error,
          onRevert: _revert,
          onCancel: () => Navigator.pop(context),
          onPreview: () => _preview(twoPane: twoPane),
          onSave: _save,
        ),
      ],
    );
    if (compact) {
      return Dialog.fullscreen(
        backgroundColor: AppColors.background,
        child: SafeArea(child: content),
      );
    }
    final width = math.min(twoPane ? 1120.0 : 820.0, size.width * 0.92);
    final height = math.min(760.0, size.height * 0.92);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: AppColors.background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        key: const ValueKey('staff-dialog-box'),
        width: width,
        height: height,
        child: content,
      ),
    );
  }
}
