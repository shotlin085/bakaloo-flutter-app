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
    this.nextAvailableLabel,
    this.onViewHoursTap,
  });

  final int estimateMinutes;
  final int itemCount;
  final SelectedDeliverySlot? selectedSlot;
  final VoidCallback? onScheduleTap;
  /// Set only when the store is closed and the customer is still on ASAP —
  /// replaces the "Delivering in X mins" line with the next real available
  /// window instead of continuing to promise an estimate that can't be met.
  final String? nextAvailableLabel;
  /// Opens the "view store hours" sheet. Only rendered when provided.
  final VoidCallback? onViewHoursTap;

  @override
  Widget build(BuildContext context) {
    final itemLabel = '$itemCount item${itemCount == 1 ? '' : 's'}';
    final slot = selectedSlot ?? const SelectedDeliverySlot.asap();
    final isScheduled = slot.isScheduled;
    final isClosed = !isScheduled && nextAvailableLabel != null;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      child: Row(
        children: <Widget>[
          Icon(
            isScheduled || isClosed
                ? Icons.calendar_month_outlined
                : Icons.access_time_outlined,
            size: 28.sp,
            color: isScheduled
                ? const Color(0xFF7C3AED)
                : isClosed
                    ? const Color(0xFFB45309)
                    : const Color(0xFF666666),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (isScheduled)
                  Text(
                    'Scheduled delivery',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7C3AED),
                      fontFamily: 'Inter',
                    ),
                  )
                else if (isClosed)
                  Text(
                    'Store closed — next available',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB45309),
                      fontFamily: 'Inter',
                    ),
                  )
                else
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
                  isScheduled
                      ? slot.displayLabel(estimateMinutes).replaceFirst(
                          'Scheduled for ', '')
                      : isClosed
                          ? nextAvailableLabel!
                          : itemLabel,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: isScheduled || isClosed
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: isScheduled
                        ? const Color(0xFF7C3AED)
                        : isClosed
                            ? const Color(0xFFB45309)
                            : const Color(0xFF888888),
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onViewHoursTap != null)
            IconButton(
              onPressed: onViewHoursTap,
              icon: Icon(
                Icons.info_outline_rounded,
                size: 20.sp,
                color: const Color(0xFF888888),
              ),
              tooltip: 'Store hours',
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
