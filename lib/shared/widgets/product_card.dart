import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

/// Layout of the card — grid (vertical lists) vs scroll (horizontal rails).
enum ProductCardStyle { grid, scroll }

/// Visual design variant of the product card, admin-configurable per section
/// (and globally) from the dashboard theme builder.
///
///   * [quickCommerceCompact] — the premium quick-commerce reference design
///     (price sticker, dashed discount line, rating/delivery rows). DEFAULT.
///   * [bakalooLegacyClean]  — the older, simpler/flatter card (plain price
///     text, minimal chrome). Kept so admins can opt back into the classic
///     look without a new widget.
enum ProductCardVariant { quickCommerceCompact, bakalooLegacyClean }

/// Resolve a [ProductCardVariant] from a backend config string.
///
/// Accepts the canonical UPPER_SNAKE tokens persisted by the dashboard
/// (`QUICK_COMMERCE_COMPACT`, `BAKALOO_LEGACY_CLEAN`). Any unknown / null /
/// empty value falls back to [ProductCardVariant.quickCommerceCompact] so old
/// themes and forward-incompatible values render the default safely.
ProductCardVariant productCardVariantFromString(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'BAKALOO_LEGACY_CLEAN':
      return ProductCardVariant.bakalooLegacyClean;
    case 'QUICK_COMMERCE_COMPACT':
      return ProductCardVariant.quickCommerceCompact;
    default:
      return ProductCardVariant.quickCommerceCompact;
  }
}

class ProductCard extends StatefulWidget {
  const ProductCard({
    required this.product,
    this.width = AppDimensions.productCardWidth,
    this.style,
    this.variant = ProductCardVariant.quickCommerceCompact,
    this.showWishlist = false,
    this.onTap,
    this.onAdd,
    this.onOptionsTap,
    super.key,
  });

  final ProductEntity product;
  final double width;
  final ProductCardStyle? style;

