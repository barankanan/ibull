import 'package:flutter/material.dart';

import '../../../models/sub_admin.dart';
import '../../../services/store_service.dart';
import '../../../utils/text_normalizer.dart';
import 'staff_account_dialog.dart';
import 'staff_business_catalog.dart';

String _staffStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Aktif';
    case 'inactive':
      return 'Pasif';
    case 'invited':
      return 'Davet';
    default:
      return 'Pasif';
  }
}

class StaffTeamPanel extends StatefulWidget {
  const StaffTeamPanel({
    super.key,
    required this.kind,
    required this.members,
    required this.isOwner,
    required this.heldPermissions,
    required this.loadBranches,
    required this.onCreate,
    required this.onEdit,
    required this.onDeactivate,
    required this.onDelete,
    required this.onActivate,
    required this.canDelete,
    required this.canManage,
    this.onSetPassword,
  });

  final StaffBusinessKind kind;
  final List<SubAdmin> members;
  final bool isOwner;
  final Set<String> heldPermissions;
  final Future<List<Map<String, dynamic>>> Function() loadBranches;
  final Future<void> Function(StaffAccountDraft draft) onCreate;
  final Future<void> Function(SubAdmin member, StaffAccountDraft draft) onEdit;
  final Future<void> Function(SubAdmin member) onDeactivate;
  final Future<void> Function(SubAdmin member) onDelete;
  final Future<void> Function(SubAdmin member) onActivate;
  final String? Function(SubAdmin member) canDelete;
  final bool canManage;

  /// Owner only: the server refuses password changes from a sub-admin.
  final Future<void> Function(SubAdmin member, String password)? onSetPassword;

  @override
  State<StaffTeamPanel> createState() => _StaffTeamPanelState();
}

