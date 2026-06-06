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
import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/checkout_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/providers/payment_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

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
  void initState() {
    super.initState();
    // Eagerly trigger wallet fetch so balance is ready when the payment
    // section renders. Uses walletProvider (keepAlive WalletNotifier) so
    // the same fetch is shared with the wallet screen — no duplicate requests.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(walletProvider.future).ignore();
      }
    });
  }

  @override
  void dispose() {
    // Refresh cart when leaving checkout (back press, payment cancel, etc.)
    // so that any Redis mutations from validateCart are reflected in the
    // Flutter cart state. This prevents "Item not in cart" on the next
    // cart screen interaction.
    ref.read(cartProvider.notifier).refresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final checkoutState = ref.watch(checkoutProvider);
    // FIX: Use walletProvider (WalletNotifier, keepAlive) instead of the
    // separate walletBalanceProvider so balance is always available from the
    // already-loaded WalletEntity — prevents "Balance unavailable" error state.
    final walletAsync = ref.watch(walletProvider);
    final walletBalance = walletAsync.asData?.value.balance;
    final walletLoading = walletAsync.isLoading;
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
            walletBalance: walletBalance ?? 0.0,
            walletLoading: walletLoading,
            walletError: walletAsync.hasError,
            itemCount: cart.itemCount,
            items: cart.items,
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
    required bool walletError,
    required int itemCount,
    required List<CartItemEntity> items,
  }) {
    final address = checkoutState.selectedAddress;
    final shortfall = summary.total - walletBalance;
    final selectedMethod = checkoutState.paymentMethod;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      children: <Widget>[
        // ── Order Items Review (option labels visible) ──────────────
        _OrderItemsReviewCard(items: items),

        Gap(12.h),

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
            selectedSlot: checkoutState.selectedDeliverySlot,
            onChangeAddress: () => _changeAddress(context),
          )
        else
          _AddAddressCard(onTap: () => _changeAddress(context)),

        Gap(24.h),

        // ── Section Label ───────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Text(
            'CHOOSE PAYMENT',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.orderViolet,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              fontSize: 11.sp,
            ),
          ),
        ),

        // ── Wallet Card ─────────────────────────────────────────────
        _WalletPaymentCard(
          balance: walletBalance,
          total: summary.total,
          isLoading: walletLoading,
          hasError: walletError,
          shortfall: shortfall > 0 ? shortfall : 0,
          selected: selectedMethod == PaymentMethod.wallet,
          onSelect: walletLoading ? null : () => ref
              .read(checkoutProvider.notifier)
              .selectPaymentMethod(PaymentMethod.wallet),
          onPay: () => _handlePayment(PaymentMethod.wallet),
          onAddMoney: _goToTopup,
          isPlacingOrder: checkoutState.paymentMethod == PaymentMethod.wallet &&
              checkoutState.isPlacingOrder,
        ),

        Gap(12.h),

        // ── Razorpay Card ───────────────────────────────────────────
        _RazorpayPaymentCard(
          total: summary.total,
          selected: selectedMethod == PaymentMethod.online,
          onSelect: () => ref
              .read(checkoutProvider.notifier)
              .selectPaymentMethod(PaymentMethod.online),
          onPay: () => _handlePayment(PaymentMethod.online),
          isPlacingOrder: checkoutState.paymentMethod == PaymentMethod.online &&
              checkoutState.isPlacingOrder,
        ),

        Gap(18.h),

        // ── Footer Info ─────────────────────────────────────────────
        const _SecurePaymentBadge(),

        Gap(16.h),

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
    ref.invalidate(walletProvider);
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
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: <Widget>[
                  const _PaymentIconTile(icon: Icons.receipt_long_rounded),
                  Gap(12.w),
                  Text(
                    'To Pay',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    summary.total.toInrCurrency,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Gap(10.w),
                  Text(
                    expanded ? 'Hide' : 'View Bill',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Gap(2.w),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryGreen,
                      size: 18.sp,
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
// Order Items Review Card — shows each selected option clearly at checkout
// ═══════════════════════════════════════════════════════════════════════════

class _OrderItemsReviewCard extends StatelessWidget {
  const _OrderItemsReviewCard({required this.items});

  final List<CartItemEntity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Order Summary',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.sp,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} item${items.length == 1 ? '' : 's'}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Gap(10.h),
          ...List<Widget>.generate(items.length, (index) {
            final item = items[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 10.h),
              child: _OrderItemReviewRow(item: item),
            );
          }),
        ],
      ),
    );
  }
}

