import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/providers/payment_provider.dart';

class CartPaymentSelectorSheet extends ConsumerWidget {
  const CartPaymentSelectorSheet({
    required this.orderTotal,
    required this.onPaymentMethodSelected,
    super.key,
  });

  final double orderTotal;
  final void Function(String method) onPaymentMethodSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletBalanceAsync = ref.watch(walletBalanceProvider);
    final walletBalance = walletBalanceAsync.asData?.value ?? 0.0;
    final hasEnoughWalletBalance = walletBalance >= orderTotal;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        MediaQuery.paddingOf(context).bottom + 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Gap(24.h),
          Text(
            'Choose Payment Method',
            style: AppTextStyles.h3,
          ),
          Gap(20.h),

          // Online Payment (Recommended/Razorpay)
          _PaymentOptionTile(
            icon: PhosphorIcons.creditCard(),
            title: 'Pay Online',
            subtitle: 'UPI, Cards, Netbanking',
            onTap: () {
              Navigator.of(context).pop();
              onPaymentMethodSelected('ONLINE');
            },
            isRecommended: true,
          ),

          Gap(12.h),

          // Bakaloo Wallet
          _PaymentOptionTile(
            icon: PhosphorIcons.wallet(),
            title: 'Bakaloo Wallet',
            subtitle: 'Balance: ${walletBalance.toInrCurrency}',
            onTap: hasEnoughWalletBalance
                ? () {
                    Navigator.of(context).pop();
                    onPaymentMethodSelected('WALLET');
                  }
                : null,
            trailingWidget: !hasEnoughWalletBalance
                ? Text(
                    'Low Balance',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.errorRed),
                  )
                : null,
            opacity: hasEnoughWalletBalance ? 1.0 : 0.5,
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isRecommended = false,
    this.trailingWidget,
    this.opacity = 1.0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isRecommended;
  final Widget? trailingWidget;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  isRecommended ? AppColors.primaryGreen : Colors.grey.shade300,
              width: isRecommended ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isRecommended
                ? AppColors.primaryGreen.withValues(alpha: 0.05)
                : Colors.white,
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            children: <Widget>[
              PhosphorIcon(
                icon,
                color: isRecommended
                    ? AppColors.primaryGreen
                    : AppColors.textPrimary,
                size: 28,
              ),
              Gap(16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          title,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isRecommended) ...[
                          Gap(8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Gap(2.h),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingWidget != null)
                trailingWidget!
              else
                PhosphorIcon(
                  PhosphorIcons.caretRight(),
                  size: 20,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
