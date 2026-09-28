import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../features/coupon/data/coupon_repository.dart';
import '../../features/coupon/domain/coupon_models.dart';
import '../../features/coupon/widgets/reward_wheel_visuals.dart';
import '../../services/coupon_service.dart';

part 'fortune_wheel_customer_chrome.dart';

class FortuneWheelDialog extends StatefulWidget {
  final VoidCallback? onSpinComplete;

  const FortuneWheelDialog({super.key, this.onSpinComplete});

  @override
  State<FortuneWheelDialog> createState() => _FortuneWheelDialogState();
}

class _FortuneWheelDialogState extends State<FortuneWheelDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentAngle = 0;
  bool _isSpinning = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  RewardWheelSpinResult? _pendingResult;
  RewardWheelSpinResult? _revealed;
  final _repo = CouponRepository();

  /// Equal visual weights hide probability. Server still picks the winner.
  List<RewardWheelSlice> get _slices => [
    for (var i = 0; i < _items.length; i++)
      RewardWheelSlice(
        label: _items[i]['label']?.toString() ?? 'Ödül',
        percent: 1,
        color: RewardWheelVisuals.mysterySliceColor(i),
        isNoPrize: _items[i]['type'] == 'none',
      ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5400),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: const RewardWheelSpinCurve(),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isSpinning = false);
      }
    });
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await _repo.loadWheelForUser();
      if (!mounted) return;
      if (config == null || !config.isActive || config.items.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Hediye çarkı şu anda kapalı.';
        });
        return;
      }
      setState(() {
        _items = [
          for (var i = 0; i < config.items.length; i++)
            {
              'id': config.items[i].id,
              'label': config.items[i].label,
              'bps': config.items[i].probabilityBps,
              'color': RewardWheelVisuals.mysterySliceColor(i),
              'textColor': Colors.white,
              'type': config.items[i].isNoPrize ? 'none' : 'discount',
              'campaignId': config.items[i].campaignId,
            },
        ];
        _loading = false;
      });
    } catch (error, stack) {
      debugPrint('FortuneWheelDialog.load failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spinWheel() async {
    if (_isSpinning || _items.isEmpty || _revealed != null) return;
    setState(() => _isSpinning = true);
    try {
      final result = await _repo.spinWheel(
        'spin-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!result.ok) {
        if (!mounted) return;
        setState(() => _isSpinning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Çark çevrilemedi.')),
        );
        return;
      }
      _pendingResult = result;
      var winnerIndex = _items.indexWhere(
        (item) => item['id']?.toString() == result.itemId,
      );
      if (winnerIndex < 0) {
        winnerIndex = result.sortOrder.clamp(0, _items.length - 1);
      }
      final weights = [for (final _ in _items) 1];
      const pointerAngle = RewardWheelVisuals.startAngle;
      final winnerCenter = RewardWheelVisuals.winnerCenter(
        weights: weights,
        index: winnerIndex,
      );
      final spinCount = 9 + Random().nextInt(4);
      final targetAngle =
          _currentAngle +
          (spinCount * 2 * pi) +
          ((pointerAngle - winnerCenter - (_currentAngle % (2 * pi))) %
              (2 * pi));
      _animation = Tween<double>(begin: _currentAngle, end: targetAngle).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const RewardWheelSpinCurve(),
        ),
      );
      await _controller.forward(from: 0);
      _currentAngle = targetAngle;
      _handlePrize();
    } catch (error, stack) {
      debugPrint('FortuneWheelDialog.spin failed: $error\n$stack');
      if (!mounted) return;
      setState(() => _isSpinning = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _handlePrize() {
    final result = _pendingResult;
    _pendingResult = null;
    if (result == null || _items.isEmpty) return;
    CouponService().notifyListenersSafe();
    if (!mounted) return;
    setState(() => _revealed = result);
    widget.onSpinComplete?.call();
  }

  void _retry() {
    setState(() => _revealed = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null || _items.isEmpty) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading) const CircularProgressIndicator(),
              if (_error != null) Text(_error!),
              if (!_loading && _error == null && _items.isEmpty)
                const Text('Hediye çarkı şu anda kapalı.'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          ),
        ),
      );
    }

    final media = MediaQuery.sizeOf(context);
    final wheelSize = min(media.shortestSide * 0.68, 320.0).clamp(220.0, 320.0);
    final maxCard = min(media.width - 32, 420.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxCard,
          maxHeight: media.height * 0.92,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8F4FF), Color(0xFFFFFFFF)],
                ),
                border: Border.all(color: const Color(0xFFE9D5FF), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Header(onClose: () => Navigator.pop(context)),
                    const SizedBox(height: 6),
                    _WheelStage(
                      size: wheelSize,
                      slices: _slices,
                      animation: _animation,
                      progress: _controller,
                      spinning: _isSpinning,
                      landed: _revealed != null,
                      won: _revealed?.isWin == true,
                      onHubTap: _spinWheel,
                    ),
                    const SizedBox(height: 18),
                    if (_revealed == null)
                      _SpinCta(busy: _isSpinning, onTap: _spinWheel)
                    else
                      _ResultCard(
                        result: _revealed!,
                        onClose: () => Navigator.pop(context),
                        onRetry: _revealed!.isWin ? null : _retry,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
