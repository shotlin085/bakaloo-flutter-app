import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';

/// Bill Summary card — renders the backend-calculated canonical breakdown.
///
/// All amounts come from the backend TotalsEngine; nothing is recomputed
/// here. Delivery fee shows the dynamic distance-based amount (or FREE when
/// waived), with a free-delivery progress hint, and each fee carries a clear,
/// user-friendly label. The delivery TIME lives in the delivery header, not
/// here — this card is strictly the money breakdown.
class CartBillSummary extends StatelessWidget {
  const CartBillSummary({required this.summary, super.key});

  final BillSummaryEntity summary;

  static const Color _ink = Color(0xFF222222);
  static const Color _muted = Color(0xFF888888);
  static const Color _green = Color(0xFF0AC26B);
  static const Color _divider = Color(0xFFF0F0F0);

  @override
  Widget build(BuildContext context) {
    final delivery = summary.deliveryFee;
    final free = summary.freeDelivery;
    final distanceKnown = summary.distance.known && summary.distance.label.isNotEmpty;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIcons.receipt(),
                    size: 18.sp,
                    color: _ink,
                  ),
                  Gap(8.w),
                  Text(
                    'Bill Summary',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              Gap(16.h),

              // ── Item total ──────────────────────────────────────
              _BillRow(
                label: 'Item total',
                originalAmount: summary.itemTotal.original !=
                        summary.itemTotal.discounted
                    ? summary.itemTotal.original
                    : null,
                amount: summary.itemTotal.discounted,
              ),
              Gap(14.h),

              // ── Coupon discount ─────────────────────────────────
              if (summary.couponDiscount > 0) ...<Widget>[
                _CouponDiscountRow(amount: summary.couponDiscount),
                Gap(14.h),
              ],

              // ── Delivery fee ────────────────────────────────────
              _BillRow(
                label: 'Delivery fee',
                amount: delivery.amount,
                originalAmount: delivery.isFree && delivery.originalAmount > 0
                    ? delivery.originalAmount
                    : null,
                isFree: delivery.isFree,
                onInfo: distanceKnown
                    ? () => _showInfoSheet(
                          context,
                          'Delivery fee',
                          delivery.isFree
                              ? 'Free delivery unlocked on this order.'
                              : 'Calculated by distance — ${summary.distance.label} from the store.',
                        )
                    : null,
              ),
              // Sub-text: distance + free-delivery hint
              if (delivery.isFree) ...<Widget>[
                Gap(6.h),
                _SubNote(
                  icon: PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                  text: free.threshold != null
                      ? 'Free delivery unlocked on orders above ₹${_fmt(free.threshold!)}'
                      : 'Free delivery unlocked',
                  color: _green,
                ),
              ] else ...<Widget>[
                if (distanceKnown) ...<Widget>[
                  Gap(6.h),
                  _SubNote(
                    icon: PhosphorIcons.mapPin(),
                    text: '${summary.distance.label} from store',
                    color: _muted,
                  ),
                ],
                if (free.enabled && free.amountToUnlock > 0) ...<Widget>[
                  Gap(6.h),
                  _SubNote(
                    icon: PhosphorIcons.moped(),
                    text:
                        'Add ₹${_fmt(free.amountToUnlock)} more for free delivery',
                    color: _green,
                  ),
                ],
              ],

              // ── Free delivery progress bar ──────────────────────
              if (free.enabled &&
                  !delivery.isFree &&
                  free.threshold != null &&
                  free.amountToUnlock > 0) ...<Widget>[
                Gap(10.h),
                _FreeDeliveryProgress(
                  subtotal: summary.itemTotal.discounted,
                  threshold: free.threshold!,
                ),
              ],
              Gap(14.h),

              // ── Handling fee ────────────────────────────────────
              if (summary.handlingFee.amount > 0) ...<Widget>[
                _BillRow(
                  label: 'Handling fee',
                  amount: summary.handlingFee.amount,
                  onInfo: () => _showInfoSheet(
                    context,
                    'Handling fee',
                    'Covers packing, quality checks and order handling so your items arrive safely.',
                  ),
                ),
                Gap(14.h),
              ],

              // ── Platform fee ────────────────────────────────────
              if (summary.platformFee.amount > 0) ...<Widget>[
                _BillRow(
                  label: 'Platform fee',
                  amount: summary.platformFee.amount,
                  onInfo: () => _showInfoSheet(
                    context,
                    'Platform fee',
                    'Helps us run the platform and provide customer support.',
                  ),
                ),
                Gap(14.h),
              ],

              // ── Small cart fee ──────────────────────────────────
              if (summary.smallCartFee.amount > 0) ...<Widget>[
                _BillRow(
                  label: 'Small cart fee',
                  amount: summary.smallCartFee.amount,
                  onInfo: () => _showInfoSheet(
                    context,
                    'Small cart fee',
                    'Applied to smaller orders. Add a few more items to avoid this fee.',
                  ),
                ),
                Gap(14.h),
              ],

              // ── Tip ─────────────────────────────────────────────
              if (summary.tipAmount > 0) ...<Widget>[
                _BillRow(
                  label: 'Delivery partner tip',
                  amount: summary.tipAmount,
                ),
                Gap(14.h),
              ],

              Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: const Divider(height: 1, thickness: 1, color: _divider),
              ),
              Gap(14.h),

