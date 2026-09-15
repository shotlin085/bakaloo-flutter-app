import 'package:flutter/material.dart';

/// A scratch-to-reveal effect built on a plain `ClipPath` clipped directly
/// to the union of scratched-circle paths — deliberately NOT
/// `Path.combine` (difference) against the full card area.
///
/// That first version worked but got measurably laggier the longer you
/// scratched: differencing a boolean path against an ever-growing set of
/// circles means recomputing the ENTIRE difference from scratch on every
/// single frame, and that cost grows with how much has been scratched so
/// far. Clipping straight to the union path instead costs nothing extra
/// as it grows — clipping is a routine, cheap rasterizer operation, not a
/// CPU-side geometry boolean.
///
/// This only works by also flipping the mental model: [foil] sits at the
/// bottom and is always fully painted; [child] sits on top, clipped to
/// only the scratched-so-far region. Where nothing's been scratched, the
/// (unclipped) foil is all that shows; where it has, the child shows
/// through on top of it — visually identical to a hole punched in a
/// foil, at a fraction of the cost.
///
/// Also still avoids `saveLayer`/`BlendMode` entirely (unlike the
/// `scratcher` package this replaced), which is broken under Impeller.
class ScratchReveal extends StatefulWidget {
  const ScratchReveal({
    required this.foil,
    required this.child,
    super.key,
    this.enabled = true,
    this.brushRadius = 42,
    this.thresholdPercent = 38,
    this.onScratchStart,
    this.onThresholdReached,
  });

  /// What covers [child] until scratched away (a color, an image, or both
  /// layered by the caller).
  final Widget foil;

  /// The content revealed underneath.
  final Widget child;

  /// Whether new scratches are accepted. While false, gestures are still
  /// detected (so [onScratchStart] still fires) but leave no mark.
  final bool enabled;

  /// Radius (logical px) of each scratch dab. Deliberately generous — a
  /// couple of natural scratch strokes should be enough to cross
  /// [thresholdPercent], not a full careful coverage pass.
  final double brushRadius;

  /// Percentage of the sampled area that must be scratched before
  /// [onThresholdReached] fires and the caller can call [reveal].
  final double thresholdPercent;

  final VoidCallback? onScratchStart;
  final VoidCallback? onThresholdReached;

  @override
  State<ScratchReveal> createState() => ScratchRevealState();
}

class ScratchRevealState extends State<ScratchReveal> {
  // Coarser than a pixel-perfect mask on purpose — this only drives the
  // percentage-scratched estimate, and a finer grid buys no visible
  // accuracy here while costing more per dab.
  static const int _gridSize = 14;

  final Path _scratchedUnion = Path();
  final Set<int> _hitCheckpoints = {};
  List<Offset>? _checkpoints;
  Size? _checkpointsSize;
  Offset? _lastPoint;
  bool _thresholdFired = false;
  bool _revealed = false;

  /// Exposed for tests — whether [reveal] has been called.
  bool get isFullyRevealed => _revealed;

  void _ensureCheckpoints(Size size) {
    if (_checkpointsSize == size && _checkpoints != null) return;
    _checkpointsSize = size;
    _checkpoints = <Offset>[
      for (var y = 0; y < _gridSize; y++)
        for (var x = 0; x < _gridSize; x++)
          Offset(
            (x + 0.5) * size.width / _gridSize,
            (y + 0.5) * size.height / _gridSize,
          ),
    ];
    _hitCheckpoints.clear();
  }

  void _dab(Offset point) {
    _scratchedUnion.addOval(Rect.fromCircle(center: point, radius: widget.brushRadius));
    final checkpoints = _checkpoints;
    if (checkpoints == null) return;
    for (var i = 0; i < checkpoints.length; i++) {
      if (_hitCheckpoints.contains(i)) continue;
      if ((checkpoints[i] - point).distance <= widget.brushRadius) {
        _hitCheckpoints.add(i);
      }
    }
  }

  void _addStroke(Offset from, Offset to) {
    const stepSize = 16.0;
    final distance = (to - from).distance;
    final steps = (distance / stepSize).ceil().clamp(1, 150);
    for (var i = 1; i <= steps; i++) {
      _dab(Offset.lerp(from, to, i / steps)!);
    }
  }

  void _handlePoint(Offset point, Size size) {
    if (!widget.enabled || _revealed) return;
    _ensureCheckpoints(size);
    setState(() {
      if (_lastPoint != null) {
        _addStroke(_lastPoint!, point);
      } else {
        _dab(point);
      }
      _lastPoint = point;
    });

    final checkpoints = _checkpoints;
    if (checkpoints == null || checkpoints.isEmpty) return;
    final progress = _hitCheckpoints.length / checkpoints.length * 100;
    if (!_thresholdFired && progress >= widget.thresholdPercent) {
      _thresholdFired = true;
      widget.onThresholdReached?.call();
    }
  }

  /// Fully reveals [child]. No shape-morph animation on the clip itself
  /// (Flutter has no built-in way to interpolate between two arbitrary
  /// Path shapes) — this just switches the clip to "covers everything";
  /// callers that want a transition animate something else (opacity,
  /// scale) around this.
  void reveal({Duration? duration}) {
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            widget.onScratchStart?.call();
            _handlePoint(details.localPosition, size);
          },
          onPanUpdate: (details) => _handlePoint(details.localPosition, size),
          onPanEnd: (_) => _lastPoint = null,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                widget.foil,
                ClipPath(
                  clipper: _RevealClipper(_scratchedUnion, _revealed),
                  child: widget.child,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Clips to (when not yet revealed) exactly the scratched-so-far union,
/// or the full area once [revealed] — see [ScratchReveal]'s doc comment
/// for why this is a plain clip and never a `Path.combine`.
class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper(this.scratchedPath, this.revealed);

  final Path scratchedPath;
  final bool revealed;

  @override
  Path getClip(Size size) {
    if (revealed) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    return scratchedPath;
  }

  // A fresh clipper instance is only ever built on a rebuild that already
  // has new scratch content (see ScratchRevealState.build), so there's no
  // cheaper-but-correct check to do here — always reclip.
  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) => true;
}
