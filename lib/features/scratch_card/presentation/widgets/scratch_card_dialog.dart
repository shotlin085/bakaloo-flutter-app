import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:scratcher/scratcher.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_result.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/presentation/providers/scratch_card_provider.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/presentation/widgets/spin_result_dialog.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';

/// How much of the card must be scratched before it auto-completes the
/// reveal — same "don't make them scratch every pixel" concession real
/// GPay/PhonePe cards make.
const double _revealThresholdPercent = 55;

/// Entry point for the whole feature — opens the "Scratch Card" popup. Not
/// registered as a go_router route, same reasoning as showSpinWinDialog
/// (this app never routes its popups).
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
  final GlobalKey<ScratcherState> _scratcherKey = GlobalKey<ScratcherState>();
  bool _isResolving = false;
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
    _scratcherKey.currentState?.reveal(duration: const Duration(milliseconds: 400));
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
    final mediaQuery = MediaQuery.of(context);
    final topGap = mediaQuery.padding.top + 56.h;
    final bottomGap = mediaQuery.padding.bottom + AppDimensions.bottomNavHeight + 14.h;

    final appearanceAsync = ref.watch(scratchCardAppearanceProvider);
    final eligibilityAsync = ref.watch(scratchEligibilityProvider);
    final coverImageUrl = appearanceAsync.value?.coverImageUrl;
    final eligibility = eligibilityAsync.value;
    final canScratch = eligibility?.hasScratchesAvailable ?? true;

    final cardsLabel = eligibility == null
        ? 'Checking your cards…'
        : eligibility.hasScratchesAvailable
            ? '${eligibility.scratchesAvailable} card${eligibility.scratchesAvailable == 1 ? '' : 's'} available'
            : 'Come back tomorrow for more cards';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.only(top: topGap, bottom: bottomGap),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: <Widget>[
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
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
                            'Scratch Card',
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
                        'Scratch the card to reveal a surprise!',
                        style: AppTextStyles.bodyMedium,
                      ),
                      Gap(22.h),
                      AspectRatio(
                        aspectRatio: 8 / 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20.r),
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              Scratcher(
                                key: _scratcherKey,
                                brushSize: 40,
                                threshold: _revealThresholdPercent,
                                color: AppColors.spinTitlePurple,
                                image: coverImageUrl == null
                                    ? null
                                    : Image(
                                        image: CachedNetworkImageProvider(coverImageUrl),
                                        fit: BoxFit.cover,
                                      ),
                                enabled: _result != null,
                                onScratchStart: () => _handleReveal(canScratch),
                                onThreshold: _onThresholdReached,
                                child: _RevealedFace(result: _result),
                              ),
                              if (_result == null)
                                IgnorePointer(
                                  child: Center(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.28),
                                        borderRadius: BorderRadius.circular(30.r),
                                      ),
                                      child: _isResolving
                                          ? SizedBox(
                                              width: 20.w,
                                              height: 20.w,
                                              child: const CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Icon(
                                                  PhosphorIcons.handTapLight,
                                                  size: 16.sp,
                                                  color: Colors.white,
                                                ),
                                                Gap(6.w),
                                                Text(
                                                  'Scratch here!',
                                                  style: AppTextStyles.buttonMedium.copyWith(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Gap(16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            PhosphorIcons.creditCardLight,
                            size: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                          Gap(5.w),
                          Text(
                            cardsLabel,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
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
      ),
    );
  }
}

/// What sits under the foil, resolved or not. Pre-resolve this is never
/// actually visible to the user (the Scratcher stays `enabled: false` until
/// [_result] exists — see the parent's doc comment on the atomic
/// enabled/child update), so its exact look barely matters; it just needs
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
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56.w,
            height: 56.w,
            decoration: const BoxDecoration(
              gradient: AppColors.spinHubGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWin ? PhosphorIcons.giftFill : PhosphorIcons.smileySadFill,
              color: Colors.white,
              size: 28.sp,
            ),
          ),
          Gap(10.h),
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
