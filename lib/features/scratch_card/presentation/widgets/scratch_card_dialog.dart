import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_result.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/presentation/providers/scratch_card_provider.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/presentation/widgets/scratch_reveal.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/presentation/widgets/spin_result_dialog.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';

/// How much of the card must be scratched before it auto-completes the
/// reveal — same "don't make them scratch every pixel" concession real
/// GPay/PhonePe cards make.
const double _revealThresholdPercent = 55;

/// width / height — a tall "trading card" shape, not a landscape banner.
const double _cardAspectRatio = 0.68;

/// Entry point for the whole feature — opens the "Scratch Card" popup. Not
/// registered as a go_router route, same reasoning as showSpinWinDialog
/// (this app never routes its popups). Deliberately no chrome around the
/// card itself (no title bar, no close button) — tapping the dimmed
/// barrier outside the card is the only way to dismiss, same as a real
/// scratch-card reward popup.
Future<void> showScratchCardDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (_) => const ScratchCardDialog(),
  );
}

class ScratchCardDialog extends ConsumerStatefulWidget {
  const ScratchCardDialog({super.key});

  @override
  ConsumerState<ScratchCardDialog> createState() => _ScratchCardDialogState();
}

class _ScratchCardDialogState extends ConsumerState<ScratchCardDialog> {
  final GlobalKey<ScratchRevealState> _scratchKey = GlobalKey<ScratchRevealState>();
  bool _isResolving = false;
  bool _fullyRevealed = false;
  ScratchResult? _result;

  Future<void> _handleReveal(bool canScratch) async {
    if (_result != null || _isResolving) return;
    if (!canScratch) {
      AppToast.show(
        context,
        "You're out of scratch cards for now — come back tomorrow!",
        type: ToastType.info,
      );
      return;
    }

    setState(() => _isResolving = true);
    final either = await ref.read(scratchUseCaseProvider).call();
    final result = either.fold((failure) => null, (value) => value);
    ref.invalidate(scratchEligibilityProvider);

    if (!mounted) return;

    if (result == null) {
      setState(() => _isResolving = false);
      AppToast.show(
        context,
        'Could not open the card right now — please check your connection and try again.',
        type: ToastType.error,
      );
      return;
    }

    if (!result.success) {
      setState(() => _isResolving = false);
      AppToast.show(
        context,
        result.message ?? "You're out of scratch cards for now — come back tomorrow!",
        type: ToastType.info,
      );
      return;
    }

    setState(() {
      _result = result;
      _isResolving = false;
    });
  }

  void _onThresholdReached() {
    _scratchKey.currentState?.reveal(duration: const Duration(milliseconds: 400));
    setState(() => _fullyRevealed = true);

    final result = _result;
    if (result == null) return;

    // A cash prize just landed in the wallet server-side — refresh the
    // balance shown elsewhere in the app, same convention spin_win_dialog
    // follows after a CASHBACK win.
    if (result.prizeType == 'CASHBACK') {
      ref.invalidate(walletProvider);
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final wonPrize = result.toPrize();
      if (wonPrize == null) return;
      showSpinResultDialog(context, wonPrize);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = math.min(screenWidth * 0.8, 340.w);

    final appearanceAsync = ref.watch(scratchCardAppearanceProvider);
    final eligibilityAsync = ref.watch(scratchEligibilityProvider);
    final coverImageUrl = appearanceAsync.value?.coverImageUrl;
    final eligibility = eligibilityAsync.value;
    final canScratch = eligibility?.hasScratchesAvailable ?? true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Center(
        child: SizedBox(
          width: cardWidth,
          child: AspectRatio(
            aspectRatio: _cardAspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.r),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ScratchReveal(
                    key: _scratchKey,
                    brushRadius: 26,
                    thresholdPercent: _revealThresholdPercent,
                    enabled: _result != null,
                    onScratchStart: () => _handleReveal(canScratch),
                    onThresholdReached: _onThresholdReached,
                    foil: coverImageUrl != null
                        ? Image(
                            image: CachedNetworkImageProvider(coverImageUrl),
                            fit: BoxFit.cover,
                          )
                        : const _DefaultFoil(),
                    child: _RevealedFace(result: _result),
                  ),
                  if (!_fullyRevealed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          color: Colors.black.withValues(alpha: 0.24),
                          alignment: Alignment.center,
                          child: _isResolving
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Scratch to unlock',
                                  style: AppTextStyles.buttonMedium.copyWith(
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
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

/// Default foil when no admin cover image is configured — a branded
/// gradient with a light scattered pattern and a centered gift icon,
/// rather than a flat single color.
class _DefaultFoil extends StatelessWidget {
  const _DefaultFoil();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.spinHubGradient),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(child: CustomPaint(painter: _ScatterPatternPainter())),
          Center(
            child: Container(
              width: 76.w,
              height: 76.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.giftFill, color: Colors.white, size: 38.sp),
            ),
          ),
        ],
      ),
    );
  }
}

/// Light memphis-style scatter (circles/squares/triangles/dashes) — a
/// fixed seed keeps the pattern stable across rebuilds instead of
/// reshuffling every frame.
class _ScatterPatternPainter extends CustomPainter {
  const _ScatterPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fillPaint = Paint()..color = Colors.white.withValues(alpha: 0.14);
    final random = math.Random(7);

    for (var i = 0; i < 28; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final s = 6.0 + random.nextDouble() * 10;
      switch (i % 4) {
        case 0:
          canvas.drawCircle(Offset(dx, dy), s / 2, fillPaint);
        case 1:
          canvas.drawRect(Rect.fromCenter(center: Offset(dx, dy), width: s, height: s), strokePaint);
        case 2:
          final path = Path()
            ..moveTo(dx, dy - s / 2)
            ..lineTo(dx + s / 2, dy + s / 2)
            ..lineTo(dx - s / 2, dy + s / 2)
            ..close();
          canvas.drawPath(path, strokePaint);
        default:
          canvas.drawLine(Offset(dx - s / 2, dy), Offset(dx + s / 2, dy), strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPatternPainter oldDelegate) => false;
}

/// What sits under the foil, resolved or not. Pre-resolve this is never
/// actually visible to the user (the ScratchReveal stays `enabled: false`
/// until [result] exists), so its exact look barely matters; it just needs
/// to not appear broken in the split-second it could theoretically flash.
class _RevealedFace extends StatelessWidget {
  const _RevealedFace({required this.result});

  final ScratchResult? result;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return const ColoredBox(color: Colors.white);
    }
    final String label = result.prizeLabel ?? '';
    final bool isWin = result.isWin;
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: EdgeInsets.all(20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64.w,
            height: 64.w,
            decoration: const BoxDecoration(
              gradient: AppColors.spinHubGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWin ? PhosphorIcons.giftFill : PhosphorIcons.smileySadFill,
              color: Colors.white,
              size: 32.sp,
            ),
          ),
          Gap(12.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(color: AppColors.spinTitlePurple),
          ),
        ],
      ),
    );
  }
}
