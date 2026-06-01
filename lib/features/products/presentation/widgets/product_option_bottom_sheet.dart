import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_options_response.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_options_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

class ProductOptionBottomSheet extends ConsumerWidget {
  const ProductOptionBottomSheet({
    required this.product,
    super.key,
  });

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(productOptionsProvider(product.id));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildHandle(),
          optionsAsync.when(
            loading: () => _buildLoading(),
            error: (error, _) => _buildError(context, ref, error),
            data: (response) => _buildContent(context, ref, response),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
      child: Center(
        child: Container(
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Container(
              height: 64.h,
              decoration: BoxDecoration(
                color: AppColors.bgSkeleton,
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(
            PhosphorIcons.warningCircle(),
            size: 40.sp,
            color: AppColors.textTertiary,
          ),
          Gap(12.h),
          Text(
            'Unable to load options',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(16.h),
          TextButton(
            onPressed: () => ref.invalidate(productOptionsProvider(product.id)),
            child: Text(
              'Retry',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ProductOptionsResponse response,
  ) {
    final familyName =
        response.family?.name ?? product.familyName ?? product.name;

    if (response.options.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.package(),
              size: 40.sp,
              color: AppColors.textTertiary,
            ),
            Gap(12.h),
            Text(
              'No options available',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
            child: Text(
              familyName,
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
              itemCount: response.options.length,
              separatorBuilder: (_, __) => Gap(8.h),
              itemBuilder: (context, index) {
                final option = response.options[index];
                return _OptionRow(option: option);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends ConsumerWidget {
  const _OptionRow({required this.option});

  final ProductOptionItem option;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartItemQuantityProvider(option.id));
    final isDisabled = !option.inStock;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: <Widget>[
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: SizedBox(
                width: 48.w,
                height: 48.w,
                child: option.thumbnailUrl != null
                    ? AppImage(
                        imageUrl: option.thumbnailUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 96,
                        memCacheHeight: 96,
                      )
                    : Container(
                        color: const Color(0xFFF5F5F5),
                        child: Icon(
                          Icons.image_outlined,
                          size: 20.sp,
                          color: AppColors.textDisabled,
                        ),
                      ),
              ),
            ),
            Gap(12.w),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (option.hasFoodMarker) ...<Widget>[
                        _FoodMarkerDot(option: option),
                        Gap(4.w),
                      ],
                      Expanded(
                        child: Text(
                          option.displayUnit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap(4.h),
                  _PriceRow(option: option),
                ],
              ),
            ),
            Gap(12.w),
            // Cart button
            if (!isDisabled)
              _CartActionButton(option: option, quantity: quantity),
            if (isDisabled)
              Text(
                'Unavailable',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FoodMarkerDot extends StatelessWidget {
  const _FoodMarkerDot({required this.option});

  final ProductOptionItem option;

  @override
  Widget build(BuildContext context) {
    final color = option.isVeg
        ? AppColors.vegGreen
        : option.isNonVeg
            ? AppColors.nonVegRed
            : const Color(0xFFF9A825);

    return Container(
      width: 12.w,
      height: 12.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 6.w,
        height: 6.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.option});

  final ProductOptionItem option;

  @override
  Widget build(BuildContext context) {
    final isOnSale =
        option.salePrice != null && option.salePrice! < option.price;

    return Row(
      children: <Widget>[
        Text(
          '₹${option.effectivePrice.toInt()}',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (isOnSale) ...<Widget>[
          Gap(6.w),
          Text(
            '₹${option.price.toInt()}',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textTertiary,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textTertiary,
            ),
          ),
          Gap(6.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              '${option.discountPercent}% OFF',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CartActionButton extends ConsumerWidget {
  const _CartActionButton({
    required this.option,
    required this.quantity,
  });

  final ProductOptionItem option;
  final int quantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (quantity > 0) {
      return _QuantityStepper(option: option, quantity: quantity);
    }

    return SizedBox(
      height: 32.h,
      child: ElevatedButton(
        onPressed: () async {
          final result = await ref.read(cartProvider.notifier).addItem(
                option.id,
                1,
                shopProductId: option.shopProductId,
              );
          if (!context.mounted || result.isSuccess) return;
          showCartSnackBar(context, result.failure!.message);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          'ADD',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({
    required this.option,
    required this.quantity,
  });

  final ProductOptionItem option;
  final int quantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 32.h,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () async {
              if (quantity == 1) {
                final result = await ref
                    .read(cartProvider.notifier)
                    .removeItem(
                      option.id,
                      shopProductId: option.shopProductId,
                    );
                if (!context.mounted || result.isSuccess) return;
                showCartSnackBar(context, result.failure!.message);
                return;
              }
              final result = await ref
                  .read(cartProvider.notifier)
                  .updateItem(
                    option.id,
                    quantity - 1,
                    shopProductId: option.shopProductId,
                  );
              if (!context.mounted || result.isSuccess) return;
              showCartSnackBar(context, result.failure!.message);
            },
            child: SizedBox(
              width: 28.w,
              height: 32.h,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.minus(),
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 18.w,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
              ),
            ),
          ),
          InkWell(
            onTap: () async {
              if (quantity >= (option.maxOrderQty ?? 50)) return;
              final result = await ref
                  .read(cartProvider.notifier)
                  .updateItem(
                    option.id,
                    quantity + 1,
                    shopProductId: option.shopProductId,
                  );
              if (!context.mounted || result.isSuccess) return;
              showCartSnackBar(context, result.failure!.message);
            },
            child: SizedBox(
              width: 28.w,
              height: 32.h,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.plus(),
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
