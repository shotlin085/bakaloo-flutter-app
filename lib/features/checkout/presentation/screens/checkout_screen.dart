import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/checkout_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/providers/payment_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CheckoutScreen — Payment-only page: Wallet + Razorpay Online
// ═══════════════════════════════════════════════════════════════════════════

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _billExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final walletBalanceAsync = ref.watch(walletBalanceProvider);
    final walletBalance = walletBalanceAsync.asData?.value ?? 0.0;
    final summary = ref.read(checkoutProvider.notifier).summary;
    final isPlacing = checkoutState.isPlacingOrder;

    ref
      // ── Listen for checkout errors ────────────────────────────────────
      ..listen<CheckoutState>(checkoutProvider, (prev, next) {
        final msg = next.errorMessage;
        if (msg != null && msg != prev?.errorMessage && mounted) {
          _showSnackBar(msg, isError: true);
          ref.read(checkoutProvider.notifier).clearError();
        }
      })
      // ── Listen for payment errors (Razorpay cancel / failure) ─────────
      ..listen<PaymentState>(paymentProvider, (prev, next) {
        final msg = next.errorMessage;
        if (msg != null && msg != prev?.errorMessage && mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(msg)),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF455A64),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () => _handlePayment(PaymentMethod.online),
                ),
              ),
            );
          ref.read(paymentProvider.notifier).clearError();
        }
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: _buildAppBar(checkoutState),
      body: cartAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
        error: (error, _) => _EmptyState(
          message: error.toString().replaceFirst('Bad state: ', ''),
        ),
        data: (cart) {
          if (cart.isEmpty) {
            return const _EmptyState(message: 'Your cart is empty.');
          }
          return _buildBody(
            checkoutState: checkoutState,
            summary: summary,
            walletBalance: walletBalance,
            walletLoading: walletBalanceAsync.isLoading,
            itemCount: cart.itemCount,
          );
        },
      ),
      bottomNavigationBar: _CheckoutBottomBar(
        summary: summary,
        isLoading: isPlacing,
        onPlaceOrder: () => _handlePayment(checkoutState.paymentMethod),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(CheckoutState state) {
    final address = state.selectedAddress;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Payment Options', style: AppTextStyles.h3),
          if (address != null)
            Text(
              'Delivering to ${address.label}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.sp,
              ),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }

  Widget _buildBody({
    required CheckoutState checkoutState,
    required CheckoutSummaryEntity summary,
    required double walletBalance,
    required bool walletLoading,
    required int itemCount,
  }) {
    final address = checkoutState.selectedAddress;
    final shortfall = summary.total - walletBalance;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      children: <Widget>[
        // ── Bill Accordion ──────────────────────────────────────────
        _BillAccordion(
          summary: summary,
          expanded: _billExpanded,
          onToggle: () => setState(() => _billExpanded = !_billExpanded),
        ),

        Gap(12.h),

        // ── Delivery Info ───────────────────────────────────────────
        if (address != null)
          _DeliveryInfoCard(
            address: address,
            itemCount: itemCount,
            onChangeAddress: () => _changeAddress(context),
          )
        else
          _AddAddressCard(onTap: () => _changeAddress(context)),

        Gap(20.h),

        // ── Section Label ───────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Text(
            'CHOOSE PAYMENT',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              fontSize: 11.sp,
            ),
          ),
        ),

        // ── Wallet Card ─────────────────────────────────────────────
        _WalletPaymentCard(
          balance: walletBalance,
          total: summary.total,
          isLoading: walletLoading,
          shortfall: shortfall > 0 ? shortfall : 0,
          onPay: () => _handlePayment(PaymentMethod.wallet),
          onAddMoney: _goToTopup,
          isPlacingOrder: checkoutState.paymentMethod == PaymentMethod.wallet &&
              checkoutState.isPlacingOrder,
        ),

        Gap(12.h),

        // ── Razorpay Card ───────────────────────────────────────────
        _RazorpayPaymentCard(
          total: summary.total,
          onPay: () => _handlePayment(PaymentMethod.online),
          isPlacingOrder: checkoutState.paymentMethod == PaymentMethod.online &&
              checkoutState.isPlacingOrder,
        ),

        Gap(20.h),

        // ── Footer Info ─────────────────────────────────────────────
        const _CheckoutFooter(),
      ],
    );
  }

  // ── Payment Handler ─────────────────────────────────────────────────
  Future<void> _handlePayment(PaymentMethod method) async {
    final currentState = ref.read(checkoutProvider);
    if (currentState.isPlacingOrder) {
      return;
    }

    if (currentState.selectedAddress == null) {
      _showSnackBar('Please choose a delivery address first.');
      return;
    }

    ref.read(checkoutProvider.notifier).selectPaymentMethod(method);
    final result = await ref.read(checkoutProvider.notifier).placeOrder();

    if (!mounted) {
      return;
    }
    if (result.handedOffToPayment) {
      return;
    }
    if (result.isSuccess) {
      return;
    }

    if (result.errorMessage != null) {
      _showSnackBar(result.errorMessage!, isError: true);
    }
  }

  // ── Address Change ──────────────────────────────────────────────────
  Future<void> _changeAddress(BuildContext context) async {
    final addressAsync = ref.read(addressProvider);
    var addresses = switch (addressAsync) {
      AsyncData(:final value) => value,
      _ => const <AddressEntity>[],
    };

    if (addresses.isEmpty) {
      final changed = await context.push<bool>(RouteNames.addAddress);
      if (!context.mounted) {
        return;
      }
      if (changed == true) {
        ref.read(addressProvider.notifier).refresh();
        try {
          await ref.read(addressProvider.future);
        } catch (_) {}
      }
      addresses = switch (ref.read(addressProvider)) {
        AsyncData(:final value) => value,
        _ => const <AddressEntity>[],
      };
    }

    if (addresses.isEmpty || !context.mounted) {
      return;
    }

    final selected = await showModalBottomSheet<AddressEntity>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AddressPickerSheet(
        addresses: addresses,
        selected: ref.read(checkoutProvider).selectedAddress,
      ),
    );
    if (!context.mounted || selected == null) {
      return;
    }
    ref.read(checkoutProvider.notifier).selectAddress(selected);
  }

  // ── Topup with refresh ──────────────────────────────────────────────
  Future<void> _goToTopup() async {
    await context.push<bool>(RouteNames.topup);
    if (!mounted) {
      return;
    }
    // Always refresh — user may have topped up even if they didn't pop with
    // `true`.
    ref.invalidate(walletBalanceProvider);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? AppColors.errorRed : const Color(0xFF455A64),
        ),
      );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bill Accordion
