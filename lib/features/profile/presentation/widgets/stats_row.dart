import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/entities/user_stats_entity.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';

class StatsRow extends StatelessWidget {
  const StatsRow({
    required this.stats,
    super.key,
  });

  final UserStatsEntity stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            value: '${stats.totalOrders}',
            label: 'Orders',
          ),
        ),
        Gap(10.w),
        Expanded(
          child: _StatCard(
            value: _formatSpent(stats.totalSpent),
            label: 'Spent',
          ),
        ),
        Gap(10.w),
        Expanded(
          child: _StatCard(
            value: '${stats.loyaltyPoints}',
            label: 'Points',
          ),
        ),
      ],
    );
  }

  String _formatSpent(double value) {
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    }
    return value.toInrCurrency;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: AppTextStyles.h1.copyWith(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Gap(2.h),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
