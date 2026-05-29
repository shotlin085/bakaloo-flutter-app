import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';

class CartItemCard extends StatelessWidget {
  const CartItemCard({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    super.key,
  });

  final CartItemEntity item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = item.salePrice != null && item.salePrice! < item.price;
    final effectivePrice = hasDiscount ? item.salePrice! : item.price;

    return Slidable(
      key: ValueKey<String>(item.productId),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.24,
        children: <Widget>[
          SlidableAction(
            onPressed: (_) => onRemove(),
            backgroundColor: AppColors.errorRed,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
          ),
        ],
      ),
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: SizedBox(
                width: 64.w,
                height: 64.w,
                child:
                    item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.thumbnailUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 128,
                            memCacheHeight: 128,
                            fadeInDuration: const Duration(milliseconds: 150),
                          )
                        : Container(
                            color: const Color(0xFFF4F4F4),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.image_outlined,
                              size: 22.sp,
                              color: const Color(0xFFB5B5B5),
                            ),
                          ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF222222),
                      height: 1.3,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (item.optionLabel != null && item.optionLabel!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        item.optionLabel!,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF666666),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  SizedBox(height: 4.h),
                  Text(
                    item.optionLabel ?? item.unit ?? '1 unit',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF888888),
                      fontFamily: 'Inter',
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: <Widget>[
                      if (hasDiscount) ...<Widget>[
                        Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF999999),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFF999999),
                            fontFamily: 'Inter',
                          ),
                        ),
                        SizedBox(width: 8.w),
                      ],
                      Text(
                        '₹${effectivePrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0AC26B),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _QuantityButton(
                      icon: Icons.remove_rounded,
                      color: const Color(0xFFE23372),
                      onPressed: onDecrease,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF222222),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    _QuantityButton(
                      icon: Icons.add_rounded,
                      color: const Color(0xFF0AC26B),
                      onPressed: onIncrease,
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  '₹${item.total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222222),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatefulWidget {
  const _QuantityButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_QuantityButton> createState() => _QuantityButtonState();
}

class _QuantityButtonState extends State<_QuantityButton> {
  double _scale = 1;

  void _setPressed(bool pressed) {
    setState(() {
      _scale = pressed ? 0.92 : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Material(
        color: widget.color,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: widget.onPressed,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 28.w,
            height: 28.w,
            child: Icon(
              widget.icon,
              size: 16.sp,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
