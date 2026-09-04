import 'dart:math' as math;

import 'package:flutter/material.dart';

class DiceDisplay extends StatelessWidget {
  const DiceDisplay({
    required this.value,
    required this.rolling,
    super.key,
  });

  final int? value;
  final bool rolling;

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? 1;
    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      scale: rolling ? 1.12 : 1,
      curve: Curves.easeOutBack,
      child: AnimatedRotation(
        duration: const Duration(milliseconds: 140),
        turns: rolling ? 0.04 : 0,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                offset: Offset(0, 5),
                color: Colors.black26,
              ),
            ],
          ),
          child: Center(
            child: Text(
              _face(displayValue),
              style: const TextStyle(fontSize: 48, height: 1),
              semanticsLabel: 'サイコロ $displayValue',
            ),
          ),
        ),
      ),
    );
  }

  String _face(int value) {
    const faces = <String>['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    return faces[(value - 1).clamp(0, 5).toInt()];
  }
}

class EffectBanner extends StatelessWidget {
  const EffectBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(message),
          tween: Tween(begin: 0.72, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: child,
          ),
          child: Material(
            elevation: 12,
            color: Theme.of(context).colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoalCelebrationOverlay extends StatelessWidget {
  const GoalCelebrationOverlay({required this.playerName, super.key});

  final String playerName;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) {
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConfettiPainter(progress: progress),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: progress.clamp(0, 1).toDouble(),
                    child: Transform.scale(
                      scale: 0.65 + progress * 0.35,
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
          child: Material(
            elevation: 18,
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 6),
                  Text(
                    '$playerName ゴール！',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
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

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final center = Offset(size.width / 2, size.height / 2);
    const colors = <Color>[
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];

    for (var index = 0; index < 36; index++) {
      final angle = index * (2 * math.pi / 36);
      final distance = 30 + progress * (70 + (index % 7) * 18);
      final wave = math.sin(progress * math.pi * 2 + index) * 10;
      final offset = Offset(
        center.dx + math.cos(angle) * distance + wave,
        center.dy + math.sin(angle) * distance + progress * progress * 90,
      );
      final alpha = (1 - progress * 0.35).clamp(0, 1).toDouble();
      paint.color = colors[index % colors.length].withValues(alpha: alpha);
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle + progress * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -2, 8, 4),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
