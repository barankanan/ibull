import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/ibul_router.dart';
import '../../../services/ihiz_public_tracking_service.dart';
import '../../../widgets/common/video_player_widget.dart';
import '../delivery/ihiz_public_tracking.dart';
import '../delivery/ihiz_route_paths.dart';
import '../shell/ihiz_footer.dart';
import '../shell/ihiz_header.dart';
import '../shell/ihiz_subpage_scaffold.dart';
import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';
import 'ihiz_tracking_map.dart';
import 'ihiz_tracking_timeline.dart';

class IhizTrackingPage extends StatefulWidget {
  const IhizTrackingPage({
    super.key,
    required this.trackingCode,
    this.service,
  });

  final String trackingCode;
  final IhizPublicTrackingService? service;

  @override
  State<IhizTrackingPage> createState() => _IhizTrackingPageState();
}

class _IhizTrackingPageState extends State<IhizTrackingPage> {
  late final IhizPublicTrackingService _service =
      widget.service ?? IhizPublicTrackingService.instance;
  IhizPublicTracking? _tracking;
  bool _loading = true;
  bool _liveConnectionLost = false;
  RealtimeChannel? _channel;
  Timer? _liveRefresh;

  String get _code =>
      IhizRoutePaths.normalizeTrackingCode(widget.trackingCode);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _liveRefresh?.cancel();
    unawaited(_service.detach(_channel));
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _service.fetch(_code);
    if (!mounted) return;
    setState(() {
      _tracking = result;
      _loading = false;
    });
    _bindRealtime(result);
  }

  void _bindRealtime(IhizPublicTracking result) {
    _liveRefresh?.cancel();
    unawaited(_service.detach(_channel));
    if (!result.found) return;

    _channel = _service.subscribe(_code, () {
      if (!mounted) return;
      unawaited(_refreshQuietly());
    });
    _channel?.subscribe((status, error) {
      if (!mounted) return;
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        setState(() => _liveConnectionLost = true);
      }
    });

    if (result.isLive) {
      _liveRefresh = Timer.periodic(const Duration(seconds: 12), (_) {
        unawaited(_refreshQuietly());
      });
    }
  }

  Future<void> _refreshQuietly() async {
    final result = await _service.fetch(_code);
    if (!mounted) return;
    setState(() {
      _tracking = result;
      _liveConnectionLost = false;
    });
  }

  void _goLanding() {
    IbulRouter.go(context, IhizRoutePaths.landing);
  }

  @override
  Widget build(BuildContext context) {
    return IhizSubpageScaffold(
      header: IhizHeader(
        onHome: _goLanding,
        onHowItWorks: _goLanding,
        onTracking: _goLanding,
        onBusinessJoin: _goLanding,
        onLogin: _goLanding,
        onCourierApply: _goLanding,
      ),
      body: IhizSectionPadding(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: IhizBrand.contentMaxWidth),
            child: _buildBody(),
          ),
        ),
      ),
      footer: IhizFooter(
        onHome: _goLanding,
        onHowItWorks: _goLanding,
        onCourierApply: _goLanding,
        onBusinessJoin: _goLanding,
        onTracking: _goLanding,
        onReturnToIbul: () {
          IbulRouter.go(context, '/home');
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final tracking = _tracking;
    if (tracking == null || !tracking.found) {
      return _NotFoundCard(message: tracking?.friendlyMessage);
    }
    return _TrackingContent(
      tracking: tracking,
      connectionLost: _liveConnectionLost,
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: tracking.trackingCode ?? _code));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teslimat kodu kopyalandı.')),
        );
      },
    );
  }
}

class _NotFoundCard extends StatelessWidget {
  const _NotFoundCard({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: IhizBrand.line),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, color: IhizBrand.blue, size: 36),
          const SizedBox(height: 12),
          Text(
            message ?? 'Teslimat bulunamadı.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({
    required this.tracking,
    required this.connectionLost,
    required this.onCopy,
  });

  final IhizPublicTracking tracking;
  final bool connectionLost;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final mobile = IhizBrand.isMobile(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(tracking: tracking, onCopy: onCopy),
        const SizedBox(height: 16),
        if (tracking.isLive && tracking.live != null) ...[
          IhizTrackingMap(
            live: tracking.live!,
            connectionLost: connectionLost,
          ),
          const SizedBox(height: 16),
        ],
        IhizTrackingTimeline(tracking: tracking),
        if (tracking.hasVideo) ...[
          const SizedBox(height: 16),
          _VideoCard(url: tracking.packageMediaUrl!),
        ],
        const SizedBox(height: 16),
        _DetailsCard(tracking: tracking, compact: mobile),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.tracking, required this.onCopy});

  final IhizPublicTracking tracking;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: IhizBrand.line),
        boxShadow: IhizBrand.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TESLİMAT TAKİBİ',
            style: TextStyle(
              color: IhizBrand.blue,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Teslimat Kodu: ${tracking.trackingCode ?? '-'}',
            style: const TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Durum: ${tracking.statusLabel}',
            style: const TextStyle(
              color: IhizBrand.inkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tracking.friendlyMessage,
            style: const TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Kodu kopyala'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IhizBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paketleme Videosu',
            style: TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Paketiniz bu aşamada hazırlanmıştır.',
            style: TextStyle(
              color: IhizBrand.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: VideoPlayerWidget(
                videoUrl: url,
                initializeOnTap: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.tracking, required this.compact});

  final IhizPublicTracking tracking;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if ((tracking.senderName ?? '').trim().isNotEmpty)
        ('Gönderici', tracking.senderName!.trim()),
      if ((tracking.pickupLabel ?? '').trim().isNotEmpty)
        ('Nereden', tracking.pickupLabel!.trim()),
      if ((tracking.dropoffLabel ?? '').trim().isNotEmpty)
        ('Nereye', tracking.dropoffLabel!.trim()),
      if ((tracking.packageSize ?? '').trim().isNotEmpty)
        ('Paket tipi', tracking.packageSize!.trim()),
      if (tracking.packageWeight != null)
        ('Ağırlık', '${tracking.packageWeight} kg'),
      if ((tracking.notes ?? '').trim().isNotEmpty)
        ('Teslimat notu', tracking.notes!.trim()),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IhizBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teslimat detayları',
            style: TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: compact ? 96 : 130,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        color: IhizBrand.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        color: IhizBrand.ink,
                        fontWeight: FontWeight.w700,
                      ),
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
