part of 'fortune_wheel_dialog.dart';

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 4, left: 36, right: 36),
          child: Column(
            children: [
              Text(
                'Şansını Dene',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3B0764),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Sürpriz ödüller seni bekliyor.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Material(
            color: const Color(0xFFF3E8FF),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Color(0xFF4C1D95),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WheelStage extends StatelessWidget {
  const _WheelStage({
    required this.size,
    required this.slices,
    required this.animation,
    required this.progress,
    required this.spinning,
    required this.landed,
    required this.won,
    required this.onHubTap,
  });

  final double size;
  final List<RewardWheelSlice> slices;
  final Animation<double> animation;
  final Animation<double> progress;
  final bool spinning;
  final bool landed;
  final bool won;
  final VoidCallback onHubTap;

  @override
  Widget build(BuildContext context) {
    final discSize = size - RewardWheelVisuals.ringWidth * 2;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, progress]),
      builder: (context, _) {
        final wobble = spinning
            ? sin(animation.value * 16) * (1 - progress.value) * 0.16
            : 0.0;
        final glow = landed && won ? 0.55 : (spinning ? 0.32 : 0.22);
        return SizedBox(
          width: size + 8,
          height: size + 18,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFF8E7A0),
                      Color(0xFFC4B5FD),
                      Color(0xFFF5D78A),
                      Color(0xFFDDD6FE),
                      Color(0xFFF8E7A0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: glow),
                      blurRadius: landed && won ? 36 : 26,
                      spreadRadius: landed && won ? 3 : 1,
                    ),
                    BoxShadow(
                      color: RewardWheelVisuals.gold.withValues(alpha: 0.28),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1E1B4B),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: discSize,
                        height: discSize,
                        child: ClipOval(
                          child: Transform.rotate(
                            angle: animation.value,
                            child: CustomPaint(
                              painter: RewardWheelSlicePainter(
                                slices: slices,
                                showLabels: false,
                                mystery: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  size: Size.square(size),
                  painter: RewardWheelRingDotsPainter(count: 20, premium: true),
                ),
              ),
              Positioned(
                top: 0,
                child: Transform.rotate(
                  angle: wobble,
                  child: SizedBox(
                    width: 32,
                    height: 38,
                    child: CustomPaint(
                      painter: RewardWheelPointerPainter(premium: true),
                    ),
                  ),
                ),
              ),
              RewardWheelHubButton(
                size: size * 0.26,
                label: 'ÇEVİR',
                premium: true,
                busy: spinning,
                onTap: onHubTap,
              ),
              if (landed && won)
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.square(size),
                    painter: _WinSparklePainter(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SpinCta extends StatelessWidget {
  const _SpinCta({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFC4B5FD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFF5D78A), width: 1.4),
            ),
          ),
          child: Text(
            busy ? 'Çevriliyor…' : 'Çevir',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onClose,
    this.onRetry,
  });

  final RewardWheelSpinResult result;
  final VoidCallback onClose;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final win = result.isWin;
    final label = (result.label ?? '').trim();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: win ? const Color(0xFFF5F3FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: win ? const Color(0xFFF5D78A) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          children: [
            Icon(
              win ? Icons.auto_awesome : Icons.replay_rounded,
              color: win ? const Color(0xFFC9A227) : const Color(0xFF6B7280),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              win ? 'Tebrikler!' : 'Bu kez olmadı, tekrar dene',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF3B0764),
              ),
            ),
            if (win) ...[
              const SizedBox(height: 6),
              Text(
                label.isEmpty ? 'Ödül kazandın.' : '$label kazandın',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kupon hesabına tanımlandı.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (onRetry != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Tekrar dene'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: onClose,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Tamam'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WinSparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final paint = Paint()
      ..color = RewardWheelVisuals.gold.withValues(alpha: 0.85);
    const spots = [0.12, 0.28, 0.41, 0.63, 0.77, 0.91];
    for (var i = 0; i < spots.length; i++) {
      final angle = RewardWheelVisuals.startAngle + spots[i] * 2 * pi;
      final r = radius * (i.isEven ? 0.92 : 1.02);
      canvas.drawCircle(
        Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)),
        i.isEven ? 2.2 : 1.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
