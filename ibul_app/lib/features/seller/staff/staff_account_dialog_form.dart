part of 'staff_account_dialog.dart';

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

extension _StaffDialogSections on _StaffAccountDialogState {
  Widget _summary() {
    final persisted = _selected.where(staffPermissionPersists).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return StaffLiveSummary(
      who: _who,
      lines: staffPermissionSummary(_selected),
      pages: [
        for (final module in _pageChoices)
          if (_pages.contains(module.name))
            StaffSummaryPage(
              sellerModuleLabel(module),
              staffPageLevelLabel(_levelOf(module)),
            ),
      ],
      warnings: staffSecurityWarnings(
        selected: _selected,
        hasPages: _pages.isNotEmpty,
      ),
      permissionNames: [for (final p in persisted) p.name],
    );
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

  List<String> _memberChips(SubAdmin member) {
    final d = member.createdAt;
    return [
      member.status == 'active' ? 'Aktif' : 'Pasif',
      _branchName(),
      staffMemberRoleLabel(
        kind: widget.kind,
        storedRole: member.staffRole,
        permissions: member.permissions.toSet(),
      ),
      if (d != null)
        'Oluşturulma ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
    ];
  }

  String _branchName() {
    final id = widget.editing?.branchId ?? _branchId;
    for (final branch in widget.branches) {
      if (branch['id'].toString() == id) {
        return branch['name']?.toString() ?? 'Şube';
      }
    }
    return id == null || id.isEmpty ? 'Şube yok' : 'Kayıtlı şube';
  }

  Widget _summaryPane() {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        key: const ValueKey('staff-summary-scroll'),
        padding: const EdgeInsets.all(20),
        child: ListenableBuilder(
          listenable: _summaryFocus,
          builder: (context, child) => Focus(
            focusNode: _summaryFocus,
            child: AnimatedContainer(
              key: _summaryKey,
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _summaryFocus.hasFocus
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: child,
            ),
          ),
          child: _summary(),
        ),
      ),
    );
  }

  Widget _formPane({required bool compact}) {
    final enabled = !_busy;
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.kind == StaffBusinessKind.unknown)
            const StaffNote(
              text: 'Mağaza kategorisi yüklenmeden personel hesabı açılmaz.',
            ),
          StaffSectionCard(
            title: 'Personel bilgileri',
            compact: compact,
            child: Column(
              children: [
                StaffFieldGrid(
                  children: [
                    _field(_name, 'Ad Soyad', enabled && !_editing),
                    _field(
                      _email,
                      'E-posta',
                      enabled && !_editing,
                      keyboard: TextInputType.emailAddress,
                    ),
                  ],
                ),
                if (!_editing) _passwordField(),
              ],
            ),
          ),
          StaffSectionCard(
            title: 'Görev / ünvan',
            subtitle:
                'Görev adı yalnızca görünen etikettir. Sayfa seçimi işlem yetkisi vermez.',
            compact: compact,
            child: _field(_jobTitle, 'Görev adı / ünvan', enabled),
          ),
          StaffSectionCard(
            title: 'Şube',
            compact: compact,
            child: _branchField(),
          ),
          if (_roles.isNotEmpty)
            StaffSectionCard(
              title: 'Yetki şablonu',
              subtitle: 'Şablon seçince sayfa ve işlem izinleri hazır gelir.',
              compact: compact,
              child: _suggestionChips(),
            ),
          StaffSectionCard(
            title: 'Sayfa erişimi',
            subtitle: 'Her sayfa için erişim düzeyini seçin.',
            compact: compact,
            child: _pageAccess(enabled),
          ),
          StaffSectionCard(
            title: 'Özel işlem izinleri',
            subtitle: 'Sayfa düzeyinden bağımsız tek tek açılıp kapanır.',
            compact: compact,
            child: _actionPermissions(enabled),
          ),
        ],
      ),
    );
  }

  Widget _pageAccess(bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in staffPageCategories(_pageChoices)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              category.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          for (var i = 0; i < category.modules.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            StaffPageAccessRow(
              module: category.modules[i],
              plan: _plan(category.modules[i]),
              current: _levelOf(category.modules[i]),
              enabled: enabled,
              onChanged: (level) => _setPageLevel(category.modules[i], level),
            ),
          ],
        ],
      ],
    );
  }

  Widget _actionPermissions(bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final gap in staffCapabilityGaps(widget.kind))
          StaffNote(text: gap),
        for (final group in _groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              group.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textGrey,
              ),
            ),
          ),
          for (final permission in group.permissions)
            StaffPermissionSwitchRow(
              permission: permission,
              description: _permissionSubtitle(permission),
              value: _selected.contains(permission),
              onChanged: enabled && _canEditPermission(permission)
                  ? (value) => _toggle(permission, value)
                  : null,
            ),
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    bool enabled, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 15),
      decoration: staffInputDecoration(label: label),
    );
  }

  Widget _passwordField() {
    return TextField(
      controller: _password,
      enabled: !_busy,
      obscureText: _hidePassword,
      enableSuggestions: false,
      autocorrect: false,
      style: const TextStyle(fontSize: 15),
      decoration: staffInputDecoration(
        label: 'Şifre',
        helper: 'En az 8 karakter.',
        suffix: IconButton(
          tooltip: _hidePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
          onPressed: _togglePassword,
          icon: Icon(
            _hidePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  Widget _suggestionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in _roles)
          ChoiceChip(
            label: Text(role.label, style: const TextStyle(fontSize: 14)),
            selected: role.id == 'custom'
                ? (_templateId == null || _templateId == 'custom')
                : _templateId == role.id,
            selectedColor: AppColors.primary.withValues(alpha: 0.16),
            onSelected: _busy ? null : (_) => _pickTemplate(role),
          ),
      ],
    );
  }

  Widget _branchField() {
    if (widget.branches.isEmpty && !_editing) {
      return const StaffNote(
        text: 'Önce işletmenize aktif bir şube tanımlayın.',
      );
    }
    final branchIds = widget.branches
        .map((branch) => branch['id'].toString())
        .toSet();
    if (_editing && (_branchId == null || !branchIds.contains(_branchId))) {
      return InputDecorator(
        decoration: staffInputDecoration(label: 'Şube'),
        child: Text(widget.editing?.branchId ?? 'Kayıtlı şube'),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('branch-$_branchId'),
      initialValue: _branchId,
      isExpanded: true,
      style: const TextStyle(fontSize: 15, color: AppColors.ink),
      decoration: staffInputDecoration(label: 'Şube'),
      items: [
        for (final branch in widget.branches)
          DropdownMenuItem(
            value: branch['id'].toString(),
            child: Text(branch['name']?.toString() ?? 'Şube'),
          ),
      ],
      onChanged: _busy ? null : _setBranch,
    );
  }
}
