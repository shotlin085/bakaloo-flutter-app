import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_option_bottom_sheet.dart';

void showProductOptionsSheet(BuildContext context, ProductEntity product) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(right: 16.w, bottom: 10.h),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              onTap: () => Navigator.of(sheetContext).pop(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: PhosphorIcon(
                  PhosphorIcons.x(PhosphorIconsStyle.bold),
                  size: 18.sp,
                  color: const Color(0xFF222222),
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
