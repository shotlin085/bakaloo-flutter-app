import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_option_bottom_sheet.dart';

/// Opens the variant option sheet for [product].
///
/// Matches the reference workflow: a dark dimmed overlay, a floating circular
/// close (X) button centred above the rounded-top sheet, then the option list.
void showProductOptionsSheet(BuildContext context, ProductEntity product) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Floating circular close button, centred above the sheet.
        Padding(
          padding: EdgeInsets.only(bottom: 14.h),
          child: Material(
            color: const Color(0xFF3A3A3A),
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              onTap: () => Navigator.of(sheetContext).pop(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(9.w),
                child: PhosphorIcon(
                  PhosphorIcons.x(PhosphorIconsStyle.bold),
                  size: 18.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        ProductOptionBottomSheet(product: product),
      ],
    ),
  );
}
