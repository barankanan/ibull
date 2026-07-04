import 'package:flutter/material.dart';

import '../../../core/web_perf_trace.dart';
import '../../../widgets/skeleton_loading.dart';
import '../home_section_error.dart';
import '../sections/home_section_sponsored.dart' deferred as sponsored_section;

/// Lazy sponsored rails — loads [sponsored_section] before building widgets.
class DeferredHomeSponsoredSection extends StatefulWidget {
  const DeferredHomeSponsoredSection({
    super.key,
    this.delay = Duration.zero,
  });

  final Duration delay;

  @override
  State<DeferredHomeSponsoredSection> createState() =>
      _DeferredHomeSponsoredSectionState();
}

class _DeferredHomeSponsoredSectionState extends State<DeferredHomeSponsoredSection> {
  Future<void>? _loadFuture;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoad());
  }

  Future<void> _scheduleLoad() async {
    if (_scheduled) return;
    _scheduled = true;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (!mounted) return;
    setState(() => _loadFuture = _loadLibrary());
  }

  Future<void> _loadLibrary() async {
    await sponsored_section.loadLibrary();
    WebPerfTrace.instance.mark(WebPerfTraceStage.deferredCampaignLoaded);
  }

  void _retry() {
    setState(() => _loadFuture = _loadLibrary());
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SkeletonLoading(
        width: double.infinity,
        height: 120,
        borderRadius: 12,
      ),
    );

    final future = _loadFuture;
    if (future == null) return placeholder;

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder;
        }
        if (snapshot.hasError) {
          return HomeSectionError(
            message: 'Sponsorlu bölüm şu an yüklenemedi.',
            onRetry: _retry,
          );
        }
        return sponsored_section.buildHomeSponsoredSection();
      },
    );
  }
}
