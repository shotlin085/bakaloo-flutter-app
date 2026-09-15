import 'package:flutter/material.dart';

/// A scratch-to-reveal effect built on `ClipPath` + `Path.combine`
/// (difference) rather than the far more common `Canvas.saveLayer` +
/// `BlendMode.clear` "punch a hole in the foil" technique used by
/// third-party packages like `scratcher`.
///
/// That technique is broken under Impeller (Flutter's default Android/iOS
/// renderer): a `CustomPainter` using `saveLayer` with a blend mode inside
/// can render the whole layer blank/white instead of compositing
/// correctly — confirmed against this exact app on a real device, and a
/// known, still-open class of Flutter engine bug (e.g.
/// flutter/flutter#145567, #134068, #136663). Pure path-clipping never
/// touches `saveLayer`, so it has no such issue.
class ScratchReveal extends StatefulWidget {
  const ScratchReveal({
    required this.foil,
    required this.child,
    super.key,
    this.enabled = true,
    this.brushRadius = 22,
    this.thresholdPercent = 55,
    this.onScratchStart,
    this.onThresholdReached,
  });

  /// What covers [child] until scratched away (a color, an image, or both
  /// layered by the caller).
  final Widget foil;

  /// The content revealed underneath.
  final Widget child;

  /// Whether new scratches are accepted. While false, gestures are still
  /// detected (so [onScratchStart] still fires) but leave no mark — same
  /// "can start scratching before the prize resolves, marks apply once it
  /// does" behavior the dialog relies on.
  final bool enabled;

  /// Radius (logical px) of each scratch dab.
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
  static const int _gridSize = 24;

  final Path _scratchedPath = Path();
  final Set<int> _hitCheckpoints = {};
  List<Offset>? _checkpoints;
  Size? _checkpointsSize;
  Offset? _lastPoint;
  bool _thresholdFired = false;
  bool _revealed = false;
  Duration _revealDuration = Duration.zero;

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
    _scratchedPath.addOval(Rect.fromCircle(center: point, radius: widget.brushRadius));
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
    const stepSize = 8.0;
    final distance = (to - from).distance;
    final steps = (distance / stepSize).ceil().clamp(1, 200);
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

  /// Fully reveals [child], fading the foil out over [duration].
  void reveal({Duration? duration}) {
    setState(() {
      _revealed = true;
      _revealDuration = duration ?? Duration.zero;
    });
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
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              widget.child,
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _revealed ? 0 : 1,
                  duration: _revealDuration,
                  child: ClipPath(
                    clipper: _DifferenceClipper(_scratchedPath),
                    child: widget.foil,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Clips to (full area − already-scratched area) — the inverse of what a
/// plain `ClipPath` gives you, which is exactly the "hole punched in the
/// foil" look this effect needs.
class _DifferenceClipper extends CustomClipper<Path> {
  _DifferenceClipper(this.scratchedPath);

  final Path scratchedPath;

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    return Path.combine(PathOperation.difference, full, scratchedPath);
  }

  @override
  bool shouldReclip(covariant _DifferenceClipper oldClipper) => true;
}
