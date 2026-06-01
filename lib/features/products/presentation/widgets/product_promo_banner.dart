import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProductPromoBanner extends StatelessWidget {
  const ProductPromoBanner({
    required this.scrollOffset,
    super.key,
  });

  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64.h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF6A1B9A),
            Color(0xFF7B1FA2),
            Color(0xFF9C27B0),
          ],
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: <Widget>[
            // Faint brand watermark on the right.
            Positioned(
              right: -8.w,
              top: -6.h,
              bottom: -6.h,
              child: Transform.translate(
                offset: Offset(scrollOffset * 0.12, 0),
                child: Text(
                  'B',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 72.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.12),
                    height: 1,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIcons.scooter(PhosphorIconsStyle.fill),
                    size: 26.sp,
                    color: Colors.white,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Fast groceries. Happy you.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        RichText(
                          text: TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: 'Delivered in minutes with ',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  height: 1.2,
                                ),
                              ),
                              TextSpan(
                                text: 'Bakaloo',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFFD54F),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
