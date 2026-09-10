import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// A stylized purple gift box that shakes, pops its lid open, and reveals
/// [child] (the won prize's icon) bursting out with a bounce. Runs once on
/// mount and calls [onOpened] the moment the lid has fully popped — that's
/// the cue [SpinResultDialog] uses to fire the confetti burst so it doesn't
/// go off before there's a box to burst from.
class GiftBoxReveal extends StatefulWidget {
  const GiftBoxReveal({
    required this.child,
    this.size = 150,
    this.onOpened,
    super.key,
  });

  final Widget child;
  final double size;
  final VoidCallback? onOpened;

  @override
  State<GiftBoxReveal> createState() => _GiftBoxRevealState();
}

class _GiftBoxRevealState extends State<GiftBoxReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _openedFired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(_maybeFireOpened);
    _controller.forward();
  }

  void _maybeFireOpened() {
    if (!_openedFired && _controller.value >= 0.42) {
      _openedFired = true;
      widget.onOpened?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_maybeFireOpened);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shake = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.28, curve: Curves.easeInOut),
    );
    // Lid motion (pop up + tilt) and lid fade run on separate, slightly
    // offset intervals so the very last animation frame settles on a clean
    // "lid gone, prize revealed" pose instead of freezing the lid mid-flight
    // at whatever angle its opening motion last reached.
    final lidPop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.5, curve: Curves.easeOutBack),
    );
    final lidFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.72, curve: Curves.easeIn),
    );
    final burst = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.48, 1, curve: Curves.elasticOut),
    );
    final burstFadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.6, curve: Curves.easeOut),
    );

    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size * 1.7,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final shakeT = shake.value;
          final wiggle = shakeT >= 1
              ? 0.0
              : math.sin(shakeT * math.pi * 7) * 0.09 * (1 - shakeT);
          final lidT = lidPop.value.clamp(0.0, 1.0);
          final lidOpacity = 1 - lidFade.value.clamp(0.0, 1.0);
          final burstT = burst.value.clamp(0.0, 1.4);
          final burstOpacity = burstFadeIn.value.clamp(0.0, 1.0);

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              // Burst content — revealed once the lid is out of the way.
              Positioned(
                bottom: widget.size * 0.78,
                child: Opacity(
                  opacity: burstOpacity,
                  child: Transform.scale(
                    scale: burstT.clamp(0.0, 1.4),
                    child: widget.child,
                  ),
                ),
              ),
              // Box body.
              Positioned(
                bottom: 0,
                child: Transform.rotate(
                  angle: wiggle,
                  child: _BoxBody(size: widget.size),
                ),
              ),
              // Lid — pops up and tilts open, then fades out completely
              // rather than resting mid-air, so the settled frame reads as
              // "box open, prize revealed" instead of a lid frozen in
              // flight.
              if (lidOpacity > 0)
                Positioned(
                  bottom: widget.size * 0.62,
                  child: Opacity(
                    opacity: lidOpacity,
                    child: Transform.translate(
                      offset: Offset(0, -lidT * widget.size * 0.55),
                      child: Transform.rotate(
                        angle: wiggle - lidT * 0.6,
                        child: _BoxLid(size: widget.size),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BoxBody extends StatelessWidget {
  const _BoxBody({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.62,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Container(
            width: size,
            height: size * 0.62,
            decoration: BoxDecoration(
              gradient: AppColors.spinHubGradient,
              borderRadius: BorderRadius.circular(size * 0.06),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: Offset(0, size * 0.06),
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.22,
            height: size * 0.62,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

class _BoxLid extends StatelessWidget {
  const _BoxLid({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final lidWidth = size * 1.08;
    final lidHeight = size * 0.2;
    return SizedBox(
      width: lidWidth,
      height: lidHeight + size * 0.22,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: lidWidth,
            height: lidHeight,
            decoration: BoxDecoration(
              gradient: AppColors.spinHubGradient,
              borderRadius: BorderRadius.circular(size * 0.05),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: Offset(0, size * 0.02),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.22,
              height: lidHeight,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          // Bow.
          Positioned(
            top: -size * 0.16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _BowLoop(size: size, flip: false),
                SizedBox(width: size * 0.02),
                _BowLoop(size: size, flip: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BowLoop extends StatelessWidget {
  const _BowLoop({required this.size, required this.flip});
  final double size;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flip,
      child: Container(
        width: size * 0.2,
        height: size * 0.18,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size * 0.16),
            bottomLeft: Radius.circular(size * 0.16),
            topRight: Radius.circular(size * 0.02),
            bottomRight: Radius.circular(size * 0.1),
          ),
        ),
      ),
    );
  }
}