// ═══════════════════════════════════════════════════════════════════════════

class _BillAccordion extends StatelessWidget {
  const _BillAccordion({
    required this.summary,
    required this.expanded,
    required this.onToggle,
  });

  final CheckoutSummaryEntity summary;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18.sp,
                    color: AppColors.textSecondary,
                  ),
                  Gap(8.w),
                  Text(
                    'To Pay',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    summary.total.toInrCurrency,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Gap(6.w),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryGreen,
                      size: 20.sp,
                    ),
                  ),
                  Gap(2.w),
                  Text(
                    expanded ? 'Hide' : 'View Bill',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              child: expanded
                  ? Column(
                      children: <Widget>[
                        Divider(
                          height: 1,
                          color: AppColors.divider,
                          indent: 16.w,
                          endIndent: 16.w,
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
                          child: Column(
                            children: <Widget>[
                              _BillRow(
                                label: 'Items total',
                                value: summary.subtotal,
                              ),
                              Gap(8.h),
                              _BillRow(
                                label: 'Delivery fee',
                                value: summary.deliveryFee,
                              ),
                              Gap(8.h),
                              _BillRow(
                                label: 'Platform fee',
                                value: summary.platformFee,
                              ),
                              if (summary.discount > 0) ...<Widget>[
                                Gap(8.h),
                                _BillRow(
                                  label: 'Coupon discount',
                                  value: summary.discount,
                                  prefix: '-',
                                  valueColor: AppColors.successGreen,
                                ),
                              ],
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                child: const Divider(
                                  height: 1,
                                  color: AppColors.divider,
                                ),
                              ),
                              _BillRow(
                                label: 'Total',
                                value: summary.total,
                                valueStyle: AppTextStyles.h3
                                    .copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.prefix = '',
    this.valueColor,
    this.valueStyle,
  });

  final String label;
  final double value;
  final String prefix;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          '$prefix${value.toInrCurrency}',
          style: valueStyle ??
              AppTextStyles.labelLarge.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Delivery Info Card
// ═══════════════════════════════════════════════════════════════════════════

class _DeliveryInfoCard extends StatelessWidget {
  const _DeliveryInfoCard({
    required this.address,
    required this.itemCount,
    required this.onChangeAddress,
  });

  final AddressEntity address;
  final int itemCount;
  final VoidCallback onChangeAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primaryGreenLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border:
            Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32.w,
            height: 32.w,
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 16.sp,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      address.label,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    Gap(6.w),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$itemCount item${itemCount == 1 ? '' : 's'}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(3.h),
                Text(
                  _format(address),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChangeAddress,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Change',
              style: AppTextStyles.buttonSmall
                  .copyWith(color: AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  static String _format(AddressEntity a) {
    return <String>[
      a.addressLine1,
      if (a.addressLine2 != null && a.addressLine2!.trim().isNotEmpty)
        a.addressLine2!.trim(),
      '${a.city}, ${a.state} ${a.pincode}',
    ].join(', ');
  }
}

class _AddAddressCard extends StatelessWidget {
  const _AddAddressCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border:
              Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5)),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.add_location_alt_outlined,
              color: AppColors.primaryGreen,
              size: 24.sp,
            ),
            Gap(12.w),
            Expanded(
              child: Text(
                'Choose delivery address',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primaryGreen,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Wallet Payment Card  (indigo gradient)
// ═══════════════════════════════════════════════════════════════════════════

class _WalletPaymentCard extends StatelessWidget {
  const _WalletPaymentCard({
    required this.balance,
    required this.total,
    required this.isLoading,
    required this.shortfall,
    required this.onPay,
    required this.onAddMoney,
    required this.isPlacingOrder,
  });

  final double balance;
  final double total;
  final bool isLoading;
  final double shortfall;
  final VoidCallback onPay;
  final VoidCallback onAddMoney;
  final bool isPlacingOrder;

  bool get _sufficient => shortfall <= 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        gradient: AppColors.walletCardGradient,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header
            Row(
              children: <Widget>[
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 22.sp,
                  ),
                ),
                Gap(12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Bakaloo Wallet',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.sp,
                      ),
                    ),
                    Gap(2.h),
                    isLoading
                        ? Container(
                            width: 80.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          )
                        : Text(
                            'Balance: ${balance.toInrCurrency}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                  ],
                ),
              ],
            ),
            Gap(16.h),

            // Insufficient balance warning
            if (!_sufficient) ...<Widget>[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF6D00).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFB74D),
                      size: 16,
                    ),
                    Gap(8.w),
                    Expanded(
                      child: Text(
                        'Add ${shortfall.toInrCurrency} more to pay with wallet',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: const Color(0xFFFFCC80),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onAddMoney,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Add Money',
                        style: AppTextStyles.buttonSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Gap(12.h),
            ],

            // Pay button
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: FilledButton(
                onPressed: (_sufficient && !isPlacingOrder)
                    ? onPay
                    : (!_sufficient ? onAddMoney : null),
                style: FilledButton.styleFrom(
                  backgroundColor: _sufficient
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.2),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isPlacingOrder
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF1A237E),
                          ),
                        ),
                      )
                    : Text(
                        _sufficient
                            ? 'Pay ${total.toInrCurrency} from Wallet'
                            : 'Add Money to Wallet',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: _sufficient
                              ? const Color(0xFF1A237E)
                              : Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Razorpay Payment Card  (white + green left accent)
// ═══════════════════════════════════════════════════════════════════════════

class _RazorpayPaymentCard extends StatelessWidget {
  const _RazorpayPaymentCard({
    required this.total,
    required this.onPay,
    required this.isPlacingOrder,
  });

  final double total;
  final VoidCallback onPay;
  final bool isPlacingOrder;

  @override
  Widget build(BuildContext context) {
    // Use ClipRRect + Row to avoid Border(left:) + borderRadius crash
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: <BoxShadow>[AppShadows.cardShadow],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: <Widget>[
              // Green left accent bar
              Container(width: 4, color: AppColors.primaryGreen),
              // Card content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 42.w,
                            height: 42.w,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreenLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              color: AppColors.primaryGreen,
                              size: 22.sp,
                            ),
                          ),
                          Gap(12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Pay Online',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                Gap(2.h),
                                Text(
                                  'UPI • Cards • Netbanking & more',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF072654),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Razorpay',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Gap(16.h),
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: FilledButton(
                          onPressed: isPlacingOrder ? null : onPay,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            disabledBackgroundColor:
                                AppColors.primaryGreen.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isPlacingOrder
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      'Pay ${total.toInrCurrency} Online',
                                      style:
                                          AppTextStyles.buttonMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Gap(6.w),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════
// Footer
// ═══════════════════════════════════════════════════════════════════════════

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _FooterRow(
          icon: Icons.info_outline_rounded,
          text:
              'Orders can be cancelled until the store starts packing them. Refunds for prepaid orders are processed automatically.',
        ),
        Gap(8.h),
        const _FooterRow(
          icon: Icons.lock_outlined,
          text: 'Your payment is secured with 256-bit SSL encryption.',
        ),
      ],
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 14.sp, color: AppColors.textTertiary),
        Gap(8.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11.sp,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom Bar
// ═══════════════════════════════════════════════════════════════════════════

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({
    required this.summary,
    required this.isLoading,
    required this.onPlaceOrder,
  });

  final CheckoutSummaryEntity summary;
  final bool isLoading;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: <BoxShadow>[AppShadows.floatingShadow],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Total payable',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    summary.total.toInrCurrency,
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Gap(12.w),
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: isLoading ? null : onPlaceOrder,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  disabledBackgroundColor: AppColors.borderLight,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Place Order',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty State
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.shopping_cart_outlined,
              size: 56.sp,
              color: AppColors.textDisabled,
            ),
            Gap(12.h),
            Text(
              message,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Address Picker Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _AddressPickerSheet extends StatelessWidget {
  const _AddressPickerSheet({
    required this.addresses,
    required this.selected,
  });

  final List<AddressEntity> addresses;
  final AddressEntity? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
        itemCount: addresses.length,
        separatorBuilder: (_, __) => Gap(10.h),
        itemBuilder: (context, index) {
          final address = addresses[index];
          final isSelected = selected?.id == address.id;
          return InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            onTap: () => Navigator.of(context).pop(address),
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.primaryGreenLight : AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.borderLight,
                    size: 20.sp,
                  ),
                  Gap(10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${address.label} • ${address.name}',
                          style: AppTextStyles.labelLarge
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Gap(3.h),
                        Text(
                          <String>[
                            address.addressLine1,
                            '${address.city}, ${address.state}',
                          ].join(', '),
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
