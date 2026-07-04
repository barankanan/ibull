import 'package:flutter/material.dart';

import '../../../widgets/skeleton_loading.dart';
import '../home_section_error.dart';
import '../sections/home_section_coupon_deal_column.dart'
    deferred as coupon_deal_section;

/// Lazy coupon/deal column — separate deferred chunk from home core.
class DeferredHomeCouponDealColumn extends StatefulWidget {
  const DeferredHomeCouponDealColumn({super.key, this.delay = Duration.zero});

  final Duration delay;

  @override
  State<DeferredHomeCouponDealColumn> createState() =>
      _DeferredHomeCouponDealColumnState();
}

class _DeferredHomeCouponDealColumnState
    extends State<DeferredHomeCouponDealColumn> {
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
    setState(() => _loadFuture = coupon_deal_section.loadLibrary());
  }

  void _retry() {
    setState(() => _loadFuture = coupon_deal_section.loadLibrary());
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = Column(
      children: [
        Expanded(
          child: SkeletonLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 16,
          ),
        ),
        SizedBox(height: 12),
        SkeletonLoading(width: double.infinity, height: 150, borderRadius: 16),
      ],
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
            message: 'Kupon alanı yüklenemedi.',
            onRetry: _retry,
          );
        }
        return coupon_deal_section.buildHomeCouponDealColumn();
      },
    );
  }
}
