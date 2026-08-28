import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';

/// Shown only when the "Cash / Wallet" button on the cart's bottom bar has
/// a genuine choice to offer — i.e. both wallet (admin-enabled, balance
/// sufficient) and Cash on Delivery (admin-enabled, bill total within the
/// configured range) are actually usable right now. When only one of the
/// two is usable, the caller places that order directly instead of opening
/// this sheet — see CartScreen._handleCashOrWallet.
class CartPaymentSelectorSheet extends ConsumerWidget {
  const CartPaymentSelectorSheet({
    required this.orderTotal,
    required this.paymentMethods,
    required this.onPaymentMethodSelected,
    super.key,
  });

  final double orderTotal;
  final PaymentMethodsInfo paymentMethods;
  final void Function(String method) onPaymentMethodSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final walletBalance = walletAsync.asData?.value.balance ?? 0.0;
    final hasEnoughWalletBalance = walletBalance >= orderTotal;
    final cod = paymentMethods.cod;

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
            'Pay with Cash or Wallet',
            style: AppTextStyles.h3,
          ),
          Gap(20.h),

          // Bakaloo Wallet — only reachable here when the admin has it
          // enabled at all; still greyed out (with an "Add Money" nudge)
          // when the balance itself falls short.
          if (paymentMethods.wallet.enabled) ...<Widget>[
            _PaymentOptionTile(
              icon: PhosphorIcons.wallet,
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
            Gap(12.h),
          ],

          // Cash on Delivery — only reachable here when the admin has it
          // enabled at all; greyed out with the backend's own reason text
          // when the live bill total falls outside the configured range.
          if (cod.enabled)
            _PaymentOptionTile(
              icon: PhosphorIcons.money,
              title: 'Cash on Delivery',
              subtitle: cod.available
                  ? 'Pay in cash when your order arrives'
                  : (cod.reason ?? 'Not available for this order'),
              onTap: cod.available
                  ? () {
                      Navigator.of(context).pop();
                      onPaymentMethodSelected('COD');
                    }
                  : null,
              opacity: cod.available ? 1.0 : 0.5,
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
    this.trailingWidget,
    this.opacity = 1.0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
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
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            children: <Widget>[
              PhosphorIcon(
                icon,
                color: AppColors.textPrimary,
                size: 28,
              ),
              Gap(16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
                const PhosphorIcon(
                  PhosphorIcons.caretRight,
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
