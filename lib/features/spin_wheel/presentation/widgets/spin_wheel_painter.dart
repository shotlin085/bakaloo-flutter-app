import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';

/// Paints the wheel's static geometry only — the ring, the dotted rim, the
/// pie wedges and their spoke dividers. Per-segment icon/label content is
/// laid out as real widgets on top of this (see [SpinWheelDial]) rather than
/// drawn on canvas, so normal text/icon widgets — and their fonts — can be
/// reused instead of hand-shaping glyphs with a [TextPainter].
///
/// Angle convention used everywhere in this file and in [SpinWheelDial]:
/// 0 = straight up (the fixed pointer's position), increasing clockwise.
/// That's a `-pi/2` offset from [Canvas.drawArc]'s own convention (0 = 3
/// o'clock), applied once here via [_upAngleToArcAngle].
class SpinWheelPainter extends CustomPainter {
  const SpinWheelPainter({required this.prizes});

  final List<SpinPrize> prizes;

  static double segmentAngle(int prizeCount) => (2 * math.pi) / prizeCount;

  double _upAngleToArcAngle(double upAngle) => upAngle - math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide / 2;
    final ringThickness = outerRadius * 0.09;
    final segmentRadius = outerRadius - ringThickness;
    final theta = segmentAngle(prizes.length);

    // Outer ring (painted first so the wedges sit on top, leaving a clean
    // ring border around them).
    final ringPaint = Paint()..color = AppColors.spinRingPurple;
    canvas.drawCircle(center, outerRadius, ringPaint);

    // Small light dots studded evenly around the ring, carnival-wheel style.
    const dotCount = 28;
    final dotRadius = ringThickness * 0.22;
    final dotOrbit = outerRadius - ringThickness / 2;
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < dotCount; i++) {
      final a = _upAngleToArcAngle(i * (2 * math.pi / dotCount));
      final dotCenter = center + Offset(math.cos(a), math.sin(a)) * dotOrbit;
      canvas.drawCircle(dotCenter, dotRadius, dotPaint);
    }

    // Pie wedges.
    final wedgeRect = Rect.fromCircle(center: center, radius: segmentRadius);
    for (var i = 0; i < prizes.length; i++) {
      final startUp = i * theta - theta / 2;
      final wedgePaint = Paint()..color = prizes[i].segmentColor;
      canvas.drawArc(
        wedgeRect,
        _upAngleToArcAngle(startUp),
        theta,
        true,
        wedgePaint,
      );
    }

    // White spoke lines between wedges.
    final spokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = math.max(1.5, outerRadius * 0.008)
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < prizes.length; i++) {
      final a = _upAngleToArcAngle(i * theta - theta / 2);
      final edge = center + Offset(math.cos(a), math.sin(a)) * segmentRadius;
      canvas.drawLine(center, edge, spokePaint);
    }

    // Inner rim separating the wedges from the ring.
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = math.max(1.5, outerRadius * 0.01)
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, segmentRadius, rimPaint);
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) =>
      oldDelegate.prizes != prizes;
}
