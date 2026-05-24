import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RetroPriceBadge extends StatelessWidget {
  const RetroPriceBadge({
    required this.price,
    this.fontSize,
    super.key,
  });

  final double price;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0C831F),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: const Color(0xFF000000),
          width: 2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xFF000000),
            blurRadius: 0,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Text(
        '₹${price.toStringAsFixed(0)}',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize ?? 18.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}
