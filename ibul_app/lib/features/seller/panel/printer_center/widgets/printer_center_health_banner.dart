import 'package:flutter/material.dart';

/// Compact system health summary for Yazıcı Merkezi.
class PrinterCenterHealthBanner extends StatelessWidget {
  const PrinterCenterHealthBanner({
    super.key,
    required this.bridgeHealthy,
    required this.bridgeReachable,
    required this.printSystemEnabled,
    required this.activePrinterCount,
    required this.issueMappingCount,
    this.supabaseReachable = true,
    this.hasNetwork = true,
  });

  final bool bridgeHealthy;
  final bool bridgeReachable;
  final bool printSystemEnabled;
  final int activePrinterCount;
  final int issueMappingCount;
  final bool supabaseReachable;
  final bool hasNetwork;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip(
            label: 'Bridge',
            value: bridgeHealthy
                ? 'Çalışıyor'
                : bridgeReachable
                ? 'Erişilebilir'
                : 'Kapalı',
            tone: bridgeHealthy
                ? _Tone.success
                : bridgeReachable
                ? _Tone.warning
                : _Tone.error,
          ),
          _Chip(
            label: 'İnternet',
            value: hasNetwork ? 'Var' : 'Yok',
            tone: hasNetwork ? _Tone.success : _Tone.warning,
          ),
          _Chip(
            label: 'Supabase',
            value: supabaseReachable ? 'Bağlı' : 'Bağlı değil',
            tone: supabaseReachable ? _Tone.success : _Tone.warning,
          ),
          _Chip(
            label: 'Baskı',
            value: printSystemEnabled ? 'Açık' : 'Kapalı',
            tone: printSystemEnabled ? _Tone.success : _Tone.error,
          ),
          _Chip(
            label: 'Aktif yazıcı',
            value: '$activePrinterCount',
            tone: activePrinterCount > 0 ? _Tone.neutral : _Tone.warning,
          ),
          if (issueMappingCount > 0)
            _Chip(
              label: 'Sorunlu eşleştirme',
              value: '$issueMappingCount',
              tone: _Tone.warning,
            ),
        ],
      ),
    );
  }
}

enum _Tone { success, warning, error, neutral }

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final _Tone tone;

  Color get _color => switch (tone) {
    _Tone.success => const Color(0xFF15803D),
    _Tone.warning => const Color(0xFFB45309),
    _Tone.error => const Color(0xFFDC2626),
    _Tone.neutral => const Color(0xFF4B5563),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.22)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF374151)),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: TextStyle(fontWeight: FontWeight.w700, color: _color),
            ),
          ],
        ),
      ),
    );
  }
}
