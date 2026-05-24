import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/payment_offer_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/coupon_provider.dart';

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  final Set<String> _expandedCoupons = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
        ..invalidate(availableCouponsProvider)
        ..invalidate(paymentOffersProvider);
    });
  }

  Future<void> _refreshData() async {
    ref
      ..invalidate(availableCouponsProvider)
      ..invalidate(paymentOffersProvider);

    try {
      await Future.wait<dynamic>(<Future<dynamic>>[
        ref.read(availableCouponsProvider.future),
        ref.read(paymentOffersProvider.future),
      ]);
    } catch (_) {}
  }

  Future<void> _applyCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return;
    }

    final success =
        await ref.read(checkoutProvider.notifier).applyCoupon(normalized);
    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    final error = ref.read(checkoutProvider).errorMessage;
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorRed,
        ),
      );
      ref.read(checkoutProvider.notifier).clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(availableCouponsProvider);
    final offersAsync = ref.watch(paymentOffersProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final subtotal = ref.read(checkoutProvider.notifier).subtotal;

    final coupons = couponsAsync.asData?.value ?? const <CouponEntity>[];
    final offers = offersAsync.asData?.value ?? const <PaymentOfferEntity>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Coupons & Offers', style: AppTextStyles.h2),
            Text(
              'Curated savings for this cart',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
          children: <Widget>[
            if (checkoutState.appliedCoupon != null) ...<Widget>[
              _AppliedCouponBanner(coupon: checkoutState.appliedCoupon!),
              Gap(18.h),
            ],
            Gap(22.h),
            const _SectionHeader(
              eyebrow: 'SMART COUPONS',
              title: 'Best codes for this order',
              subtitle:
                  'These offers are ready to apply instantly on your current basket.',
            ),
            Gap(12.h),
            if (couponsAsync.isLoading && coupons.isEmpty) ...<Widget>[
              const _LoadingOfferCard(),
              Gap(12.h),
              const _LoadingOfferCard(),
            ] else if (couponsAsync.hasError && coupons.isEmpty) ...<Widget>[
              _InlineStateCard(
                icon: PhosphorIcons.warningCircle(),
                title: 'Unable to load coupons right now',
                subtitle: couponsAsync.error.toString(),
              ),
            ] else if (coupons.isEmpty) ...<Widget>[
              const _InlineStateCard(
                icon: Icons.local_offer_outlined,
                title: 'No live coupons right now',
                subtitle:
                    'You can still try a code manually or use one of the payment offers below.',
              ),
            ] else
              ...coupons.map(
                (coupon) {
                  final isApplied =
                      checkoutState.appliedCoupon?.code == coupon.code;
                  final isEligible = subtotal >= coupon.minOrderAmount;
                  final isExpanded = _expandedCoupons.contains(coupon.code);
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _CouponCard(
                      coupon: coupon,
                      subtotal: subtotal,
                      isApplied: isApplied,
                      isEligible: isEligible,
                      isExpanded: isExpanded,
                      onApply: isApplied ? null : () => _applyCode(coupon.code),
                      onToggleTerms: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedCoupons.remove(coupon.code);
                          } else {
                            _expandedCoupons.add(coupon.code);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            Gap(10.h),
            const _SectionHeader(
              eyebrow: 'BANK & UPI OFFERS',
              title: 'Payment perks you can unlock',
              subtitle:
                  'These work on online payment and update based on your cart total.',
            ),
            Gap(12.h),
            if (offersAsync.isLoading && offers.isEmpty) ...<Widget>[
              const _LoadingOfferCard(),
              Gap(12.h),
              const _LoadingOfferCard(),
            ] else if (offersAsync.hasError && offers.isEmpty) ...<Widget>[
              _InlineStateCard(
                icon: PhosphorIcons.creditCard(),
                title: 'Unable to load payment offers',
                subtitle: offersAsync.error.toString(),
              ),
            ] else if (offers.isEmpty) ...<Widget>[
              const _InlineStateCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No payment offers right now',
                subtitle:
                    'Once live offers are available, they will appear here automatically.',
              ),
            ] else
              ...offers.map(
                (offer) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _BankOfferCard(offer: offer),
                ),
              ),
            Gap(8.h),
            const _InlineStateCard(
              icon: Icons.info_outline_rounded,
              title: 'How savings are applied',
              subtitle:
                  'Coupons reduce your order total before payment. Bank and UPI offers are promotional benefits that may be credited by the payment partner after a successful online payment.',
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppliedCouponBanner extends StatelessWidget {
  const _AppliedCouponBanner({
    required this.coupon,
  });

  final CouponEntity coupon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primaryGreenLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34.w,
            height: 34.w,
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 18.sp,
            ),
          ),
          Gap(10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${coupon.code} applied',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap(2.h),
                Text(
                  coupon.description ??
                      'This coupon will be used when you place the order.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(4.h),
        Text(title, style: AppTextStyles.h2),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    required this.subtotal,
    required this.isApplied,
    required this.isEligible,
    required this.isExpanded,
    required this.onToggleTerms,
    this.onApply,
  });

  final CouponEntity coupon;
  final double subtotal;
  final bool isApplied;
  final bool isEligible;
  final bool isExpanded;
  final VoidCallback onToggleTerms;
  final VoidCallback? onApply;

  String get _badgeMain => coupon.discountType == CouponDiscountType.PERCENTAGE
      ? '${coupon.discountValue.toStringAsFixed(0)}%'
      : coupon.discountValue.toInrCurrency;

  String get _saveLine {
    if (coupon.discountType == CouponDiscountType.PERCENTAGE &&
        coupon.maxDiscount > 0) {
      return 'Save up to ${coupon.maxDiscount.toInrCurrency}';
    }
    return 'Instant savings on this order';
  }

  @override
  Widget build(BuildContext context) {
    final shortfall = coupon.minOrderAmount > subtotal
        ? coupon.minOrderAmount - subtotal
        : 0.0;
    final accentGradient = isApplied
        ? AppColors.heroGradient
        : isEligible
            ? AppColors.offerBannerGradient
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFF3F4F6),
                  Color(0xFFE6E7EB),
                ],
              );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: isApplied
              ? AppColors.primaryGreen
              : AppColors.borderLight.withValues(alpha: 0.9),
          width: isApplied ? 1.4 : 1,
        ),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 92.w,
                padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 14.h),
                decoration: BoxDecoration(
                  gradient: accentGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppDimensions.radiusXl),
                    bottomLeft: Radius.circular(AppDimensions.radiusXl),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Icon(
                      isApplied
                          ? Icons.check_circle_rounded
                          : Icons.local_offer_rounded,
                      color: isApplied
                          ? Colors.white
                          : isEligible
                              ? AppColors.warmOrangeDark
                              : AppColors.textSecondary,
                      size: 18.sp,
                    ),
                    Gap(8.h),
                    Text(
                      _badgeMain,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2.copyWith(
                        color: isApplied ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20.sp,
                      ),
                    ),
                    Text(
                      'OFF',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isApplied
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: <Widget>[
                                _TinyPill(
                                  text: coupon.code,
                                  background: AppColors.bgSection,
                                  foreground: AppColors.textPrimary,
                                ),
                                _TinyPill(
                                  text: isApplied
                                      ? 'Applied'
                                      : isEligible
                                          ? 'Ready'
                                          : 'Locked',
                                  background: isApplied
                                      ? AppColors.primaryGreenLight
                                      : isEligible
                                          ? AppColors.warmCard
                                          : const Color(0xFFF0F2F5),
                                  foreground: isApplied
                                      ? AppColors.primaryGreen
                                      : isEligible
                                          ? AppColors.warmOrangeDark
                                          : AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                          Gap(8.w),
                          FilledButton(
                            onPressed: isEligible ? onApply : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: isApplied
                                  ? AppColors.primaryGreenLight
                                  : AppColors.primaryGreen,
                              foregroundColor: isApplied
                                  ? AppColors.primaryGreen
                                  : Colors.white,
                              disabledBackgroundColor: AppColors.bgSection,
                              disabledForegroundColor: AppColors.textTertiary,
                              minimumSize: Size(84.w, 42.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd,
                                ),
                              ),
                            ),
                            child: Text(
                              isApplied ? 'Applied' : 'Apply',
                              style: AppTextStyles.buttonSmall.copyWith(
                                color: isApplied
                                    ? AppColors.primaryGreen
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Gap(10.h),
                      Text(
                        coupon.description ??
                            'Use this coupon to reduce your final bill.',
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 15.sp,
                        ),
                      ),
                      Gap(6.h),
                      Text(
                        _saveLine,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Gap(10.h),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                          Gap(6.w),
                          Expanded(
                            child: Text(
                              'Min cart ${coupon.minOrderAmount.toInrCurrency}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (!isEligible)
                            Text(
                              'Add ${shortfall.toInrCurrency} more',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.warningOrange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
            child: Column(
              children: <Widget>[
                Divider(
                  height: 1,
                  color: AppColors.divider,
                  indent: 92.w,
                ),
                Gap(8.h),
                Row(
                  children: <Widget>[
                    SizedBox(width: 92.w),
                    Expanded(
                      child: TextButton(
                        onPressed: onToggleTerms,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isExpanded ? 'Hide terms' : 'View terms',
                          style: AppTextStyles.buttonSmall.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: isExpanded
                      ? Padding(
                          padding: EdgeInsets.only(left: 92.w),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                              border: Border.all(
                                color: AppColors.borderLight,
                              ),
                            ),
                            child: Text(
                              coupon.terms ??
                                  'Valid on one order. Cannot be clubbed with another coupon in the same checkout.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankOfferCard extends StatelessWidget {
  const _BankOfferCard({
    required this.offer,
  });

  final PaymentOfferEntity offer;

  @override
  Widget build(BuildContext context) {
    final providerInitial = offer.provider.trim().isEmpty
        ? '₹'
        : offer.provider.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF0B2559),
                      Color(0xFF294A9B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    providerInitial,
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      offer.title,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 15.sp,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      offer.description ??
                          'Online payment promotion available on eligible carts.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Gap(8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: <Widget>[
                        _TinyPill(
                          text: offer.provider,
                          background: const Color(0xFFEFF3FF),
                          foreground: const Color(0xFF173E8F),
                        ),
                        _TinyPill(
                          text: 'Above ${offer.minOrderAmount.toInrCurrency}',
                          background: AppColors.bgSection,
                          foreground: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Gap(10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: offer.isLocked
                      ? const Color(0xFFFFF4DD)
                      : AppColors.primaryGreenLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      offer.cashbackAmount.toInrCurrency,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: offer.isLocked
                            ? const Color(0xFF8A5A00)
                            : AppColors.primaryGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      offer.isLocked ? 'Unlock' : 'Cashback',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: offer.isLocked
                            ? const Color(0xFF8A5A00)
                            : AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap(14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: LinearProgressIndicator(
              minHeight: 8.h,
              value: offer.unlockProgress.clamp(0.0, 1.0).toDouble(),
              backgroundColor: const Color(0xFFE9EEF9),
              valueColor: AlwaysStoppedAnimation<Color>(
                offer.isLocked
                    ? const Color(0xFFF0A000)
                    : AppColors.primaryGreen,
              ),
            ),
          ),
          Gap(10.h),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  offer.isLocked
                      ? (offer.lockMessage ??
                          'Add a little more to unlock this payment offer.')
                      : 'Ready to claim on your next online payment.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Gap(8.w),
              _TinyPill(
                text: offer.isLocked ? 'Locked' : 'Live',
                background: offer.isLocked
                    ? const Color(0xFFFFF4DD)
                    : AppColors.primaryGreenLight,
                foreground: offer.isLocked
                    ? const Color(0xFF8A5A00)
                    : AppColors.primaryGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineStateCard extends StatelessWidget {
  const _InlineStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(dense ? 14.w : 18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: dense ? 34.w : 40.w,
            height: dense ? 34.w : 40.w,
            decoration: BoxDecoration(
              color: AppColors.bgSection,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.textSecondary,
              size: dense ? 16.sp : 18.sp,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.labelLarge),
                Gap(2.h),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingOfferCard extends StatelessWidget {
  const _LoadingOfferCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 92.w,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F3F5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.radiusXl),
                bottomLeft: Radius.circular(AppDimensions.radiusXl),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 90.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      color: AppColors.bgSection,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Gap(12.h),
                  Container(
                    width: double.infinity,
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: AppColors.bgSection,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Gap(8.h),
                  Container(
                    width: 140.w,
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: AppColors.bgSection,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
