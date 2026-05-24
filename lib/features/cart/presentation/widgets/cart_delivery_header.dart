import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CartDeliveryHeader extends StatelessWidget {
  const CartDeliveryHeader({
    required this.estimateMinutes,
    required this.itemCount,
    super.key,
    this.onScheduleTap,
  });

  final int estimateMinutes;
  final int itemCount;
  final VoidCallback? onScheduleTap;

  @override
  Widget build(BuildContext context) {
    final itemLabel = '$itemCount item${itemCount == 1 ? '' : 's'}';

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.access_time_outlined,
            size: 28.sp,
            color: const Color(0xFF666666),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF222222),
                      fontFamily: 'Inter',
                    ),
                    children: <InlineSpan>[
                      const TextSpan(text: 'Delivering in '),
                      TextSpan(
                        text: '$estimateMinutes mins',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222222),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  itemLabel,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF888888),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onScheduleTap,
            icon: Icon(
              Icons.calendar_month_outlined,
              size: 16.sp,
              color: const Color(0xFF0AC26B),
            ),
            label: Text(
              'Schedule',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0AC26B),
                fontFamily: 'Inter',
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0AC26B),
              side: const BorderSide(
                color: Color(0xFF0AC26B),
                width: 1.5,
              ),
              minimumSize: Size(0, 38.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
