import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/mall_profile.dart';
import 'mall_panel_kit.dart';

class MallMenuItem {
  const MallMenuItem(this.section, this.label, this.icon);

  final String section;
  final String label;
  final IconData icon;
}

const mallMenuGroups = <String, List<MallMenuItem>>{
  'GENEL': [MallMenuItem('ozet', 'Genel Bakış', Icons.space_dashboard_outlined)],
  'YÖNETİM': [
    MallMenuItem('bilgiler', 'AVM Bilgileri', Icons.apartment_outlined),
    MallMenuItem('katlar', 'Katlar', Icons.layers_outlined),
    MallMenuItem('magazalar', 'Mağazalar', Icons.storefront_outlined),
    MallMenuItem('harita', 'İç Mekan Haritası', Icons.map_outlined),
  ],
  'PAZARLAMA': [
    MallMenuItem('kampanyalar', 'Kampanyalar', Icons.local_offer_outlined),
    MallMenuItem('reklam', 'Reklam', Icons.campaign_outlined),
  ],
  'ANALİZ': [MallMenuItem('istatistikler', 'İstatistikler', Icons.insights_outlined)],
  'EKİP': [MallMenuItem('yetkililer', 'Yetkililer', Icons.groups_outlined)],
};

/// Account actions shared by the sidebar (and mobile drawer) and the header menu.
/// Only the AVM session is signed out; mall switching lives on the header title.
class MallAccountActions {
  const MallAccountActions({required this.onSignOut});

  final VoidCallback onSignOut;
}

class MallSidebar extends StatelessWidget {
  const MallSidebar({
    super.key,
    required this.mall,
    required this.section,
    required this.onSelect,
    this.roleLabel,
    this.account,
    this.actions,
  });

  final MallProfile? mall;
  final String section;
  final String? roleLabel;
  final ValueChanged<String> onSelect;
  final MallAccount? account;
  final MallAccountActions? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 264,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: MallTokens.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  Row(
                    children: [
                      mallLogo(mall?.logoUrl, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mall?.name ?? 'AVM Yönetimi',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            if (mall?.isVerified ?? false)
                              const MallBadge('Doğrulandı', tone: MallTone.success, icon: Icons.verified, dense: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final group in mallMenuGroups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                      child: Text(
                        group.key,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    for (final item in group.value)
                      _SidebarTile(
                        item: item,
                        selected: item.section == section,
                        onTap: () => onSelect(item.section),
                      ),
                  ],
                ],
              ),
            ),
            if (actions != null) _accountBlock(actions!),
          ],
        ),
      ),
    );
  }

  Widget _accountBlock(MallAccountActions actions) {
    final name = account?.name ?? 'AVM Yöneticisi';
    return Container(
      key: const ValueKey('mall-sidebar-account'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MallTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            MallAvatar(account: account),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(roleLabel ?? 'AVM Yöneticisi', style: const TextStyle(fontSize: 12, color: MallTokens.muted)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextButton.icon(
            key: const ValueKey('mall-sidebar-signout'),
            onPressed: actions.onSignOut,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}

class MallAvatar extends StatelessWidget {
  const MallAvatar({super.key, this.account, this.size = 36});

  final MallAccount? account;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: MallTokens.soft,
      child: Text(account?.initials ?? '?',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({required this.item, required this.selected, required this.onTap});

  final MallMenuItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected ? AppColors.primary : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: selected
              ? MallTokens.soft
              : _hover
                  ? const Color(0xFFF7F7FA)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(widget.item.icon, size: 20, color: selected ? AppColors.primary : MallTokens.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: TextStyle(color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MallPanelHeader extends StatelessWidget {
  const MallPanelHeader({
    super.key,
    required this.mall,
    required this.statusLabel,
    required this.statusTone,
    required this.onPreview,
    required this.onSettings,
    this.onMenu,
    this.account,
    this.roleLabel,
    this.actions,
    this.memberships = const [],
    this.onSwitchMall,
  });

  /// Every mall the AVM account manages; the title becomes a selector only
  /// when there is more than one.
  final List<MallMembership> memberships;
  final ValueChanged<String>? onSwitchMall;

  final MallProfile mall;
  final String statusLabel;
  final MallTone statusTone;
  final VoidCallback onPreview;
  final VoidCallback onSettings;
  final VoidCallback? onMenu;
  final MallAccount? account;
  final String? roleLabel;
  final MallAccountActions? actions;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 32, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: MallTokens.border)),
      ),
      child: Row(
        children: [
          if (onMenu != null)
            IconButton(onPressed: onMenu, icon: const Icon(Icons.menu), tooltip: 'Menü'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (mall.locationLabel.isNotEmpty)
                      Text(mall.locationLabel, style: const TextStyle(color: MallTokens.muted, fontSize: 13)),
                    if (mall.isVerified)
                      const MallBadge('Doğrulandı', tone: MallTone.success, icon: Icons.verified, dense: true),
                    MallBadge(statusLabel, tone: statusTone, dense: true),
                  ],
                ),
              ],
            ),
          ),
          if (!compact) ...[
            OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('AVM Önizle'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Ayarlar'),
            ),
            const SizedBox(width: 8),
          ],
          _accountMenu(compact),
        ],
      ),
    );
  }

  Widget _title() {
    final name = Text(
      mall.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    );
    if (memberships.length < 2 || onSwitchMall == null) return name;
    return PopupMenuButton<String>(
      key: const ValueKey('mall-switcher'),
      tooltip: 'AVM seç',
      position: PopupMenuPosition.under,
      onSelected: (mallId) {
        if (mallId != mall.id) onSwitchMall!(mallId);
      },
      itemBuilder: (_) => [
        for (final membership in memberships)
          CheckedPopupMenuItem<String>(
            value: membership.mallId,
            checked: membership.mallId == mall.id,
            child: Text(membership.mall.name),
          ),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: name),
        const Icon(Icons.expand_more),
      ]),
    );
  }

  Widget _accountMenu(bool compact) {
    return PopupMenuButton<String>(
      key: const ValueKey('mall-account-menu'),
      tooltip: 'Hesap',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        switch (value) {
          case 'preview':
            onPreview();
          case 'settings':
            onSettings();
          case 'signout':
            actions?.onSignOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account?.name ?? 'Hesabım',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
              if (roleLabel != null) Text(roleLabel!, style: const TextStyle(fontSize: 12, color: MallTokens.muted)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (compact) ...[
          const PopupMenuItem(value: 'preview', child: Text('AVM Önizle')),
          const PopupMenuItem(value: 'settings', child: Text('Ayarlar')),
        ],
        const PopupMenuItem(
          value: 'signout',
          child: Text('Çıkış Yap', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          MallAvatar(account: account),
          if (!compact) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(account?.name ?? 'Hesabım',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (roleLabel != null)
                    Text(roleLabel!, maxLines: 1, style: const TextStyle(fontSize: 11, color: MallTokens.muted)),
                ],
              ),
            ),
            const Icon(Icons.expand_more, size: 18),
          ],
        ]),
      ),
    );
  }
}