  /// Visual design variant. Defaults to the premium quick-commerce card.
  final ProductCardVariant variant;
  final bool showWishlist;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onOptionsTap;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final style = widget.style ?? _inferStyle(context);
    final isGridStyle = style == ProductCardStyle.grid;
    final compactGrid = isGridStyle && widget.width < 126;
    final tightGrid = isGridStyle && widget.width < 112;
    final cardWidth = widget.width.w;
    final imageHeight = cardWidth * (isGridStyle ? 0.96 : 0.88);
    final contentPadding = tightGrid ? 8.w : 10.w;
    final priceFontSize = tightGrid ? 12.sp : 14.sp;
    final comparePriceFontSize = tightGrid ? 10.sp : 12.sp;
    final titleFontSize = tightGrid ? 11.6.sp : 12.8.sp;
    final unitFontSize = tightGrid ? 10.sp : 10.8.sp;
    final offFontSize = tightGrid ? 10.sp : 11.sp;
    final imageUrl = product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);
    final optimizedImage = ApiConstants.optimizedMedia(
      imageUrl,
      profile: CustomerImageProfile.listProduct,
    );

    final effectivePrice = product.salePrice ?? product.price;
    final isOnSale =
        product.salePrice != null && product.salePrice! < product.price;
    final offAmount =
        isOnSale ? (product.price - product.salePrice!).toInt() : null;

    return Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: SizedBox(
              width: cardWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: const Color(0xFFE8E8E8),
                    width: 0.8,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: Stack(
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            height: imageHeight,
                            width: double.infinity,
                            child: Stack(
                              children: <Widget>[
                                Positioned.fill(
                                  child: imageUrl == null || imageUrl.isEmpty
                                      ? const ColoredBox(
                                          color: Color(0xFFFAFAFA),
                                          child: Center(
                                            child: Icon(
                                              Icons.image_outlined,
                                              color: AppColors.textDisabled,
                                              size: 28,
                                            ),
                                          ),
                                        )
                                      : AppImage(
                                          imageUrl:
                                              optimizedImage.url ?? imageUrl,
                                          memCacheWidth:
                                              optimizedImage.memCacheWidth,
                                          memCacheHeight:
                                              optimizedImage.memCacheHeight,
                                          fit: BoxFit.cover,
                                          filterQuality: FilterQuality.low,
                                          placeholder: const ColoredBox(
                                            color: Color(0xFFFAFAFA),
                                            child: SizedBox.expand(),
                                          ),
                                          errorWidget: const ColoredBox(
                                            color: Color(0xFFFAFAFA),
                                            child: Center(
                                              child: Icon(
                                                Icons.broken_image_outlined,
                                                color: AppColors.textDisabled,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                                if (widget.showWishlist)
                                  Positioned(
                                    top: 8.h,
                                    right: 8.w,
                                    child: _IsolatedWishlistButton(
                                      product: product,
                                      showWishlist: widget.showWishlist,
                                    ),
                                  ),
                                // Origin badge (top-left)
                                if (product.hasOriginTag && product.isImported)
                                  Positioned(
                                    top: 6.h,
                                    left: 6.w,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 5.w,
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(4.r),
                                        border: Border.all(
                                          color: const Color(0xFFFFB74D),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'Imported',
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFE65100),
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Food marker (top-right under wishlist)
                                if (product.hasFoodMarker)
                                  Positioned(
                                    top: widget.showWishlist ? 34.h : 6.h,
                                    right: 8.w,
                                    child: Container(
                                      width: 16.w,
                                      height: 16.w,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(3.r),
                                        border: Border.all(
                                          color: product.isVeg
                                              ? const Color(0xFF2E7D32)
                                              : product.isNonVeg
                                                  ? const Color(0xFFC62828)
                                                  : const Color(0xFFF9A825),
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 8.w,
                                        height: 8.w,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: product.isVeg
                                              ? const Color(0xFF2E7D32)
                                              : product.isNonVeg
                                                  ? const Color(0xFFC62828)
                                                  : const Color(0xFFF9A825),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  right: tightGrid ? 6.w : 8.w,
                                  bottom: tightGrid ? 6.h : 8.h,
                                  child: _IsolatedCartButton(
                                    style: style,
                                    compact: compactGrid,
                                    tight: tightGrid,
                                    product: product,
                                    onAdd: widget.onAdd,
                                    onOptionsTap: widget.onOptionsTap,
                                  ),
                                ),
                                // Weight / unit chip (bottom-left on image)
                                if (product.displayUnit.trim().isNotEmpty)
                                  Positioned(
                                    left: tightGrid ? 6.w : 8.w,
                                    bottom: tightGrid ? 6.h : 8.h,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: tightGrid ? 6.w : 8.w,
                                        vertical: tightGrid ? 2.h : 3.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(6.r),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        product.displayUnit,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: unitFontSize,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF3A3A3A),
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              contentPadding,
                              6.h,
                              contentPadding,
                              0,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  '₹${effectivePrice.toInt()}',
                                  style: TextStyle(
                                    fontSize: priceFontSize + 2,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1A1A1A),
                                    height: 1.1,
                                  ),
                                ),
                                if (isOnSale) ...<Widget>[
                                  Gap(tightGrid ? 4.w : 6.w),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '₹${product.price.toInt()}',
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: comparePriceFontSize,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF999999),
                                            decoration:
                                                TextDecoration.lineThrough,
                                            decorationColor:
                                                const Color(0xFF999999),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (offAmount != null && offAmount > 0)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                contentPadding,
                                3.h,
                                contentPadding,
                                0,
                              ),
                              child: Text(
                                product.discountPercent > 0
                                    ? '${product.discountPercent}% OFF on MRP'
                                    : '₹$offAmount OFF',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: offFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2B7FFF),
                                ),
                              ),
                            ),
                          Gap(4.h),
                          Flexible(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: contentPadding,
                              ),
                              child: Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelLarge.copyWith(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  color: const Color(0xFF222222),
                                ),
                              ),
                            ),
                          ),
                          // Rating row
                          if (product.hasRating)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                contentPadding,
                                3.h,
                                contentPadding,
                                0,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.star_rounded,
                                    size: 12.sp,
                                    color: const Color(0xFFFFA000),
                                  ),
                                  Gap(2.w),
                                  Expanded(
                                    child: Text(
                                      product.formattedRating,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF666666),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Delivery time row
                          if (product.hasDeliveryTime)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                contentPadding,
                                2.h,
                                contentPadding,
                                0,
                              ),
                              child: Row(
                                children: <Widget>[
                                  PhosphorIcon(
                                    PhosphorIcons.clock(),
                                    size: 11.sp,
                                    color: const Color(0xFF888888),
                                  ),
                                  Gap(3.w),
                                  Text(
                                    product.formattedDeliveryTime,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFF888888),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Gap(6.h),
                        ],
                      ),
                      if (!product.inStock)
                        Positioned.fill(
                          child: Container(
                            color: AppColors.overlayLight,
                            alignment: Alignment.center,
                            child: Text(
                              'Out of stock',
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.outOfStockRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ProductCardStyle _inferStyle(BuildContext context) {
    final axisDirection = Scrollable.maybeOf(context)?.widget.axisDirection;
    if (axisDirection == AxisDirection.left ||
        axisDirection == AxisDirection.right) {
      return ProductCardStyle.scroll;
    }
    return ProductCardStyle.grid;
  }
}

/// Isolated Consumer wrapper: only this widget rebuilds on wishlist changes.
class _IsolatedWishlistButton extends ConsumerWidget {
  const _IsolatedWishlistButton({
    required this.product,
    required this.showWishlist,
  });

  final ProductEntity product;
  final bool showWishlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showWishlist) return const SizedBox.shrink();

    final isWishlisted = ref.watch(
      wishlistProvider.select(
        (wishlistAsync) => switch (wishlistAsync) {
          AsyncData(:final value) => value.items.any(
              (item) => item.productId == product.id,
            ),
          _ => false,
        },
      ),
    );
    final authGate = ref.read(authGateControllerProvider);

    return _WishlistButton(
      product: product,
      isWishlisted: isWishlisted,
      authGate: authGate,
    );
  }
}

class _WishlistButton extends ConsumerWidget {
  const _WishlistButton({
    required this.product,
    required this.isWishlisted,
    required this.authGate,
  });

  final ProductEntity product;
  final bool isWishlisted;
  final AuthGateController authGate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () async {
          final allowed = await authGate.protectWishlist(context, product);
          if (!allowed || !context.mounted) return;
          final result =
              await ref.read(wishlistProvider.notifier).toggleWishlist(product);
          if (!context.mounted || result.isSuccess) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.failure!.message),
            ),
          );
        },
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: PhosphorIcon(
            PhosphorIcons.heart(
              isWishlisted
                  ? PhosphorIconsStyle.fill
                  : PhosphorIconsStyle.regular,
            ),
            size: 18,
            color: isWishlisted ? AppColors.errorRed : const Color(0xFF606060),
          ),
        ),
      ),
    );
  }
}

