import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' show RiveAnimation;

const Color kAppLoadingBackgroundColor = Color.fromARGB(255, 241, 244, 249);

class AppLoadingAnimation extends StatefulWidget {
  const AppLoadingAnimation({
    super.key,
    this.backgroundColor = kAppLoadingBackgroundColor,
  });

  final Color backgroundColor;

  @override
  State<AppLoadingAnimation> createState() => _AppLoadingAnimationState();
}

class _AppLoadingAnimationState extends State<AppLoadingAnimation> {
  static const String _riveAssetPath = 'assets/animations/5158-10360-jumpy.riv';
  static const String _fallbackAssetPath = 'assets/images/logo_icon.png';

  late final Future<bool> _assetReadyFuture = _checkAnimationAsset();

  Future<bool> _checkAnimationAsset() async {
    try {
      await rootBundle.load(_riveAssetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final animationSize = (constraints.biggest.shortestSide * 0.84)
              .clamp(280.0, 420.0)
              .toDouble();
          final fallbackSize = (constraints.biggest.shortestSide * 0.34)
              .clamp(120.0, 180.0)
              .toDouble();

          return Center(
            child: RepaintBoundary(
              child: FutureBuilder<bool>(
                future: _assetReadyFuture,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<bool> snapshot,
                ) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return SizedBox(
                      width: animationSize,
                      height: animationSize,
                    );
                  }

                  if (snapshot.data != true) {
                    return SizedBox(
                      width: fallbackSize,
                      height: fallbackSize,
                      child: Image.asset(
                        _fallbackAssetPath,
                        fit: BoxFit.contain,
                      ),
                    );
                  }

                  return SizedBox(
                    width: animationSize,
                    height: animationSize,
                    child: const RiveAnimation.asset(
                      _riveAssetPath,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
