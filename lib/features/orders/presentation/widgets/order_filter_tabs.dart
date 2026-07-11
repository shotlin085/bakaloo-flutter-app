import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';

/// Horizontal segmented filter chips for the orders list.
class OrderFilterTabs extends StatelessWidget {
  const OrderFilterTabs({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final OrderFilter selected;
  final ValueChanged<OrderFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: OrderFilter.values.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          final filter = OrderFilter.values[index];
          return _FilterChip(
            label: filter.label,
            icon: _iconFor(filter),
            selected: filter == selected,
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }

  PhosphorIconData _iconFor(OrderFilter filter) {
    return switch (filter) {
      OrderFilter.all => PhosphorIcons.squaresFour,
      OrderFilter.active => PhosphorIcons.clock,
      OrderFilter.delivered => PhosphorIcons.checkCircle,
      OrderFilter.cancelled => PhosphorIcons.xCircle,
    };
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final PhosphorIconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? AppColors.orderViolet : AppColors.textSecondary;

    return Material(
      color: selected ? AppColors.orderVioletSurface : AppColors.bgCard,
      borderRadius: BorderRadius.circular(100.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100.r),
            border: Border.all(
              color: selected
                  ? AppColors.orderViolet
                  : AppColors.borderLight,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PhosphorIcon(icon, size: 16.sp, color: foreground),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
