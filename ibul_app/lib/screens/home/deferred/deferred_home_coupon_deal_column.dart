import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/home_data_diagnostics.dart';
import '../../../widgets/skeleton_loading.dart';
import '../home_section_error.dart';
import '../sections/home_section_coupon_deal_column.dart'
    deferred as coupon_deal_section;

/// Lazy coupon/deal column — separate deferred chunk from home core.
class DeferredHomeCouponDealColumn extends StatefulWidget {
  const DeferredHomeCouponDealColumn({
    super.key,
    this.delay = Duration.zero,
    this.suppressSkeleton = false,
    this.maxSkeletonDuration = const Duration(seconds: 4),
  });

  final Duration delay;
  final bool suppressSkeleton;
  final Duration maxSkeletonDuration;

  @override
  State<DeferredHomeCouponDealColumn> createState() =>
      _DeferredHomeCouponDealColumnState();
}

class _DeferredHomeCouponDealColumnState
    extends State<DeferredHomeCouponDealColumn> {
  Future<void>? _loadFuture;
  bool _scheduled = false;
  bool _skeletonTimedOut = false;
  Timer? _skeletonTimer;

  @override
  void initState() {
    super.initState();
    _skeletonTimer = Timer(widget.maxSkeletonDuration, () {
      if (!mounted || _skeletonTimedOut) return;
      setState(() => _skeletonTimedOut = true);
      HomeSkeletonDiagnostics.timeout(source: 'coupon_deal');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoad());
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    super.dispose();
  }

  Future<void> _scheduleLoad() async {
    if (_scheduled) return;
    _scheduled = true;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (!mounted) return;
    setState(() {
      _loadFuture = coupon_deal_section.loadLibrary();
    });
  }

  void _retry() {
    setState(() {
      _loadFuture = coupon_deal_section.loadLibrary();
    });
  }

  bool get _shouldShowSkeleton {
    if (widget.suppressSkeleton || _skeletonTimedOut) return false;
    return true;
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
        SkeletonLoading(width: double.infinity, height: 108, borderRadius: 16),
      ],
    );

    final future = _loadFuture;
    if (future == null) {
      if (!_shouldShowSkeleton) {
        return const SizedBox.shrink();
      }
      HomeSkeletonDiagnostics.show(
        source: 'coupon_deal',
        reason: 'library_pending',
      );
      return placeholder;
    }

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          if (!_shouldShowSkeleton) {
            return const SizedBox.shrink();
          }
          HomeSkeletonDiagnostics.show(
            source: 'coupon_deal',
            reason: 'library_loading',
          );
          return placeholder;
        }
        if (snapshot.hasError) {
          HomeSectionDiagnostics.state(section: 'coupon_deal', state: 'error');
          return HomeSectionError(
            message: 'Kupon alanı yüklenemedi.',
            onRetry: _retry,
          );
        }
        HomeSkeletonDiagnostics.hide(
          source: 'coupon_deal',
          reason: 'library_loaded',
        );
        HomeSectionDiagnostics.state(section: 'coupon_deal', state: 'content');
        return coupon_deal_section.buildHomeCouponDealColumn();
      },
    );
  }
}
