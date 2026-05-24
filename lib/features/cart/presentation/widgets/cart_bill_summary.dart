import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';

class CartBillSummary extends StatelessWidget {
  const CartBillSummary({required this.summary, super.key});

  final BillSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIcons.receipt(),
                    size: 18.sp,
                    color: const Color(0xFF222222),
                  ),
                  Gap(8.w),
                  Text(
                    'Bill Summary',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF222222),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              Gap(16.h),
              _BillRow(
                label: 'Item Total',
                originalAmount:
                    summary.itemTotal.original != summary.itemTotal.discounted
                        ? summary.itemTotal.original
                        : null,
                amount: summary.itemTotal.discounted,
              ),
              Gap(14.h),
              _BillRow(
                label: 'Delivery Fee',
                amount: summary.deliveryFee.amount,
                isFree: summary.deliveryFee.isFree,
              ),
              if (!summary.deliveryFee.isFree &&
                  summary.deliveryFee.freeIn > 0) ...<Widget>[
                Gap(6.h),
                Text(
                  'Add products worth ₹${summary.deliveryFee.freeIn.toStringAsFixed(0)} to get free delivery',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0AC26B),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
              Gap(14.h),
              _BillRow(
                label: 'Handling Fee',
                originalAmount: summary.handlingFee.isFree &&
                        summary.handlingFee.savedAmount > 0
                    ? summary.handlingFee.savedAmount
                    : null,
                amount: summary.handlingFee.amount,
                isFree: summary.handlingFee.isFree,
              ),
              Gap(14.h),
              _BillRow(
                label: 'Late Night Fee',
                originalAmount: summary.lateNightFee.isFree &&
                        summary.lateNightFee.savedAmount > 0
                    ? summary.lateNightFee.savedAmount
                    : null,
                amount: summary.lateNightFee.amount,
                isFree: summary.lateNightFee.isFree,
              ),
              if (summary.tipAmount > 0) ...<Widget>[
                Gap(14.h),
                _BillRow(
                  label: 'Partner Tip',
                  amount: summary.tipAmount,
                ),
              ],
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0F0F0),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'To Pay',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF222222),
                      fontFamily: 'Inter',
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      if (summary.toPay.original !=
                          summary.toPay.finalAmount) ...<Widget>[
                        Text(
                          '₹${summary.toPay.original.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF999999),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFF999999),
                            fontFamily: 'Inter',
                          ),
                        ),
                        Gap(8.w),
                      ],
                      Text(
                        '₹${summary.toPay.finalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF222222),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.amount,
    this.originalAmount,
    this.isFree = false,
  });

  final String label;
  final double amount;
  final double? originalAmount;
  final bool isFree;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF666666),
              fontFamily: 'Inter',
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          originalAmount != null && originalAmount! > 0
              ? '₹${originalAmount!.toStringAsFixed(0)}'
              : '',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF999999),
            decoration: TextDecoration.lineThrough,
            decorationColor: const Color(0xFF999999),
            fontFamily: 'Inter',
          ),
        ),
        if (originalAmount != null && originalAmount! > 0) Gap(8.w),
        Text(
          isFree ? 'FREE' : '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: isFree ? const Color(0xFF0AC26B) : const Color(0xFF222222),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
