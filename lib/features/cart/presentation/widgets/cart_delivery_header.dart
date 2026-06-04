import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';

class CartDeliveryHeader extends StatelessWidget {
  const CartDeliveryHeader({
    required this.estimateMinutes,
    required this.itemCount,
    super.key,
    this.selectedSlot,
    this.onScheduleTap,
  });

  final int estimateMinutes;
  final int itemCount;
  final SelectedDeliverySlot? selectedSlot;
  final VoidCallback? onScheduleTap;

  @override
  Widget build(BuildContext context) {
    final itemLabel = '$itemCount item${itemCount == 1 ? '' : 's'}';
    final slot = selectedSlot ?? const SelectedDeliverySlot.asap();
    final isScheduled = slot.isScheduled;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      child: Row(
        children: <Widget>[
          Icon(
            isScheduled
                ? Icons.calendar_month_outlined
                : Icons.access_time_outlined,
            size: 28.sp,
            color: isScheduled
                ? const Color(0xFF7C3AED)
                : const Color(0xFF666666),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                isScheduled
                    ? Text(
                        'Scheduled delivery',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7C3AED),
                          fontFamily: 'Inter',
                        ),
                      )
                    : RichText(
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
                  isScheduled
                      ? slot.displayLabel.replaceFirst(
                          'Scheduled for ', '')
                      : itemLabel,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: isScheduled
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: isScheduled
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF888888),
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onScheduleTap,
            icon: Icon(
              isScheduled
                  ? Icons.edit_calendar_outlined
                  : Icons.calendar_month_outlined,
              size: 16.sp,
              color: isScheduled
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF0AC26B),
            ),
            label: Text(
              isScheduled ? 'Change' : 'Schedule',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isScheduled
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF0AC26B),
                fontFamily: 'Inter',
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: isScheduled
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF0AC26B),
              side: BorderSide(
                color: isScheduled
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF0AC26B),
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
