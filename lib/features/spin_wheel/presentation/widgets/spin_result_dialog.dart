import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/presentation/widgets/gift_box_reveal.dart';

/// "You won!" celebration popup — gift box pop-open + confetti burst for a
/// real prize, a gentler consolation card for `betterLuck`. Shown after
/// [SpinWheelDial.spinToIndex] finishes, on top of the still-open
/// Spin & Win dialog.
///
/// PHASE 1: purely tells the customer what they won; no wallet credit /
/// coupon-code issuance happens yet (see spin_wheel_provider.dart doc
/// comment) — that lands with the backend algorithm in phase 2.
Future<void> showSpinResultDialog(BuildContext context, SpinPrize prize) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => SpinResultDialog(prize: prize),
  );
}

class SpinResultDialog extends StatefulWidget {
  const SpinResultDialog({required this.prize, super.key});

  final SpinPrize prize;

  @override
  State<SpinResultDialog> createState() => _SpinResultDialogState();
}

class _SpinResultDialogState extends State<SpinResultDialog> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String get _subtitle {
    switch (widget.prize.type) {
      case SpinPrizeType.freeDelivery:
        return "You've won Free Delivery on your next order!";
      case SpinPrizeType.percentageOff:
        return "You've won ${widget.prize.value!.toInt()}% OFF your next order!";
      case SpinPrizeType.flatOff:
        return "You've won ₹${widget.prize.value!.toInt()} OFF your next order!";
      case SpinPrizeType.buyOneGetOne:
        return "You've won a Buy 1 Get 1 offer!";
      case SpinPrizeType.extraSavings:
        return "You've unlocked Extra Savings on your next order!";
      case SpinPrizeType.betterLuck:
        return "No prize this time — come back tomorrow for another spin!";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWin = widget.prize.isWinning;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          if (isWin)
            Positioned(
              top: -20.h,
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: math.pi / 2,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 26,
                  maxBlastForce: 24,
                  minBlastForce: 10,
                  gravity: 0.28,
                  shouldLoop: false,
                  colors: const <Color>[
                    AppColors.spinHubStart,
                    AppColors.spinHubEnd,
                    AppColors.promoBrandGold,
                    Colors.white,
                  ],
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 26.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: AppColors.bgSection,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.xLight,
                        size: 18.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (isWin)
                  GiftBoxReveal(
                    size: 120.w,
                    onOpened: () => _confettiController.play(),
                    child: Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: const BoxDecoration(
                        gradient: AppColors.spinHubGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.prize.icon,
                        color: Colors.white,
                        size: 32.sp,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Icon(
                      PhosphorIcons.smileySadLight,
                      size: 72.sp,
                      color: AppColors.spinRingPurple,
                    ),
                  ),
                Gap(10.h),
                Text(
                  isWin ? '🎉 Congratulations!' : 'Better Luck Next Time!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(
                    color: AppColors.spinTitlePurple,
                  ),
                ),
                Gap(8.h),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                Gap(22.h),
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.spinCtaGradient,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14.r),
                        onTap: () => Navigator.of(context).pop(),
                        child: Center(
                          child: Text(
                            isWin ? 'Awesome!' : 'OK, Got it',
                            style: AppTextStyles.buttonLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
