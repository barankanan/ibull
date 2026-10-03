import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/mall_ops.dart';
import '../models/mall_profile.dart';
import '../services/mall_management_repository.dart';
import '../services/mall_operations_repository.dart';
import 'mall_management_dialogs.dart';
import 'mall_panel_kit.dart';

class MallTeamView extends StatefulWidget {
  const MallTeamView({super.key, required this.mallId, required this.canManage, required this.operations});

  final String mallId;
  final bool canManage;
  final MallOperationsRepository operations;

  @override
  State<MallTeamView> createState() => _MallTeamViewState();
}

class _MallTeamViewState extends State<MallTeamView> {
  late Future<({List<MallMember> members, List<MallInvitation> invitations})> _team =
      widget.operations.team(widget.mallId);
  String? _error;

  void _reload() => setState(() {
        _team = widget.operations.team(widget.mallId);
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _team,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return MallPage(children: [
          MallPageTitle(
            title: 'Yetkililer',
            subtitle: 'AVM panelini kullanan ekip ve rolleri.',
            actions: [
              if (widget.canManage) MallPrimaryButton(label: 'Yetkili Ekle', icon: Icons.person_add_alt, onPressed: _invite),
            ],
          ),
          if (_error != null) MallInlineError(_error!, onClose: () => setState(() => _error = null)),
          if (snapshot.connectionState != ConnectionState.done)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (snapshot.hasError)
            MallLoadError('Yetkililer yüklenemedi.', onRetry: _reload)
          else ...[
            MallCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < data!.members.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _memberRow(data.members[i]),
                ],
              ]),
            ),
            if (data.invitations.isNotEmpty)
              MallCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const MallCardTitle('Bekleyen davetler'),
                    for (final invite in data.invitations)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mail_outline),
                        title: Text(invite.email),
                        trailing: MallBadge(mallRoleLabel(invite.role)),
                      ),
                  ],
                ),
              ),
          ],
        ]);
      },
    );
  }

  Widget _memberRow(MallMember member) {
    final editable = widget.canManage && !member.isSelf;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                backgroundColor: MallTokens.soft,
                child: Text(
                  member.displayName.isEmpty ? '?' : member.displayName.characters.first.toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.isSelf ? '${member.displayName} (siz)' : member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (member.email != null)
                      Text(member.email!, style: const TextStyle(color: MallTokens.muted, fontSize: 13)),
                  ],
                ),
              ),
            ]),
          ),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            MallBadge(mallRoleLabel(member.role), tone: MallTone.primary),
            MallBadge(member.statusLabel, tone: member.status == 'active' ? MallTone.success : MallTone.warning),
            if (editable)
              PopupMenuButton<String>(
                tooltip: 'Yetkili işlemleri',
                onSelected: (value) => _change(member, value),
                itemBuilder: (_) => [
                  for (final role in mallRoles)
                    if (role != member.role) PopupMenuItem(value: 'role:$role', child: Text('Rol: ${mallRoleLabel(role)}')),
                  const PopupMenuDivider(),
                  if (member.status == 'suspended')
                    const PopupMenuItem(value: 'status:active', child: Text('Yeniden etkinleştir'))
                  else
                    const PopupMenuItem(value: 'status:suspended', child: Text('Askıya al')),
                  const PopupMenuItem(value: 'status:removed', child: Text('Ekipten çıkar')),
                ],
              ),
          ]),
        ],
      ),
    );
  }

  Future<void> _change(MallMember member, String action) async {
    final parts = action.split(':');
    final role = parts[0] == 'role' ? parts[1] : member.role;
    final status = parts[0] == 'status' ? parts[1] : member.status;
    if (status == 'removed') {
      final ok = await confirmMallAction(
        context,
        title: 'Ekipten çıkar',
        message: '${member.displayName} AVM panel erişimini kaybedecek.',
        confirmLabel: 'Çıkar',
      );
      if (!ok) return;
    }
    try {
      await widget.operations.updateMember(mallId: widget.mallId, userId: member.userId, role: role, status: status);
      _reload();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    }
  }

  Future<void> _invite() async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _InviteDialog(mallId: widget.mallId, operations: widget.operations),
    );
    if (message == null) return;
    _reload();
    if (mounted) showMallSnack(context, message);
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.mallId, required this.operations});

  final String mallId;
  final MallOperationsRepository operations;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final _email = TextEditingController();
  var _role = 'mall_store_manager';
  var _busy = false;
  String? _emailError;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MallFormDialog(
      title: 'Yetkili Ekle',
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        MallPrimaryButton(label: _busy ? 'Gönderiliyor…' : 'Davet Gönder', onPressed: _busy ? null : _send),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[MallInlineError(_error!), const SizedBox(height: 16)],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: mallInput('E-posta *', hint: 'ornek@firma.com', error: _emailError),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: mallInput('Rol'),
            items: [for (final role in mallRoles) DropdownMenuItem(value: role, child: Text(mallRoleLabel(role)))],
            onChanged: (value) => setState(() => _role = value ?? _role),
          ),
          const SizedBox(height: 8),
          const Text('Davet edilen kişi daveti kabul edince panele erişir.',
              style: TextStyle(color: MallTokens.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    setState(() => _emailError = _emailPattern.hasMatch(email) ? null : 'Geçerli bir e-posta girin.');
    if (_emailError != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await widget.operations.invite(mallId: widget.mallId, email: email, role: _role);
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
