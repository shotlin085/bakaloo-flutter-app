import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/retro_price_badge.dart';

class ProductInfoHeader extends StatefulWidget {
  const ProductInfoHeader({
    required this.product,
    required this.isWishlisted,
    required this.onWishlistToggle,
    super.key,
  });

  final ProductEntity product;
  final bool isWishlisted;
  final VoidCallback onWishlistToggle;

  @override
  State<ProductInfoHeader> createState() => _ProductInfoHeaderState();
}

class _ProductInfoHeaderState extends State<ProductInfoHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartAnimation;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _heartAnimation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0.8),
        weight: 10,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.8, end: 1.2),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.2, end: 1),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleWishlistTap() {
    widget.onWishlistToggle();
    _heartController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final brandLabel = product.brandDisplay;
    final netQuantity = product.netQuantity?.trim() ?? '';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.all(16.w),
      child: Stack(
        children: <Widget>[
          Padding(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Wrap(
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
                    ),
                    SizedBox(width: 12.w),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PhosphorIcon(
                          PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                          size: 14.sp,
                          color: const Color(0xFF0C831F),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '17 mins',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0C831F),
                            height: 1.2,
                          ),
                        ),
                      ],
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
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleWishlistTap,
              child: AnimatedBuilder(
                animation: _heartAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _heartAnimation.value,
                  child: child,
                ),
                child: PhosphorIcon(
                  widget.isWishlisted
                      ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                      : PhosphorIcons.heart(),
                  size: 24.sp,
                  color: widget.isWishlisted
                      ? const Color(0xFFE91E63)
                      : const Color(0xFF999999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
