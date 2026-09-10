import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/presentation/providers/spin_wheel_provider.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/presentation/widgets/spin_result_dialog.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/presentation/widgets/spin_wheel_dial.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';

const String _backgroundAsset = 'assets/images/spin_wheel/spin_background.png';
const String _brandLogoAsset = 'assets/icon/brand_logo.png';

/// Entry point for the whole feature — opens the "Spin & Win" popup.
/// Not registered as a go_router route (this app never routes its popups,
/// see lib/routing/app_router.dart) — call this imperatively from wherever
/// the customer triggers it (Profile menu, home onboarding chain, etc.).
Future<void> showSpinWinDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (_) => const SpinWinDialog(),
  );
}

class SpinWinDialog extends ConsumerStatefulWidget {
  const SpinWinDialog({super.key});

  @override
  ConsumerState<SpinWinDialog> createState() => _SpinWinDialogState();
}

class _SpinWinDialogState extends ConsumerState<SpinWinDialog> {
  final GlobalKey<SpinWheelDialState> _dialKey =
      GlobalKey<SpinWheelDialState>();
  bool _isSpinning = false;

  Future<void> _spin(List<SpinPrize> currentPrizes, bool isLive) async {
    if (_isSpinning) return;
    if (!isLive) {
      AppToast.show(
        context,
        "The wheel isn't available right now — please try again shortly.",
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isSpinning = true);
    final result = await ref.read(spinWheelProvider.notifier).spin(currentPrizes);
    ref.invalidate(spinEligibilityProvider);

    if (!mounted) return;

    if (result == null) {
      setState(() => _isSpinning = false);
      AppToast.show(
        context,
        'Could not spin right now — please check your connection and try again.',
        type: ToastType.error,
      );
      return;
    }

    if (!result.success) {
      setState(() => _isSpinning = false);
      AppToast.show(
        context,
        result.message ?? "You're out of spins for now — come back tomorrow!",
        type: ToastType.info,
      );
      return;
    }

    final resolved = ref.read(spinWheelProvider).resolved;
    if (resolved != null) {
      await _dialKey.currentState?.spinToIndex(resolved.prizeIndex);
    }

    if (!mounted) return;
    setState(() => _isSpinning = false);

    final wonPrize = result.toPrize();
    if (wonPrize == null) return;

    // A cash prize just landed in the wallet server-side — refresh the
    // balance shown elsewhere in the app (matches the existing
    // invalidate-after-mutation convention, e.g. checkout_provider.dart).
    if (wonPrize.type == SpinPrizeType.extraSavings) {
      ref.invalidate(walletProvider);
    }

    await showSpinResultDialog(context, wonPrize);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topGap = mediaQuery.padding.top + 56.h;
    final bottomGap =
        mediaQuery.padding.bottom + AppDimensions.bottomNavHeight + 14.h;
    final wheelSize = math.min(320.w, mediaQuery.size.width * 0.82);

    final configAsync = ref.watch(spinConfigProvider);
    final isLiveAsync = ref.watch(spinConfigIsLiveProvider);
    final eligibilityAsync = ref.watch(spinEligibilityProvider);

    final prizes = configAsync.value ?? kSpinWheelPrizes;
    final eligibility = eligibilityAsync.value;
    final noSpinsLeft = eligibility != null && !eligibility.hasSpinsAvailable;
    final canSpin = (isLiveAsync.value ?? false) && !noSpinsLeft && !_isSpinning;

    final spinsLabel = eligibility == null
        ? '1 free spin today'
        : eligibility.hasSpinsAvailable
            ? '${eligibility.spinsAvailable} spin${eligibility.spinsAvailable == 1 ? '' : 's'} available'
            : 'Come back tomorrow for more spins';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.only(top: topGap, bottom: bottomGap),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset(_backgroundAsset, fit: BoxFit.cover),
            ),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image.asset(_brandLogoAsset, height: 32.h),
                    Gap(6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          PhosphorIcons.confettiFill,
                          size: 18.sp,
                          color: AppColors.promoBrandGold,
                        ),
                        Gap(6.w),
                        Text(
                          'Spin & Win',
                          style: AppTextStyles.display.copyWith(
                            fontSize: 24.sp,
                            color: AppColors.spinTitlePurple,
                          ),
                        ),
                        Gap(6.w),
                        Icon(
                          PhosphorIcons.confettiFill,
                          size: 18.sp,
                          color: AppColors.promoBrandGold,
                        ),
                      ],
                    ),
                    Gap(4.h),
                    Text(
                      'Try your luck and unlock exclusive offers!',
                      style: AppTextStyles.bodyMedium,
                    ),
                    Gap(18.h),
                    if (configAsync.isLoading)
                      SizedBox(
                        width: wheelSize,
                        height: wheelSize,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.spinHubStart,
                            ),
                          ),
                        ),
                      )
                    else
                      SpinWheelDial(
                        key: _dialKey,
                        prizes: prizes,
                        size: wheelSize,
                        spinning: _isSpinning,
                        onHubTap: () => _spin(prizes, canSpin),
                      ),
                    Gap(28.h),
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.spinCtaGradient,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.spinHubEnd
                                  .withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: Offset(0, 6.h),
                            ),
                          ],
                        ),
                        child: Opacity(
                          opacity: canSpin || _isSpinning ? 1 : 0.55,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16.r),
                              onTap: (_isSpinning || configAsync.isLoading)
                                  ? null
                                  : () => _spin(prizes, canSpin),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      _isSpinning
                                          ? 'Spinning…'
                                          : noSpinsLeft
                                              ? 'No Spins Left'
                                              : 'Spin Now',
                                      style: AppTextStyles.buttonLarge.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (!_isSpinning && !noSpinsLeft) ...<Widget>[
                                      Gap(4.w),
                                      Icon(
                                        PhosphorIcons.caretRightBold,
                                        size: 16.sp,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Gap(10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          PhosphorIcons.giftLight,
                          size: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                        Gap(5.w),
                        Text(
                          spinsLabel,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                    Gap(18.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.spinCardTranslucent,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.orderVioletBorder),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            PhosphorIcons.ticketFill,
                            size: 22.sp,
                            color: AppColors.orderViolet,
                          ),
                          Gap(10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  'Win up to ₹100 off',
                                  style: AppTextStyles.labelLarge,
                                ),
                                Text(
                                  'on your next order',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Good Deals\nEveryday!',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontStyle: FontStyle.italic,
                              color: AppColors.orderViolet,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10.h,
              right: 10.w,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    PhosphorIcons.xLight,
                    size: 18.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