/// Isolated Consumer wrapper: only this widget rebuilds on cart changes.
class _IsolatedCartButton extends ConsumerWidget {
  const _IsolatedCartButton({
    required this.style,
    required this.compact,
    required this.tight,
    required this.product,
    this.onAdd,
    this.onOptionsTap,
  });

  final ProductCardStyle style;
  final bool compact;
  final bool tight;
  final ProductEntity product;
  final VoidCallback? onAdd;
  final VoidCallback? onOptionsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartItemQuantityProvider(product.id));
    final authGate = ref.read(authGateControllerProvider);

    return _ZeptoAddQtyButton(
      style: style,
      compact: compact,
      tight: tight,
      quantity: quantity,
      product: product,
      authGate: authGate,
      onAdd: onAdd,
      onOptionsTap: onOptionsTap,
    );
  }
}

class _ZeptoAddQtyButton extends ConsumerWidget {
  const _ZeptoAddQtyButton({
    required this.style,
    required this.compact,
    required this.tight,
    required this.quantity,
    required this.product,
    required this.authGate,
    this.onAdd,
    this.onOptionsTap,
  });

  final ProductCardStyle style;
  final bool compact;
  final bool tight;
  final int quantity;
  final ProductEntity product;
  final AuthGateController authGate;
  final VoidCallback? onAdd;
  final VoidCallback? onOptionsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const pinkBorder = AppColors.primaryGreen;
    final buttonHeight = tight ? 30.h : 32.h;
    final gridButtonWidth = tight
        ? 58.w
        : compact
            ? 66.w
            : 76.w;
    final controlWidth = tight ? 24.w : 28.w;
    final quantityWidth = tight ? 16.w : 18.w;
    final iconSize = tight ? 13.0 : 14.0;
    final addFontSize = tight
        ? 11.5.sp
        : compact
            ? 12.sp
            : 13.sp;

