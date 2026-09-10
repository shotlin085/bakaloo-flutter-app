import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/presentation/widgets/spin_wheel_painter.dart';

/// The wheel + fixed pointer + fixed center hub button.
///
/// Owns the spin animation itself (imperative [spinToIndex] via
/// [GlobalKey]) rather than being driven by provider state, because the
/// rotation must accumulate across spins (never reset to 0) for the motion
/// to look continuous — that's animation-controller state, not app state.
class SpinWheelDial extends StatefulWidget {
  const SpinWheelDial({
    required this.prizes,
    required this.size,
    this.onHubTap,
    this.spinning = false,
    super.key,
  });

  final List<SpinPrize> prizes;
  final double size;
  final VoidCallback? onHubTap;
  final bool spinning;

  @override
  State<SpinWheelDial> createState() => SpinWheelDialState();
}

class SpinWheelDialState extends State<SpinWheelDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double> _rotation = const AlwaysStoppedAnimation<double>(0);
  double _currentRotation = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Spins the wheel forward (never backward — always several extra full
  /// turns) so [index]'s wedge ends up centered under the fixed top
  /// pointer, then resolves once the wheel has fully stopped.
  Future<void> spinToIndex(int index) async {
    final theta = SpinWheelPainter.segmentAngle(widget.prizes.length);
    final twoPi = 2 * math.pi;
    final desiredMod = ((-index * theta) % twoPi + twoPi) % twoPi;
    final currentMod = ((_currentRotation % twoPi) + twoPi) % twoPi;
    final delta = ((desiredMod - currentMod) % twoPi + twoPi) % twoPi;
    // A little per-spin randomness in the extra full turns (5-7) so
    // consecutive spins don't all feel identically timed.
    final extraTurns = 5 + (index % 3);
    final target = _currentRotation + extraTurns * twoPi + delta;

    _rotation = Tween<double>(begin: _currentRotation, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _controller
      ..duration = const Duration(milliseconds: 4600)
      ..reset();
    await _controller.forward();
    _currentRotation = target;
  }

  @override
  Widget build(BuildContext context) {
    final theta = SpinWheelPainter.segmentAngle(widget.prizes.length);
    final hubSize = widget.size * 0.26;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          AnimatedBuilder(
            animation: _rotation,
            builder: (context, child) {
              return Transform.rotate(angle: _rotation.value, child: child);
            },
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: SpinWheelPainter(prizes: widget.prizes),
                  ),
                  for (var i = 0; i < widget.prizes.length; i++)
                    _SegmentContent(
                      prize: widget.prizes[i],
                      angle: i * theta,
                      wheelSize: widget.size,
                    ),
                ],
              ),
            ),
          ),
          // Fixed pointer — does not rotate with the wheel.
          Positioned(
            top: -widget.size * 0.035,
            child: _PointerTriangle(size: widget.size * 0.11),
          ),
          // Fixed center hub — does not rotate with the wheel.
          _SpinHubButton(
            size: hubSize,
            enabled: !widget.spinning,
            onTap: widget.onHubTap,
          ),
        ],
      ),
    );
  }
}

class _SegmentContent extends StatelessWidget {
  const _SegmentContent({
    required this.prize,
    required this.angle,
    required this.wheelSize,
  });

  final SpinPrize prize;
  final double angle;
  final double wheelSize;

  @override
  Widget build(BuildContext context) {
    final midRadius = wheelSize * 0.335;
    final dx = math.sin(angle) * midRadius;
    final dy = -math.cos(angle) * midRadius;
    final contentWidth = wheelSize * 0.24;
    // Bottom-half wedges would otherwise render upside down (radial angle
    // > 90° from top) — flip them back a half turn so every label stays
    // readable without tilting your head past vertical.
    final normalizedAngle = angle % (2 * math.pi);
    final contentRotation = (normalizedAngle > math.pi / 2 &&
            normalizedAngle < math.pi * 1.5)
        ? angle + math.pi
        : angle;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: contentRotation,
        child: SizedBox(
          width: contentWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                prize.icon,
                size: (wheelSize * 0.052).clamp(14.0, 22.0),
                color: AppColors.spinSegmentIcon,
              ),
              Gap(2.h),
              Text(
                prize.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  fontSize: (wheelSize * 0.026).clamp(8.5, 11.0),
                  color: AppColors.spinSegmentIcon,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointerTriangle extends StatelessWidget {
  const _PointerTriangle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.9),
      painter: _PointerPainter(),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = AppColors.orderVioletDark);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpinHubButton extends StatelessWidget {
  const _SpinHubButton({
    required this.size,
    required this.enabled,
    this.onTap,
  });

  final double size;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size * 0.06),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.spinHubEnd.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: AppColors.spinHubGradient,
              ),
              child: Center(
                child: Text(
                  'SPIN',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.19,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
