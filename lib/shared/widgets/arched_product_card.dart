import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:bakaloo_flutter_app/shared/widgets/arched_top_box_clipper.dart';

class ArchedProductCard extends StatefulWidget {
  const ArchedProductCard({
    required this.product,
    required this.backgroundColor,
    this.cardShape = 'arch',
    this.archHeight = 14.0,
    this.cornerRadius = 24.0,
    this.boxGradientColors,
    this.width = 148,
    this.onTap,
    super.key,
  });

  final ProductEntity product;
  final Color backgroundColor;
  final String cardShape;
  final double archHeight;
  final double cornerRadius;
  final List<Color>? boxGradientColors;
  final double width;
  final VoidCallback? onTap;

  @override
  State<ArchedProductCard> createState() => _ArchedProductCardState();
}

class _ArchedProductCardState extends State<ArchedProductCard> {
  bool _isPressed = false;
  bool _suppressCardTap = false;

  void _handleTapDown(
    TapDownDetails details,
    double cardWidth,
    double cardHeight,
  ) {
    final localPosition = details.localPosition;
    final tappedControlArea = localPosition.dy >= cardHeight - 92.h;
    _suppressCardTap = tappedControlArea;
    if (tappedControlArea) {
      return;
    }

    setState(() => _isPressed = true);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cardWidth = widget.width.w;
    final imageHeight = cardWidth * 0.9;
    final cardHeight = imageHeight + 122.h;
    final effectivePrice = product.salePrice ?? product.price;
    final isOnSale =
        product.salePrice != null && product.salePrice! < product.price;
    final discountPercent = isOnSale ? product.discountPercent : null;
    final isWaveShape = widget.cardShape == 'wave';
    final archOffset = isWaveShape ? 0.0 : widget.archHeight;
    final cardDecoration = BoxDecoration(
      color: widget.boxGradientColors == null ? widget.backgroundColor : null,
      gradient: widget.boxGradientColors != null
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.boxGradientColors!,
            )
          : null,
      borderRadius:
          isWaveShape ? BorderRadius.circular(widget.cornerRadius.r) : null,
    );