class _StaffTeamPanelState extends State<StaffTeamPanel> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _branches = const <Map<String, dynamic>>[];
  String? _branchFilter;
  String? _roleFilter;
  String? _branchError;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final rows = await widget.loadBranches();
      if (!mounted) return;
      setState(() {
        _branches = rows;
        _branchError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _branchError = 'Şubeler yüklenemedi.');
    }
  }

  List<SubAdmin> get _visible {
    final query = TextNormalizer.normalize(_search.text);
    return widget.members.where((member) {
      final customTitle = member.jobTitle?.trim() ?? '';
      final role = customTitle.isNotEmpty
          ? customTitle
          : staffMemberRoleLabel(
              kind: widget.kind,
              storedRole: member.staffRole,
              permissions: member.permissions.toSet(),
            );
      if (_roleFilter != null && role != _roleFilter) return false;
      if (_branchFilter != null && member.branchId != _branchFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = TextNormalizer.normalize(
        '${member.displayName ?? ''} ${member.email ?? ''} ${member.phone ?? ''}',
      );
      return haystack.contains(query);
    }).toList(growable: false);
  }

  int _countStatus(String status) {
    return widget.members.where((member) => member.status == status).length;
  }

  Future<void> _create() async {
    await showStaffAccountDialog(
      context: context,
      kind: widget.kind,
      isOwner: widget.isOwner,
      heldPermissions: widget.heldPermissions,
      branches: _branches,
      onSubmit: widget.onCreate,
    );
  }

  Future<void> _edit(SubAdmin member) async {
    final retained = staffPermissionsRetainedOnEdit(
      kind: widget.kind,
      current: member.permissions,
    );
    await showStaffAccountDialog(
      context: context,
      kind: widget.kind,
      isOwner: widget.isOwner,
      heldPermissions: widget.heldPermissions,
      branches: _branches,
      editing: member,
      retainedPermissions: retained,
      onSubmit: (draft) => widget.onEdit(member, draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final roles = <String>{
      for (final member in widget.members)
        staffMemberRoleLabel(
          kind: widget.kind,
          storedRole: member.staffRole,
          permissions: member.permissions.toSet(),
        ),
    }.toList()
      ..sort();
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _stat('Personel', widget.members.length),
            _stat('Aktif', _countStatus('active')),
            _stat('Pasif', _countStatus('inactive')),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: widget.canManage &&
                        widget.isOwner &&
                        widget.kind != StaffBusinessKind.unknown
                    ? _create
                    : null,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Yeni personel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Personel ara',
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              _filter(
                'Şube',
                _branchFilter,
                [for (final branch in _branches) branch['id'].toString()],
                (id) => _branches
                    .firstWhere((row) => row['id'].toString() == id)['name']
                    .toString(),
                (value) => setState(() => _branchFilter = value),
              ),
              _filter(
                'Rol',
                _roleFilter,
                roles,
                (value) => value,
                (value) => setState(() => _roleFilter = value),
              ),
            ],
          ),
        ),
        if (_branchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_branchError!),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('Bu işletmede personel yok.'))
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _card(visible[index]),
                ),
        ),
      ],
    );
  }

  Widget _stat(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _filter(
    String label,
    String? value,
    List<String> items,
    String Function(String value) title,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        // Uzun görev/şube adları 180px kutuyu taşırmasın (sahibin girdiği
        // serbest metin): genişliğe sığdır ve kısalt.
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Tümü')),
          for (final item in items)
            DropdownMenuItem(
              value: item,
              child: Text(title(item), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _setPassword(SubAdmin member) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _StaffPasswordDialog(),
    );
    if (password == null || !mounted) return;
    try {
      await widget.onSetPassword!(member, password);
    } catch (error) {
      if (!mounted) return;
      final text = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _confirmDelete(SubAdmin member) async {
    final blocked = widget.canDelete(member);
    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(blocked)));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Personel silinsin mi?'),
        content: const Text(
          'Personelin işletme erişimi iptal edilir ve aktif listeden çıkar. '
          'Geçmiş siparişler, ödemeler ve denetim izleri silinmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Erişimi iptal et'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete(member);
  }

  Widget _card(SubAdmin member) {
    final role = staffMemberRoleLabel(
      kind: widget.kind,
      storedRole: member.staffRole,
      permissions: member.permissions.toSet(),
    );
    final branchNames = _branches
        .where((row) => row['id'].toString() == member.branchId)
        .map((row) => row['name'].toString())
        .toList(growable: false);
    final branchName = branchNames.isEmpty ? null : branchNames.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.displayName?.trim().isNotEmpty == true
                ? member.displayName!.trim()
                : (member.email ?? member.phone ?? 'Personel'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${member.jobTitle?.trim().isNotEmpty == true ? member.jobTitle!.trim() : role}'
            ' · $role · ${branchName ?? 'Şube yok'} · ${_staffStatusLabel(member.status)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final permission in member.permissions.take(6))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    sellerPermissionShortLabel(permission),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4C1D95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (member.permissions.length > 6)
                Text(
                  '+${member.permissions.length - 6}',
                  style: const TextStyle(fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: widget.canManage ? () => _edit(member) : null,
                child: const Text('Düzenle'),
              ),
              OutlinedButton(
                onPressed: widget.canManage ? () => _edit(member) : null,
                child: const Text('Yetkiler'),
              ),
              OutlinedButton(
                onPressed: widget.canManage && member.status == 'active'
                    ? () => widget.onDeactivate(member)
                    : null,
                child: const Text('Pasifleştir'),
              ),
              if (widget.isOwner)
                OutlinedButton(
                  onPressed: widget.canManage && member.status != 'active'
                      ? () => widget.onActivate(member)
                      : null,
                  child: const Text('Aktifleştir'),
                ),
              if (widget.isOwner && widget.onSetPassword != null)
                OutlinedButton(
                  onPressed: widget.canManage ? () => _setPassword(member) : null,
                  child: const Text('Şifre belirle'),
                ),
              OutlinedButton(
                onPressed: widget.canManage && widget.canDelete(member) == null
                    ? () => _confirmDelete(member)
                    : null,
                child: const Text('Sil'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffPasswordDialog extends StatefulWidget {
  const _StaffPasswordDialog();

  @override
  State<_StaffPasswordDialog> createState() => _StaffPasswordDialogState();
}

class _StaffPasswordDialogState extends State<_StaffPasswordDialog> {
  final TextEditingController _password = TextEditingController();
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final error = staffTemporaryPasswordError(_password.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Şifre belirle'),
      content: TextField(
        controller: _password,
        obscureText: _hide,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'Şifre',
          helperText: 'En az 8 karakter.',
          errorText: _error,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _hide = !_hide),
            icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Kaydet')),
      ],
    );
  }
}
