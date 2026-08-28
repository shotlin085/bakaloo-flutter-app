import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_ids_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/retro_price_badge.dart';

// Watches wishlistIdsProvider itself (rather than taking isWishlisted from
// the parent screen's build) so a wishlist toggle only rebuilds this small
// header, not the whole product-detail page (gallery, banner, variant
// selector, ...) that was previously watching the same provider up top.
//
// The heart's pop used to run on a hand-rolled AnimationController +
// TweenSequence + Curves.elasticOut, driving a raw Transform.scale — that
// combination is exactly what produced a grey flash over the price/name
// block next to it on every tap (reported, reproduced, and measured from a
// screen recording). Curves.elasticOut deliberately overshoots past its
// [0, 1] range, and feeding that into a TweenSequence built for that exact
// range let the icon's transform spike outside its expected bounds for a
// frame, forcing an unwanted repaint of everything sharing its compositing
// layer. Replaced with AnimatedSwitcher + ScaleTransition -- Flutter's own
// built-in "swap this child for that one" widget, keyed on isWishlisted, no
// custom AnimationController/TweenSequence to get wrong.
class ProductInfoHeader extends ConsumerWidget {
  const ProductInfoHeader({
    required this.product,
    required this.onWishlistToggle,
    super.key,
  });

  final ProductEntity product;
  final VoidCallback onWishlistToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWishlisted = ref.watch(
      wishlistIdsProvider.select((ids) => ids.contains(product.id)),
    );
    final brandLabel = product.brandDisplay;
    final netQuantity = product.netQuantity?.trim() ?? '';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.all(16.w),
      child: Stack(
        children: <Widget>[
          // Own RepaintBoundary so a wishlist toggle's repaint of the heart
          // (below) never forces this text block to recomposite alongside
          // it, and vice versa.
          RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(right: 42.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (brandLabel.isNotEmpty)
                    Text(
                      brandLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                        height: 1.2,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: const Color(0xFFBBBBBB),
                      ),
                    ),
                  if (brandLabel.isNotEmpty) SizedBox(height: 6.h),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF333333),
                      height: 1.35,
                    ),
                  ),
                  if (netQuantity.isNotEmpty) SizedBox(height: 10.h),
                  if (netQuantity.isNotEmpty)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: 'Net Qty: ',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF666666),
                                height: 1.2,
                              ),
                            ),
                            TextSpan(
                              text: netQuantity,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF333333),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 12.h),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8.w,
                    runSpacing: 6.h,
                    children: <Widget>[
                      RetroPriceBadge(price: product.effectivePrice),
                      if (product.discountPercent > 0)
                        Text(
                          '${product.discountPercent}% Off',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0C831F),
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                  if (product.isOnSale) ...<Widget>[
                    SizedBox(height: 6.h),
                    RichText(
                      text: TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '₹${product.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF999999),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: const Color(0xFF999999),
                              height: 1.2,
                            ),
                          ),
                          TextSpan(
                            text: ' MRP (incl. of all taxes)',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF999999),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            // Own RepaintBoundary so a wishlist toggle only re-rasterizes
            // this small icon's layer — paired with the text block's own
            // boundary above, so neither one's repaint forces the other
            // to recomposite together.
            child: RepaintBoundary(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onWishlistToggle,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: PhosphorIcon(
                    isWishlisted
                        ? PhosphorIcons.heartFill
                        : PhosphorIcons.heart,
                    key: ValueKey<bool>(isWishlisted),
                    size: 24.sp,
                    color: AppColors.pdViolet,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