              // ── To pay ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'To pay',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      if (summary.toPay.original > summary.payable) ...<Widget>[
                        Text(
                          '₹${_fmt(summary.toPay.original)}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF999999),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFF999999),
                            fontFamily: 'Inter',
                          ),
                        ),
                        Gap(8.w),
                      ],
                      Text(
                        '₹${_fmt(summary.payable)}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(0);

  void _showInfoSheet(BuildContext context, String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
            Gap(18.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _ink,
                fontFamily: 'Inter',
              ),
            ),
            Gap(8.h),
            Text(
              body,
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF555555),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row primitive
// ─────────────────────────────────────────────────────────────────────────────

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.amount,
    this.originalAmount,
    this.isFree = false,
    this.onInfo,
  });

  final String label;
  final double amount;
  final double? originalAmount;
  final bool isFree;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF555555),
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              if (onInfo != null) ...<Widget>[
                Gap(4.w),
                GestureDetector(
                  onTap: onInfo,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 15.sp,
                    color: const Color(0xFFAAAAAA),
                  ),
                ),
              ],
            ],
          ),
        ),
        Row(
          children: <Widget>[
            if (originalAmount != null) ...<Widget>[
              Text(
                '₹${originalAmount!.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF999999),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: const Color(0xFF999999),
                  fontFamily: 'Inter',
                ),
              ),
              Gap(6.w),
            ],
            Text(
              isFree ? 'FREE' : '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: isFree
                    ? const Color(0xFF0AC26B)
                    : const Color(0xFF222222),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-note (distance / free-delivery hint)
// ─────────────────────────────────────────────────────────────────────────────

class _SubNote extends StatelessWidget {
  const _SubNote({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        PhosphorIcon(icon, size: 13.sp, color: color),
        Gap(5.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: color,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coupon discount row — green, shows amount saved with a tag icon
// ─────────────────────────────────────────────────────────────────────────────

class _CouponDiscountRow extends StatelessWidget {
  const _CouponDiscountRow({required this.amount});

  final double amount;

  static const Color _green = Color(0xFF0AC26B);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.tag(PhosphorIconsStyle.fill),
              size: 14.sp,
              color: _green,
            ),
            Gap(6.w),
            Text(
              'Coupon discount',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: _green,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        Text(
          '−₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: _green,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Free-delivery progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _FreeDeliveryProgress extends StatelessWidget {
  const _FreeDeliveryProgress({
    required this.subtotal,
    required this.threshold,
  });

  final double subtotal;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final progress =
        threshold <= 0 ? 1.0 : (subtotal / threshold).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999.r),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6.h,
        backgroundColor: const Color(0xFFEFEFEF),
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0AC26B)),
      ),
    );
  }
}
