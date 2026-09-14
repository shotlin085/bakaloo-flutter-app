import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/business_account/presentation/providers/price_mode_provider.dart';

/// Quick "B2B Store is on" indicator + one-tap disable, shown directly on
/// the Profile page's summary right below the order-stats row — only ever
/// while wholesale pricing is actually ACTIVE (`isWholesalePricingActiveProvider`,
/// which is already exactly "business account APPROVED and its b2bEnabled
/// toggle is on" — see PriceModeNotifier).
///
/// This card only ever turns things OFF. A B2C customer, an approved
/// account that hasn't turned wholesale on yet, and (the moment this
/// card's own switch flips it off) that same account a second later — all
/// render nothing here at all: the whole widget returns a zero-size
/// SizedBox.shrink() rather than a disabled/explanatory placeholder.
/// Turning it back ON is a deliberate trip to the dedicated Business
/// Account screen, not something this shortcut offers.
class B2BModeCard extends ConsumerStatefulWidget {
  const B2BModeCard({super.key});

  @override
  ConsumerState<B2BModeCard> createState() => _B2BModeCardState();
}

class _B2BModeCardState extends ConsumerState<B2BModeCard> {
  bool _toggling = false;

  Future<void> _onChanged(bool _) async {
    setState(() => _toggling = true);
    final result = await ref.read(priceModeProvider.notifier).toggle();
    if (!mounted) return;
    setState(() => _toggling = false);
    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wholesaleActive = ref.watch(isWholesalePricingActiveProvider);
    if (!wholesaleActive) {
      return const SizedBox.shrink();
    }

    // Top spacing lives here (not in the parent layout) so a B2C customer
    // — for whom this whole widget renders as a zero-size SizedBox.shrink()
    // above — never ends up with an orphaned empty gap between the stats
    // row and MY ACTIVITY.
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.orderVioletSurface, Colors.white],
          ),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.orderVioletBorder),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.orderVioletGlow,
              blurRadius: 16.r,
              offset: Offset(0, 6.h),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    AppColors.orderViolet,
                    AppColors.orderVioletDark
                  ],
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                PhosphorIcons.storefrontFill,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'B2B Store',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.orderVioletDark,
                        ),
                      ),
                      Gap(6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.orderViolet,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'PRO',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap(2.h),
                  Text(
                    'Wholesale pricing is active across the app.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Gap(8.w),
            _toggling
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: wholesaleActive,
                    activeThumbColor: AppColors.orderViolet,
                    onChanged: _onChanged,
                  ),
          ],
        ),
      ),
    );
  }
}