    if (quantity > 0) {
      return Container(
        height: buttonHeight,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: () async {
                if (quantity == 1) {
                  final result = await ref
                      .read(cartProvider.notifier)
                      .removeItem(product.id);
                  if (!context.mounted || result.isSuccess) return;
                  showCartSnackBar(context, result.failure!.message);
                  return;
                }
                final result = await ref
                    .read(cartProvider.notifier)
                    .updateItem(product.id, quantity - 1);
                if (!context.mounted || result.isSuccess) return;
                showCartSnackBar(context, result.failure!.message);
              },
              child: SizedBox(
                width: controlWidth,
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.minus(),
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: quantityWidth,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: tight ? 12.sp : 14.sp,
                ),
              ),
            ),
            InkWell(
              onTap: () async {
                if (quantity >= 50) return;
                final result = await ref
                    .read(cartProvider.notifier)
                    .updateItem(product.id, quantity + 1);
                if (!context.mounted || result.isSuccess) return;
                showCartSnackBar(context, result.failure!.message);
              },
              child: SizedBox(
                width: controlWidth,
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.plus(),
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            child: InkWell(
              onTap: product.inStock
                  ? () async {
                      // If product has multiple options, open options sheet
                      if (product.hasMultipleOptions && onOptionsTap != null) {
                        onOptionsTap!.call();
                        return;
                      }
                      final allowed = await authGate.protectAddToCart(
                        context,
                        product,
                      );
                      if (!allowed || !context.mounted) return;
                      final result = await ref
                          .read(cartProvider.notifier)
                          .addItem(product.id, 1, product: product);
                      if (!context.mounted) return;
                      if (!result.isSuccess) {
                        showCartSnackBar(context, result.failure!.message);
                        return;
                      }
                      onAdd?.call();
                    }
                  : null,
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                height: buttonHeight,
                width:
                    style == ProductCardStyle.grid ? gridButtonWidth : buttonHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: pinkBorder, width: 1.5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                alignment: Alignment.center,
                child: style == ProductCardStyle.grid
                    ? Text(
                        'ADD',
                        style: TextStyle(
                          color: pinkBorder,
                          fontWeight: FontWeight.w700,
                          fontSize: addFontSize,
                        ),
                      )
                    : PhosphorIcon(
                        PhosphorIcons.plus(PhosphorIconsStyle.bold),
                        size: tight ? 15.0 : 18.0,
                        color: pinkBorder,
                      ),
              ),
            ),
          ),
        ),
        // "N options" label below ADD button
        if (product.hasMultipleOptions)
          Padding(
            padding: EdgeInsets.only(top: 3.h),
            child: Text(
              '${product.optionCount} options',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF888888),
                height: 1.1,
              ),
            ),
          ),
      ],
    );
  }
}
