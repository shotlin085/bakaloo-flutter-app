import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class RatingBadge extends StatelessWidget {
  const RatingBadge({
    required this.rating,
    required this.count,
    super.key,
  });

  final double rating;
  final int count;

  String get _formattedCount {
    if (count < 1000) {
      return '$count';
    }

    final value = count / 1000;
    final formatted = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '${formatted}k';
  }

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0C831F),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 3.w),
          PhosphorIcon(
            PhosphorIcons.star(PhosphorIconsStyle.fill),
            size: 12.sp,
            color: Colors.white,
          ),
          SizedBox(width: 6.w),
          Text(
            _formattedCount,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
