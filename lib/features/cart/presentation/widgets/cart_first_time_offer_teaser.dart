import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';

/// A positive "add X to unlock this offer" nudge for a first-time customer
/// whose cart doesn't yet qualify for any active first-order offer — e.g.
/// an all-dairy cart shown "Add ₹150 of Fresh Vegetables to unlock Free
/// Delivery!" instead of the offer just silently never appearing anywhere.
/// Sits between Coupons & Offers and Bill Summary; only rendered when the
/// backend actually has something to tease (see [BillSummaryEntity.
/// firstTimeOfferTeaser] — always null once an offer is already applied).
class CartFirstTimeOfferTeaser extends StatelessWidget {
  const CartFirstTimeOfferTeaser({required this.teaser, super.key});

  final FirstTimeOfferTeaserInfo teaser;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFEAF9EF), Color(0xFFF6FDF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: const Color(0xFFBFE8CE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 46.w,
              height: 46.w,
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.giftFill,
                color: Colors.white,
                size: 22.sp,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'FIRST ORDER',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.sp,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      Gap(8.w),
                      Expanded(
                        child: Text(
                          teaser.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap(8.h),
                  Text(
                    teaser.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF2E7D46),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
