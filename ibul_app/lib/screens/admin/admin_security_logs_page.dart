import 'package:flutter/material.dart';

import '../../models/admin_permissions.dart';
import '../../services/admin_service.dart';

class AdminSecurityLogsPage extends StatefulWidget {
  const AdminSecurityLogsPage({super.key});

  @override
  State<AdminSecurityLogsPage> createState() => _AdminSecurityLogsPageState();
}

class _AdminSecurityLogsPageState extends State<AdminSecurityLogsPage> {
  final AdminService _adminService = AdminService();

  late Future<AdminSecuritySnapshot> _snapshotFuture;
  String _severityFilter = 'Tümü';
  bool _showOnlyRiskyAdmins = false;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _adminService.getSecuritySnapshot();
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotFuture = _adminService.getSecuritySnapshot();
    });
    await _snapshotFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminSecuritySnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.gpp_bad_outlined,
                        color: Color(0xFFDC2626),
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Güvenlik verileri yüklenemedi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('Güvenlik görünürlüğü bulunamadı.'));
        }

        final incidents = data.incidents.where((incident) {
          switch (_severityFilter) {
            case 'Kritik':
              return incident.severity == 'critical';
            case 'Uyarı':
              return incident.severity == 'warning';
            case 'Bilgi':
              return incident.severity == 'info';
            default:
              return true;
          }
        }).toList();

        final adminPosture = data.adminPosture.where((admin) {
          if (_showOnlyRiskyAdmins && !admin.isOverexposed) {
            return false;
          }
          return true;
        }).toList();

        final openRequirements = data.requirements
            .where((item) => item.status != 'healthy')
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1220;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildHeroSection(data, isWide: isWide),
                  const SizedBox(height: 20),
                  _buildSummaryStrip(data),
                  const SizedBox(height: 20),
                  _buildSchemaBanner(data.schemaMessage),
                  const SizedBox(height: 20),
                  _buildRequirementSection(data),
                  const SizedBox(height: 20),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: _buildIncidentTimeline(incidents),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 4,
                          child: _buildRiskPanel(data, openRequirements),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildRiskPanel(data, openRequirements),
                        const SizedBox(height: 20),
                        _buildIncidentTimeline(incidents),
                      ],
                    ),
                  const SizedBox(height: 20),
                  _buildAdminPostureSection(adminPosture),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroSection(AdminSecuritySnapshot data, {required bool isWide}) {
    final statusColor = _statusColor(
      data.postureLabel == 'Stabil'
          ? 'healthy'
          : data.postureLabel == 'İzlemede'
          ? 'warning'
          : 'critical',
    );

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildHeroCopy(data, statusColor)),
                const SizedBox(width: 20),
                SizedBox(width: 340, child: _buildHeroGaugeCard(data)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCopy(data, statusColor),
                const SizedBox(height: 20),
                _buildHeroGaugeCard(data),
              ],
            ),
    );
  }

  Widget _buildHeroCopy(AdminSecuritySnapshot data, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_moon_outlined, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Admin güvenlik komuta alanı',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Log, yetki ve operasyonel güvenlik gereksinimleri aynı panelde.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          data.postureNote,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _heroPill('Aktif admin', '${data.activeAdminCount} hesap'),
            _heroPill('Kritik olay', '${data.criticalIncidentCount7d} / 7 gün'),
            _heroPill(
              'Ayrıcalık inceleme',
              '${data.overexposedAdminCount} hesap',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.26)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radar_rounded, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Text(
                data.postureLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroGaugeCard(AdminSecuritySnapshot data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hazırlık Skoru',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gereksinim karşılanma oranı ve veri görünürlüğü birlikte ölçülür.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _progressMetric(
            'Gereksinim uygunluğu',
            data.readinessPercent,
            const Color(0xFF22C55E),
          ),
          const SizedBox(height: 16),
          _progressMetric(
            'Log görünürlüğü',
            data.visibilityPercent,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _heroMiniCard(
                  'Güvenlik sahibi',
                  '${data.securityOwnerCount}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _heroMiniCard(
                  'Yetki sahibi',
                  '${data.permissionManagerCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(AdminSecuritySnapshot data) {
    final items = [
      (
        'Güvenlik erişimi',
        '${data.securityOwnerCount}',
        Icons.shield_outlined,
        const Color(0xFF2563EB),
      ),
      (
        'Yetki yöneticisi',
        '${data.permissionManagerCount}',
        Icons.admin_panel_settings_outlined,
        const Color(0xFF7C3AED),
      ),
      (
        'Riskli hesap',
        '${data.overexposedAdminCount}',
        Icons.priority_high_rounded,
        const Color(0xFFDC2626),
      ),
      (
        'Görünürlük',
        '%${data.visibilityPercent.round()}',
        Icons.visibility_outlined,
        const Color(0xFF0F766E),
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items.map((item) {
        return SizedBox(
          width: 240,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: item.$4.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.$3, color: item.$4),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSchemaBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB45309)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF92400E), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementSection(AdminSecuritySnapshot data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gereksinim Matrisi',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bu alan güvenlik operasyonunun tasarım gereksinimlerini görünür kılar ve eksikleri eyleme dönüştürür.',
          style: TextStyle(color: Colors.grey.shade600, height: 1.45),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: data.requirements.map(_buildRequirementCard).toList(),
        ),
      ],
    );
  }

  Widget _buildRequirementCard(AdminSecurityRequirement requirement) {
    final accent = _statusColor(requirement.status);

    return SizedBox(
      width: 330,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_statusIcon(requirement.status), color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requirement.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        requirement.owner,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(requirement.status),
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              requirement.description,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: requirement.completionPercent / 100,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              requirement.evidenceLabel,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              requirement.actionLabel,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskPanel(
    AdminSecuritySnapshot data,
    List<AdminSecurityRequirement> openRequirements,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.radar_rounded, color: Color(0xFF0F172A)),
              SizedBox(width: 8),
              Text(
                'Risk ve Operasyon',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.postureNote,
            style: TextStyle(color: Colors.grey.shade700, height: 1.5),
          ),
          const SizedBox(height: 18),
          _signalRow(
            'Hazırlık',
            '%${data.readinessPercent.round()}',
            data.readinessPercent >= 80 ? 'healthy' : 'warning',
          ),
          _signalRow(
            'Kritik olay',
            '${data.criticalIncidentCount7d} / 7 gün',
            data.criticalIncidentCount7d == 0 ? 'healthy' : 'critical',
          ),
          _signalRow(
            'Ayrıcalık yoğunlaşması',
            '${data.overexposedAdminCount} hesap',
            data.overexposedAdminCount == 0 ? 'healthy' : 'warning',
          ),
          const SizedBox(height: 18),
          if (openRequirements.isNotEmpty) ...[
            const Text(
              'Açık Gereksinimler',
              style: TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...openRequirements.map((item) {
              final accent = _statusColor(item.status);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.actionLabel,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Tüm ana gereksinimler yeşil durumda. Düzenli gözden geçirme yeterli.',
                style: TextStyle(color: Color(0xFF166534), height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncidentTimeline(List<AdminSecurityIncident> incidents) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Denetim Akışı',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Yenile'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Tümü', 'Kritik', 'Uyarı', 'Bilgi'].map((label) {
              final selected = _severityFilter == label;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _severityFilter = label;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (incidents.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Bu filtre için olay bulunamadı.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...incidents.map((incident) {
              final accent = _severityColor(incident.severity);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _severityIcon(incident.severity),
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            incident.title,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            incident.subtitle,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _tag(
                                incident.source,
                                background: Colors.white,
                                foreground: Colors.grey.shade800,
                              ),
                              _tag(
                                _severityLabel(incident.severity),
                                background: accent.withValues(alpha: 0.14),
                                foreground: accent,
                              ),
                              _tag(
                                _formatDateTime(incident.occurredAt),
                                background: Colors.white,
                                foreground: Colors.grey.shade700,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdminPostureSection(List<AdminSecurityAdminPosture> admins) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Admin Erişim Duruşu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              FilterChip(
                selected: _showOnlyRiskyAdmins,
                label: const Text('Sadece riskli hesaplar'),
                onSelected: (value) {
                  setState(() {
                    _showOnlyRiskyAdmins = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rol, modül kapsamı ve son güncelleme bilgileri güvenlik denetimi için özetlenir.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.45),
          ),
          const SizedBox(height: 16),
          if (admins.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Gösterilecek admin hesabı bulunamadı.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...admins.map((admin) {
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: admin.isOverexposed
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: admin.isOverexposed
                        ? const Color(0xFFFECACA)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF111827),
                          child: Text(
                            admin.name.isNotEmpty
                                ? admin.name.characters.first.toUpperCase()
                                : 'A',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                admin.name,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                admin.email,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: admin.isOverexposed
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            admin.isOverexposed ? 'İnceleme gerekli' : 'Normal',
                            style: TextStyle(
                              color: admin.isOverexposed
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _detailPill('Rol', admin.roleLabel),
                        _detailPill('Modül', '${admin.moduleCount} erişim'),
                        _detailPill(
                          'Güncelleme',
                          admin.lastUpdated == null
                              ? 'Bilinmiyor'
                              : _formatRelative(admin.lastUpdated!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: admin.modules.isEmpty
                          ? [
                              _tag(
                                'Tanımlı modül yok',
                                background: const Color(0xFFF3F4F6),
                                foreground: const Color(0xFF6B7280),
                              ),
                            ]
                          : admin.modules.map((module) {
                              final label =
                                  AdminModules.labels[module] ?? module;
                              final isCritical =
                                  module == AdminModules.securityLogs ||
                                  module == AdminModules.permissionSystem;
                              return _tag(
                                label,
                                background: isCritical
                                    ? const Color(0xFF111827)
                                    : const Color(0xFFE5E7EB),
                                foreground: isCritical
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              );
                            }).toList(),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _progressMetric(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
            ),
            const Spacer(),
            Text(
              '%${value.round()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: value / 100,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _heroMiniCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signalRow(String label, String value, String status) {
    final color = _statusColor(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _detailPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _heroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'healthy':
        return const Color(0xFF16A34A);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'critical':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF2563EB);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'healthy':
        return Icons.verified_user_outlined;
      case 'warning':
        return Icons.rule_folder_outlined;
      case 'critical':
        return Icons.gpp_bad_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'healthy':
        return 'Hazır';
      case 'warning':
        return 'Takipte';
      case 'critical':
        return 'Eksik';
      default:
        return 'Bilgi';
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'warning':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF2563EB);
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error_outline_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'critical':
        return 'Kritik';
      case 'warning':
        return 'Uyarı';
      default:
        return 'Bilgi';
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _formatRelative(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'şimdi';
    if (difference.inMinutes < 60) return '${difference.inMinutes} dk önce';
    if (difference.inHours < 24) return '${difference.inHours} sa önce';
    if (difference.inDays < 30) return '${difference.inDays} gün önce';
    return _formatDateTime(value);
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