class _OrderItemReviewRow extends StatelessWidget {
  const _OrderItemReviewRow({required this.item});

  final CartItemEntity item;

  @override
  Widget build(BuildContext context) {
    final optimized = ApiConstants.optimizedMedia(
      item.thumbnailUrl,
      profile: CustomerImageProfile.cartThumb,
    );
    // The option label (e.g. "500g", "4 x 95g") is the key disambiguator
    // between sibling options — surface it prominently next to the name.
    final optionLabel = item.optionLabel?.trim();
    final hasOption = optionLabel != null && optionLabel.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: SizedBox(
            width: 40.w,
            height: 40.w,
            child: (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty)
                ? AppImage(
                    imageUrl: optimized.url ?? item.thumbnailUrl!,
                    memCacheWidth: optimized.memCacheWidth,
                    memCacheHeight: optimized.memCacheHeight,
                    fit: BoxFit.cover,
                    placeholder: const ColoredBox(color: Color(0xFFF4F4F4)),
                    errorWidget: const ColoredBox(
                      color: Color(0xFFF4F4F4),
                      child: Icon(
                        Icons.image_outlined,
                        size: 16,
                        color: Color(0xFFB5B5B5),
                      ),
                    ),
                  )
                : const ColoredBox(
                    color: Color(0xFFF4F4F4),
                    child: Icon(
                      Icons.image_outlined,
                      size: 16,
                      color: Color(0xFFB5B5B5),
                    ),
                  ),
          ),
        ),
        Gap(10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              Gap(2.h),
              Row(
                children: <Widget>[
                  if (hasOption)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        optionLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else if (item.unit != null && item.unit!.isNotEmpty)
                    Text(
                      item.unit!,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  Gap(6.w),
                  Text(
                    'Qty ${item.quantity}',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Gap(8.w),
        Text(
          '₹${item.total.toStringAsFixed(0)}',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
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
    this.selectedSlot,
  });

  final AddressEntity address;
  final int itemCount;
  final VoidCallback onChangeAddress;
  final SelectedDeliverySlot? selectedSlot;

  @override
  Widget build(BuildContext context) {
    final slot = selectedSlot ?? const SelectedDeliverySlot.asap();
    final isScheduled = slot.isScheduled;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40.w,
                height: 40.w,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreenLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primaryGreen,
                  size: 20.sp,
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
                            fontSize: 14.sp,
                          ),
                        ),
                        Gap(8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: AppColors.orderVioletSurface,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            '$itemCount item${itemCount == 1 ? '' : 's'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.orderViolet,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gap(4.h),
                    Text(
                      _format(address),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(8.w),
              GestureDetector(
                onTap: onChangeAddress,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Change',
                      style: AppTextStyles.buttonSmall
                          .copyWith(color: AppColors.primaryGreen),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primaryGreen,
                      size: 16.sp,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── Scheduled delivery badge ──────────────────────────────
          if (isScheduled) ...[
            Gap(10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 14.sp,
                    color: const Color(0xFF7C3AED),
                  ),
                  Gap(6.w),
                  Text(
                    slot.slotLabel,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
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
// Payment selection primitives (premium minimalist)
// ═══════════════════════════════════════════════════════════════════════════

/// A leading rounded-square icon tile used across payment + summary cards.
class _PaymentIconTile extends StatelessWidget {
  const _PaymentIconTile({
    required this.icon,
    this.background = AppColors.orderVioletSurface,
    this.foreground = AppColors.orderViolet,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Icon(icon, color: foreground, size: 20.sp),
    );
  }
}

/// Animated radio indicator. Filled green ring when selected.
class _SelectionRadio extends StatelessWidget {
  const _SelectionRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primaryGreen : AppColors.borderLight,
          width: selected ? 6.5 : 2,
        ),
      ),
    );
  }
}

/// Shared outer shell for a selectable payment card. Wraps content with a
/// white surface, an animated selection border, and press feedback.
class _PaymentCardShell extends StatelessWidget {
  const _PaymentCardShell({
    required this.selected,
    required this.onSelect,
    required this.child,
  });

  final bool selected;
  final VoidCallback onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: selected ? AppColors.primaryGreen : AppColors.borderLight,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: <BoxShadow>[
          if (selected)
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          else
            AppShadows.cardShadow,
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect,
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Wallet Payment Card  (minimal, selectable)
// ═══════════════════════════════════════════════════════════════════════════

class _WalletPaymentCard extends StatelessWidget {
  const _WalletPaymentCard({
    required this.balance,
    required this.total,
    required this.isLoading,
    required this.hasError,
    required this.shortfall,
    required this.selected,
    required this.onSelect,
    required this.onPay,
    required this.onAddMoney,
    required this.isPlacingOrder,
  });

  final double balance;
  final double total;
  final bool isLoading;
  final bool hasError;
  final double shortfall;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback onPay;
  final VoidCallback onAddMoney;
  final bool isPlacingOrder;

  bool get _sufficient => shortfall <= 0;

  @override
  Widget build(BuildContext context) {
    return _PaymentCardShell(
      selected: selected,
      onSelect: onSelect ?? () {},
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header row: icon + title/balance + radio
            Row(
              children: <Widget>[
                const _PaymentIconTile(
                  icon: Icons.account_balance_wallet_rounded,
                ),
                Gap(12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Bakaloo Wallet',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                        ),
                      ),
                      Gap(2.h),
                      if (isLoading)
                        Container(
                          width: 70.w,
                          height: 11.h,
                          decoration: BoxDecoration(
                            color: AppColors.bgSkeleton,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        )
                      else if (hasError)
                        Text(
                          'Balance unavailable',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.errorRed,
                          ),
                        )
                      else
                        Text(
                          'Balance: ${balance.toInrCurrency}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                _SelectionRadio(selected: selected),
              ],
            ),

            // Insufficient balance notice
            if (!_sufficient) ...<Widget>[
              Gap(12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.warmOrangeSoft.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.warningOrange,
                      size: 16.sp,
                    ),
                    Gap(8.w),
                    Expanded(
                      child: Text(
                        'Add ${shortfall.toInrCurrency} more to pay with wallet',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onAddMoney,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Add Money',
                        style: AppTextStyles.buttonSmall.copyWith(
                          color: AppColors.warningOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action only shows when this method is selected.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: selected
                  ? Padding(
                      padding: EdgeInsets.only(top: 14.h),
                      child: _PaymentActionButton(
                        label: _sufficient
                            ? 'Pay ${total.toInrCurrency} from Wallet'
                            : 'Add Money to Wallet',
                        icon: _sufficient
                            ? Icons.lock_rounded
                            : Icons.add_rounded,
                        isLoading: isPlacingOrder,
                        onPressed: (_sufficient && !isPlacingOrder)
                            ? onPay
                            : (!_sufficient ? onAddMoney : null),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width primary action button shared by both payment cards.
class _PaymentActionButton extends StatelessWidget {
  const _PaymentActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor:
              AppColors.primaryGreen.withValues(alpha: 0.45),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, color: Colors.white, size: 17.sp),
                  Gap(8.w),
                  Text(
                    label,
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Razorpay Payment Card  (minimal, selectable)
// ═══════════════════════════════════════════════════════════════════════════

class _RazorpayPaymentCard extends StatelessWidget {
  const _RazorpayPaymentCard({
    required this.total,
    required this.selected,
    required this.onSelect,
    required this.onPay,
    required this.isPlacingOrder,
  });

  final double total;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPay;
  final bool isPlacingOrder;

  @override
  Widget build(BuildContext context) {
    return _PaymentCardShell(
      selected: selected,
      onSelect: onSelect,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const _PaymentIconTile(
                  icon: Icons.bolt_rounded,
                  background: AppColors.primaryGreenLight,
                  foreground: AppColors.primaryGreen,
                ),
                Gap(12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Pay Online',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp,
                            ),
                          ),
                          Gap(8.w),
                          const _RazorpayBadge(),
                        ],
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
                Gap(8.w),
                _SelectionRadio(selected: selected),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: selected
                  ? Padding(
                      padding: EdgeInsets.only(top: 14.h),
                      child: _PaymentActionButton(
                        label: 'Pay ${total.toInrCurrency} Online',
                        icon: Icons.lock_rounded,
                        isLoading: isPlacingOrder,
                        onPressed: isPlacingOrder ? null : onPay,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _RazorpayBadge extends StatelessWidget {
  const _RazorpayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFF072654),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Secure payment badge
// ═══════════════════════════════════════════════════════════════════════════

class _SecurePaymentBadge extends StatelessWidget {
  const _SecurePaymentBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.verified_user_rounded,
          size: 14.sp,
          color: AppColors.orderViolet,
        ),
        Gap(6.w),
        Text.rich(
          TextSpan(
            text: 'Secure payments powered by ',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            children: <InlineSpan>[
              TextSpan(
                text: 'Razorpay',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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
