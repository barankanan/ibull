import 'package:flutter/material.dart';

import '../../theme/ihiz_brand.dart';

class IhizCourierDocStatus {
  const IhizCourierDocStatus({required this.label, required this.status});

  final String label;
  final String status;
}

class IhizCourierMobileAccount extends StatelessWidget {
  const IhizCourierMobileAccount({
    super.key,
    required this.displayName,
    required this.vehicleLabel,
    required this.online,
    required this.onToggleOnline,
    required this.onEditProfile,
    required this.ratingLabel,
    required this.completedLabel,
    required this.monthEarningsLabel,
    required this.earningsCaption,
    required this.onOpenEarnings,
    required this.documents,
    required this.onSupport,
    required this.onSettings,
    required this.onLogout,
    this.loading = false,
  });

  final String? displayName;
  final String? vehicleLabel;
  final bool online;
  final VoidCallback onToggleOnline;
  final VoidCallback onEditProfile;
  final String ratingLabel;
  final String completedLabel;
  final String monthEarningsLabel;
  final String earningsCaption;
  final VoidCallback onOpenEarnings;
  final List<IhizCourierDocStatus> documents;
  final VoidCallback onSupport;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim() ?? '';
    final initials = _initials(name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hesabım',
          style: TextStyle(
            color: IhizBrand.ink,
            fontWeight: FontWeight.w900,
            fontSize: 28,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Profilini yönet, performansını takip et ve hesap ayarlarını düzenle.',
          style: TextStyle(
            color: IhizBrand.inkSoft,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        if (loading)
          const _Skeleton(height: 92)
        else
          _ProfileCard(
            initials: initials,
            name: name.isEmpty ? 'Kurye' : name,
            vehicleLabel: vehicleLabel,
            online: online,
            onToggleOnline: onToggleOnline,
            onEditProfile: onEditProfile,
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metric(
                value: ratingLabel,
                label: 'Puan',
                icon: Icons.star_outline_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                value: completedLabel,
                label: 'Tamamlanan teslimat',
                icon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                value: monthEarningsLabel,
                label: 'Bu ay kazanç',
                icon: Icons.account_balance_wallet_outlined,
                onTap: onOpenEarnings,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          earningsCaption,
          style: const TextStyle(
            color: IhizBrand.inkSoft,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        _DocsCard(documents: documents),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Icons.headset_mic_outlined,
          title: 'Yardım ve Destek',
          subtitle: 'Canlı destek kaydı oluştur',
          onTap: onSupport,
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.settings_outlined,
          title: 'Ayarlar',
          subtitle: 'Bildirim ve hesap tercihleri',
          onTap: onSettings,
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.logout_rounded,
          title: 'Çıkış Yap',
          subtitle: 'Hesabından güvenle çıkış yap',
          danger: true,
          onTap: onLogout,
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'K';
    return parts.map((part) => part.characters.first.toUpperCase()).join();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.initials,
    required this.name,
    required this.vehicleLabel,
    required this.online,
    required this.onToggleOnline,
    required this.onEditProfile,
  });

  final String initials;
  final String name;
  final String? vehicleLabel;
  final bool online;
  final VoidCallback onToggleOnline;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final vehicle = vehicleLabel?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IhizBrand.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: IhizBrand.blue.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: const TextStyle(
                color: IhizBrand.blue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: IhizBrand.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                if (vehicle.isNotEmpty)
                  Text(
                    vehicle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: IhizBrand.inkSoft,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onToggleOnline,
                  borderRadius: BorderRadius.circular(999),
                  child: Text(
                    online ? 'Aktif' : 'Çevrimdışı',
                    style: TextStyle(
                      color: online ? IhizBrand.mint : IhizBrand.inkSoft,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onEditProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: IhizBrand.blue,
              minimumSize: const Size(44, 44),
              side: const BorderSide(color: IhizBrand.line),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Profili Düzenle',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: IhizBrand.line),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: IhizBrand.blue),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: IhizBrand.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: IhizBrand.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocsCard extends StatelessWidget {
  const _DocsCard({required this.documents});

  final List<IhizCourierDocStatus> documents;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IhizBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Belgelerim',
            style: TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          if (documents.isEmpty)
            const Text(
              'Belge kaydı yok.',
              style: TextStyle(
                color: IhizBrand.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (final doc in documents)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.label,
                        style: const TextStyle(
                          color: IhizBrand.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      doc.status,
                      style: const TextStyle(
                        color: IhizBrand.inkSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB42318) : IhizBrand.ink;
    return Material(
      color: danger ? const Color(0xFFFFF6F5) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: danger ? const Color(0xFFF3D0CB) : IhizBrand.line,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: IhizBrand.inkSoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: IhizBrand.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