    Widget cardContainer;
    if (isWaveShape) {
      cardContainer = ClipRRect(
        borderRadius: BorderRadius.circular(widget.cornerRadius.r),
        child: DecoratedBox(
          decoration: cardDecoration,
          child: _buildCardContent(
            product: product,
            imageHeight: imageHeight,
            archOffset: archOffset,
            effectivePrice: effectivePrice,
            isOnSale: isOnSale,
            discountPercent: discountPercent,
          ),
        ),
      );
    } else {
      cardContainer = ClipPath(
        clipper: ArchedTopBoxClipper(
          radius: widget.cornerRadius,
          archHeight: widget.archHeight,
        ),
        child: DecoratedBox(
          decoration: cardDecoration,
          child: _buildCardContent(
            product: product,
            imageHeight: imageHeight,
            archOffset: archOffset,
            effectivePrice: effectivePrice,
            isOnSale: isOnSale,
            discountPercent: discountPercent,
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (details) => _handleTapDown(details, cardWidth, cardHeight),
      onTapUp: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      onTapCancel: () {
        _suppressCardTap = false;
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      onTap: () {
        if (_suppressCardTap) {
          _suppressCardTap = false;
          return;
        }
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: cardContainer,
        ),
      ),
    );
  }

  Widget _buildCardContent({
    required ProductEntity product,
    required double imageHeight,
    required double archOffset,
    required double effectivePrice,
    required bool isOnSale,
    required int? discountPercent,
  }) {
    final imageUrl = product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);
    final optimizedImage = ApiConstants.optimizedMedia(
      imageUrl,
      profile: CustomerImageProfile.listProduct,
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: imageHeight + widget.archHeight,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12.w,
                        archOffset + 4.h,
                        12.w,
                        0,
                      ),
                      child: imageUrl == null || imageUrl.isEmpty
                          ? Center(
                              child: PhosphorIcon(
                                PhosphorIcons.image(),
                                color: AppColors.textDisabled,
                                size: 32,
                              ),
                            )
                          : AppImage(
                              imageUrl: optimizedImage.url ?? imageUrl,
                              memCacheWidth: optimizedImage.memCacheWidth,
                              memCacheHeight: optimizedImage.memCacheHeight,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.low,
                              placeholder: const SizedBox.expand(),
                              errorWidget: Center(
                                child: PhosphorIcon(
                                  PhosphorIcons.imageBroken(),
                                  color: AppColors.textDisabled,
                                  size: 28,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (discountPercent != null)
                    Positioned(
                      top: archOffset + 1.h,
                      left: 5.w,
                      child: SizedBox(
                        width: 46.w,
                        height: 46.w,
                        child: ClipPath(
                          clipper: const _ArchedDiscountBurstClipper(),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Color(0xFFFFA16F),
                                  Color(0xFFFF784E),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${discountPercent.toInt()}%\nOFF',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 3.h,
                    right: 8.w,
                    child: PhosphorIcon(
                      PhosphorIcons.heart(PhosphorIconsStyle.regular),
                      size: 18,
                      color: const Color(0xFFE04A86),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(11.w, 1.h, 11.w, 0),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.2.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.22,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(11.w, 1.h, 11.w, 0),
              child: Text(
                product.unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF7F7F7F),
                  fontSize: 11.4.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Padding(
              padding: EdgeInsets.fromLTRB(11.w, 0, 9.w, 8.h),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '₹ ${effectivePrice.toInt()}',
                            style: TextStyle(
                              fontSize: 18.2.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1A1A1A),
                              height: 1.1,
                            ),
                          ),
                          if (isOnSale)
                            Text(
                              '₹${product.price.toInt()}',
                              style: TextStyle(
                                fontSize: 12.6.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF999999),
                                decoration: TextDecoration.lineThrough,
                                decorationColor: const Color(0xFF999999),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _IsolatedArchedAddButton(
                      product: product,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!product.inStock)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(widget.cornerRadius.r),
              ),
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                  ),
                ),
                child: Text(
                  'Out of stock',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE53935),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Isolated Consumer wrapper: only this widget rebuilds on cart changes.
class _IsolatedArchedAddButton extends ConsumerWidget {
  const _IsolatedArchedAddButton({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartItemQuantityProvider(product.id));
    final authGate = ref.read(authGateControllerProvider);

    return _ArchedAddButton(
      quantity: quantity,
      product: product,
      authGate: authGate,
    );
  }
}

class _ArchedAddButton extends ConsumerWidget {
  const _ArchedAddButton({
    required this.quantity,
    required this.product,
    required this.authGate,
  });

  final int quantity;
  final ProductEntity product;
  final AuthGateController authGate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (quantity > 0) {
      return Container(
        height: 34.h,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: product.inStock
                  ? () async {
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
                    }
                  : null,
              child: SizedBox(
                width: 28.w,
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
                  fontSize: 14.sp,
                ),
              ),
            ),
            InkWell(
              onTap: product.inStock
                  ? () async {
                      if (quantity >= 50) return;
                      final result = await ref
                          .read(cartProvider.notifier)
                          .updateItem(product.id, quantity + 1);
                      if (!context.mounted || result.isSuccess) return;
                      showCartSnackBar(context, result.failure!.message);
                    }
                  : null,
              child: SizedBox(
                width: 28.w,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: product.inStock
            ? () async {
                // Multi-option products open the option sheet instead of
                // adding directly, so the customer picks the exact option.
                if (product.hasMultipleOptions) {
                  showProductOptionsSheet(context, product);
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
                if (!context.mounted || result.isSuccess) return;
                showCartSnackBar(context, result.failure!.message);
              }
            : null,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          width: 72.w,
          height: 36.h,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFCD2D55),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0xFFCD2D55),
                offset: Offset(2, 3),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'ADD',
                style: TextStyle(
                  color: const Color(0xFFCD2D55),
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                  height: 1.0,
                ),
              ),
              // "N options" sits INSIDE the fixed-size ADD button so the
              // arched showcase card height never changes (no overflow).
              if (product.hasMultipleOptions)
                Text(
                  '${product.optionCount} options',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFCD2D55),
                    height: 1.0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchedDiscountBurstClipper extends CustomClipper<Path> {
  const _ArchedDiscountBurstClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.76;
    const pointCount = 12;

    for (var index = 0; index < pointCount * 2; index++) {
      final radius = index.isEven ? outerRadius : innerRadius;
      final angle = (math.pi / pointCount) * index - (math.pi / 2);
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
