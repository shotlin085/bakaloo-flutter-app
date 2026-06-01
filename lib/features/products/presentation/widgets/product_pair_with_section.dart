import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/retro_price_badge.dart';

class ProductPairWithSection extends StatelessWidget {
  const ProductPairWithSection({
    required this.products,
    this.onProductTap,
    this.onSeeAll,
    this.onAddToCart,
    super.key,
  });

  final List<ProductEntity> products;
  final ValueChanged<ProductEntity>? onProductTap;
  final VoidCallback? onSeeAll;
  final ValueChanged<ProductEntity>? onAddToCart;

  @override
  Widget build(BuildContext context) {
    return ProductRecommendationsStrip(
      title: 'Pair it with',
      products: products,
      onProductTap: onProductTap,
      onSeeAll: onSeeAll,
      onAddToCart: onAddToCart,
      showVariantTag: false,
      showAdBadge: false,
    );
  }
}

class ProductRecommendationsStrip extends StatelessWidget {
  const ProductRecommendationsStrip({
    required this.title,
    required this.products,
    this.onProductTap,
    this.onSeeAll,
    this.onAddToCart,
    this.showVariantTag = false,
    this.showAdBadge = false,
    super.key,
  });

  final String title;
  final List<ProductEntity> products;
  final ValueChanged<ProductEntity>? onProductTap;
  final VoidCallback? onSeeAll;
  final ValueChanged<ProductEntity>? onAddToCart;
  final bool showVariantTag;
  final bool showAdBadge;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: EdgeInsets.only(top: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSeeAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'See all',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pdViolet,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      PhosphorIcon(
                        PhosphorIcons.caretRight(),
                        size: 14.sp,
                        color: AppColors.pdViolet,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 310.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(left: 16.w, right: 16.w),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return RepaintBoundary(
                  child: ProductRecommendationCard(
                    product: product,
                    onTap: onProductTap == null
                        ? null
                        : () => onProductTap!(product),
                    onAdd: onAddToCart == null
                        ? null
                        : () => onAddToCart!(product),
                    showVariantTag: showVariantTag,
                    showAdBadge: showAdBadge,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductRecommendationCard extends StatefulWidget {
  const ProductRecommendationCard({
    required this.product,
    this.onTap,
    this.onAdd,
    this.showVariantTag = false,
    this.showAdBadge = false,
    super.key,
  });

  final ProductEntity product;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final bool showVariantTag;
  final bool showAdBadge;

  @override
  State<ProductRecommendationCard> createState() =>
      _ProductRecommendationCardState();
}

class _ProductRecommendationCardState extends State<ProductRecommendationCard> {
  bool _isPressed = false;

  String? get _imageUrl {
    final thumbnail = widget.product.thumbnailUrl?.trim() ?? '';
    if (thumbnail.isNotEmpty) {
      return thumbnail;
    }

    for (final image in widget.product.images) {
      if (image.trim().isNotEmpty) {
        return image;
      }
    }

    return null;
  }

  String? get _variantTag {
    if (!widget.showVariantTag) {
      return null;
    }

    for (final tag in widget.product.tags) {
      final value = tag.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  int? get _variantCount {
    // Prefer the real product-family option count so the strip matches the
    // grid card's "N options" semantics; fall back to legacy attribute
    // count only when the product carries no family.
    if (widget.product.hasMultipleOptions) {
      return widget.product.optionCount;
    }
    final count = widget.product.attributes?.length ?? 0;
    return count > 1 ? count : null;
  }

  String? get _returnPolicyLabel {
    switch (widget.product.returnPolicy) {
      case 'instant':
        return 'Instant Return';
      case '7_day':
        return '7 Day Return';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final optimizedImage = ApiConstants.optimizedMedia(
      _imageUrl,
      profile: CustomerImageProfile.listProduct,
    );
    final packInfo = (widget.product.netQuantity?.trim().isNotEmpty ?? false)
        ? widget.product.netQuantity!.trim()
        : widget.product.unit;
    final variantTag = _variantTag;
    final returnPolicyLabel = _returnPolicyLabel;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          width: 165.w,
          margin: EdgeInsets.only(right: 12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFE8E8E8),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 145.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12.r),
                          ),
                        ),
                        child: _imageUrl == null
                            ? Center(
                                child: PhosphorIcon(
                                  PhosphorIcons.image(),
                                  size: 28.sp,
                                  color: const Color(0xFFBBBBBB),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: optimizedImage.url ?? _imageUrl!,
                                fit: BoxFit.contain,
                                memCacheWidth: 168,
                                memCacheHeight: 168,
                                fadeInDuration: Duration.zero,
                                filterQuality: FilterQuality.low,
                                placeholder: (context, url) => const ColoredBox(
                                  color: Color(0xFFFAFAFA),
                                  child: SizedBox.expand(),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: PhosphorIcon(
                                    PhosphorIcons.imageBroken(),
                                    size: 24.sp,
                                    color: const Color(0xFFBBBBBB),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 8.h,
                      right: 8.w,
                      child: Container(
                        width: 30.w,
                        height: 30.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.96),
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIcons.heart(),
                            size: 16.sp,
                            color: const Color(0xFF999999),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10.w,
                      bottom: -16.h,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onAdd,
                        child: Container(
                          width: 76.w,
                          height: 32.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: AppColors.pdViolet,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                'ADD',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.pdViolet,
                                  height: 1,
                                ),
                              ),
                              if (_variantCount != null)
                                Text(
                                  '${_variantCount!} options',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.pdViolet,
                                    height: 1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 22.h, 10.w, 6.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6.w,
                      runSpacing: 4.h,
                      children: <Widget>[
                        RetroPriceBadge(
                          price: widget.product.effectivePrice,
                          fontSize: 14.sp,
                        ),
                        if (widget.product.discountPercent > 0)
                          Text(
                            '₹${widget.product.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF888888),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: const Color(0xFF888888),
                            ),
                          ),
                      ],
                    ),
                    if (variantTag != null ||
                        (widget.showAdBadge && widget.product.isFeatured))
                      SizedBox(height: 6.h),
                    if (variantTag != null ||
                        (widget.showAdBadge && widget.product.isFeatured))
                      Row(
                        children: <Widget>[
                          if (variantTag != null)
                            Expanded(
                              child: Text(
                                variantTag,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.pdViolet,
                                ),
                              ),
                            ),
                          if (widget.showAdBadge && widget.product.isFeatured)
                            Text(
                              'Ad',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFFCCCCCC),
                              ),
                            ),
                        ],
                      ),
                    SizedBox(height: 6.h),
                    Text(
                      widget.product.brandDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF333333),
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      packInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF666666),
                        height: 1.2,
                      ),
                    ),
                    if (returnPolicyLabel != null) SizedBox(height: 5.h),
                    if (returnPolicyLabel != null)
                      Text(
                        returnPolicyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF0C831F),
                          height: 1.2,
                        ),
                      ),
                    if (widget.product.avgRating > 0) SizedBox(height: 5.h),
                    if (widget.product.avgRating > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          PhosphorIcon(
                            PhosphorIcons.star(PhosphorIconsStyle.fill),
                            size: 11.sp,
                            color: const Color(0xFFFFB300),
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            '${widget.product.avgRating.toStringAsFixed(1)}(${widget.product.ratingCount})',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
