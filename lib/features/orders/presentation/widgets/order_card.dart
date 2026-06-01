import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_item_thumb_row.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_status_pill.dart';
import 'package:bakaloo_flutter_app/shared/widgets/safe_product_image.dart';

/// Premium order card: hero image, meta, item preview row and contextual
/// actions. Designed to match the reference "My Orders" UI.
class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.order,
    required this.isCancelling,
    required this.isReordering,
    required this.onTap,
    required this.onTrack,
    required this.onCancel,
    required this.onReorder,
    required this.onViewDetails,
    super.key,
  });

  final OrderEntity order;
  final bool isCancelling;
  final bool isReordering;
  final VoidCallback onTap;
  final VoidCallback onTrack;
  final VoidCallback onCancel;
  final VoidCallback onReorder;
  final VoidCallback onViewDetails;

  String get _productNames {
    if (order.items.isEmpty) {
      return 'Order items';
    }
    return order.items.map((item) => item.name).join(', ');
  }

  String? get _heroImageUrl {
    for (final item in order.items) {
      if (item.thumbnailUrl != null && item.thumbnailUrl!.trim().isNotEmpty) {
        return item.thumbnailUrl;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = order.itemCount;

    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.orderCardBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.orderCardShadow,
                blurRadius: 3.r,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeroImage(url: _heroImageUrl),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _OrderMeta(
                      order: order,
                      productNames: _productNames,
                      itemCount: itemCount,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              const Divider(height: 1, color: AppColors.divider),
              SizedBox(height: 12.h),
              OrderItemThumbRow(items: order.items),
              SizedBox(height: 14.h),
              _OrderActions(
                status: order.status,
                isCancelling: isCancelling,
                isReordering: isReordering,
                onTrack: onTrack,
                onCancel: onCancel,
                onReorder: onReorder,
                onViewDetails: onViewDetails,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.orderThumbBorder),
      ),
      padding: EdgeInsets.all(6.w),
      child: SafeProductImage(
        url: url,
        size: 76.w,
        borderRadius: BorderRadius.circular(12.r),
        fit: BoxFit.contain,
        backgroundColor: Colors.white,
        iconSize: 28.sp,
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({
    required this.order,
    required this.productNames,
    required this.itemCount,
  });

  final OrderEntity order;
  final String productNames;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                order.orderNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            OrderStatusPill(status: order.status),
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.calendarBlank(),
              size: 12.sp,
              color: AppColors.textTertiary,
            ),
            SizedBox(width: 5.w),
            Expanded(
              child: Text(
                order.createdAt.toIndianDateTime,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    productNames,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Text(
                order.total.toInrCurrency,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({
    required this.status,
    required this.isCancelling,
    required this.isReordering,
    required this.onTrack,
    required this.onCancel,
    required this.onReorder,
    required this.onViewDetails,
  });

  final OrderStatus status;
  final bool isCancelling;
  final bool isReordering;
  final VoidCallback onTrack;
  final VoidCallback onCancel;
  final VoidCallback onReorder;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case OrderStatus.PENDING:
        // A pending order isn't confirmed yet, so it can't be cancelled from
        // here — surface details instead, with tracking still available.
        return Row(
          children: <Widget>[
            Expanded(
              child: _PrimaryButton(
                icon: PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                label: 'Track Order',
                onTap: onTrack,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _SecondaryButton(
                label: 'View Details',
                onTap: onViewDetails,
              ),
            ),
          ],
        );
      case OrderStatus.CONFIRMED:
      case OrderStatus.PREPARING:
      case OrderStatus.PACKED:
      case OrderStatus.OUT_FOR_DELIVERY:
        return Row(
          children: <Widget>[
            Expanded(
              child: _PrimaryButton(
                icon: PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                label: 'Track Order',
                onTap: onTrack,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _SecondaryButton(
                label: 'Cancel Order',
                isLoading: isCancelling,
                onTap: onCancel,
              ),
            ),
          ],
        );
      case OrderStatus.DELIVERED:
      case OrderStatus.CANCELLED:
        return Row(
          children: <Widget>[
            Expanded(
              child: _PrimaryButton(
                icon: PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
                label: 'Reorder',
                isLoading: isReordering,
                onTap: onReorder,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _SecondaryButton(
                label: 'View Details',
                onTap: onViewDetails,
              ),
            ),
          ],
        );
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Ink(
          height: 44.h,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                AppColors.orderViolet,
                AppColors.orderVioletDark,
              ],
            ),
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.orderVioletGlow,
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    PhosphorIcon(icon, size: 16.sp, color: Colors.white),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          height: 44.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.orderVioletBorder, width: 1.4),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.orderViolet,
                    ),
                  ),
                )
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orderViolet,
                    height: 1.1,
                  ),
                ),
        ),
      ),
    );
  }
}
