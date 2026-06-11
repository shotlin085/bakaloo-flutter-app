// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/savings_breakdown_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_address_header.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_bill_summary.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_bottom_bar.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_coupons_offers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_delivery_header.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_item_card.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_misc_widgets.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_ordering_for.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_savings_banner.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_savings_breakdown.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_tip_section.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/checkout_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/screens/coupons_screen.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/schedule_delivery_sheet.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/confirmation_dialog.dart';
import 'package:bakaloo_flutter_app/shared/widgets/empty_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(priceDropProductsProvider);
      ref.read(paymentOffersProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final checkoutSummary = ref.read(checkoutProvider.notifier).summary;
    final cart = switch (cartAsync) {
      AsyncData(:final value) => value,
      _ => CartEntity.empty(),
    };
    final selectedAddress = ref.watch(cartSelectedAddressProvider);
    final hasAddress = selectedAddress != null;
    final billSummaryAsync = ref.watch(billSummaryProvider);
    final billSummary = switch (billSummaryAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final displayBillSummary = _displayBillSummary(
      cart: cart,
      checkoutSummary: checkoutSummary,
      remoteSummary: billSummary,
    );
    // Bottom bar mirrors the bill's "To pay" — backend total when available,
    // otherwise the item subtotal while the summary loads.
    final toPay = billSummary != null ? displayBillSummary.payable : cart.subtotal;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(context, cart.itemCount),
      body: cartAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE23372)),
        ),
        error: (error, _) => ErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: () => ref.read(cartProvider.notifier).refresh(),
        ),
        data: (resolvedCart) {
          if (resolvedCart.isEmpty) {
            return EmptyState(
              title: 'Your cart is empty',
              message: 'Add fresh groceries to start your order.',
              buttonLabel: 'Start Shopping',
              onPressed: () => context.go(RouteNames.home),
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: 500,
            padding: EdgeInsets.zero,
            children: _buildSections(
              context: context,
              cart: resolvedCart,
              selectedAddress: selectedAddress,
              hasAddress: hasAddress,
              billSummaryAsync: billSummaryAsync,
              billSummary: displayBillSummary,
            ),
          );
        },
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : CartBottomBar(
              hasAddress: hasAddress,
              toPay: toPay,
              onAddAddress: () => _ensureAddressAndProceed(context),
              onProceed: () => _proceedToCheckout(context),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, int itemCount) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16.w,
      title: Text(
        'My Cart${itemCount > 0 ? ' ($itemCount)' : ''}',
        style: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF222222),
          fontFamily: 'Inter',
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
      ),
      actions: <Widget>[
        IconButton(
          onPressed: () => context.push(RouteNames.wishlist),
          icon: Icon(
            Icons.favorite_border_rounded,
            size: 22.sp,
            color: const Color(0xFF222222),
          ),
        ),
        if (itemCount > 0)
          TextButton(
            onPressed: () => _clearCart(context),
            child: Text(
              'Clear',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE23372),
                fontFamily: 'Inter',
              ),
            ),
          ),
        SizedBox(width: 4.w),
      ],
    );
  }

  List<Widget> _buildSections({
    required BuildContext context,
    required CartEntity cart,
    required AddressEntity? selectedAddress,
    required bool hasAddress,
    required AsyncValue<BillSummaryEntity> billSummaryAsync,
    required BillSummaryEntity billSummary,
  }) {
    final savingsTotal = billSummary.savings.total;
    final estimateMinutes = billSummary.deliveryEstimate.minutes;
    final widgets = <Widget>[];

    if (hasAddress && selectedAddress != null) {
      widgets.add(
        RepaintBoundary(
          child: CartAddressHeader(
            address: selectedAddress,
            onTap: () => _openAddressList(context),
          ),
        ),
      );
    }

    if (savingsTotal > 0) {
      widgets.add(
        RepaintBoundary(
          child: CartSavingsBanner(savingsTotal: savingsTotal),
        ),
      );
    }

    widgets.add(
      RepaintBoundary(
        child: CartCouponsOffers(
          onViewCoupons: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const CouponsScreen(),
              ),
            );
          },
        ),
      ),
    );
    widgets.add(const CartSectionDivider());

    widgets.add(
      RepaintBoundary(
        child: _buildDeliveryHeader(
          context: context,
          estimateMinutes: estimateMinutes,
          itemCount: cart.itemCount,
        ),
      ),
    );
    widgets.add(const CartSectionDivider());

    widgets.addAll(_buildItemCards(context, cart.items));
    widgets.add(const CartSectionDivider());

    widgets.add(const RepaintBoundary(child: CartTipSection()));

    if (hasAddress) {
      widgets.add(const CartSectionDivider());
      widgets.add(const RepaintBoundary(child: CartOrderingFor()));
      widgets.add(const CartSectionDivider());
      widgets.add(const RepaintBoundary(child: CartGstInvoice()));
      widgets.add(const CartSectionDivider());
      widgets.add(const RepaintBoundary(child: CartCancellationPolicy()));
    }

    widgets.add(const CartSectionDivider());
    widgets.add(
      billSummaryAsync.when(
        loading: () => RepaintBoundary(child: _buildBillSummaryShimmer()),
        error: (_, __) => RepaintBoundary(
          child: CartBillSummary(summary: billSummary),
        ),
        data: (_) => RepaintBoundary(
          child: CartBillSummary(summary: billSummary),
        ),
      ),
    );

    if (billSummary.savings.total > 0) {
      widgets.add(const CartSectionDivider());
      widgets.add(
        RepaintBoundary(
          child: CartSavingsBreakdown(savings: billSummary.savings),
        ),
      );
    }

    widgets.add(SizedBox(height: 110.h));

    return widgets;
  }

  List<Widget> _buildItemCards(
    BuildContext context,
    List<CartItemEntity> items,
  ) {
    return List<Widget>.generate(items.length, (index) {
      final item = items[index];
      return RepaintBoundary(
        child: Column(
          children: <Widget>[
            CartItemCard(
              item: item,
              onIncrease: () => _updateItemQuantity(
                context,
                item.productId,
                item.quantity + 1,
                shopProductId: item.shopProductId,
              ),
              onDecrease: () {
                if (item.quantity <= 1) {
                  _removeItem(context, item.productId, shopProductId: item.shopProductId);
                  return;
                }
                _updateItemQuantity(
                  context,
                  item.productId,
                  item.quantity - 1,
                  shopProductId: item.shopProductId,
                );
              },
              onRemove: () => _removeItem(context, item.productId, shopProductId: item.shopProductId),
            ),
            if (index != items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0F0F0),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildBillSummaryShimmer() {
    return Padding(
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
          children: List<Widget>.generate(
            5,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == 4 ? 0 : 14.h),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Container(
                    width: 64.w,
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryHeader({
    required BuildContext context,
    required int estimateMinutes,
    required int itemCount,
  }) {
    final selectedSlot = ref.watch(
      checkoutProvider.select((s) => s.selectedDeliverySlot),
    );
    final effectiveSlot = selectedSlot ?? const SelectedDeliverySlot.asap();

    return CartDeliveryHeader(
      estimateMinutes: estimateMinutes,
      itemCount: itemCount,
      selectedSlot: effectiveSlot,
      onScheduleTap: () => _openScheduleSheet(context),
    );
  }

  Future<void> _openScheduleSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ScheduleDeliverySheet(),
    );
  }

  Future<void> _clearCart(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Clear cart?',
      message: 'This will remove all items from your cart.',
      confirmLabel: 'Clear',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final result = await ref.read(cartProvider.notifier).clearCart();
    if (!result.isSuccess && context.mounted) {
      showCartSnackBar(context, result.failure!.message);
    } else if (result.isSuccess) {
      // Reset delivery slot to ASAP when cart is cleared
      ref.read(checkoutProvider.notifier).clearDeliverySlot();
    }
  }

  Future<bool> _openAddAddress(BuildContext context) async {
    final changed = await context.push<bool>(RouteNames.addAddress);
    if (!context.mounted || changed != true) {
      return false;
    }

    ref.read(addressProvider.notifier).refresh();
    try {
      await ref.read(addressProvider.future);
    } catch (_) {}
    return true;
  }

  Future<void> _ensureAddressAndProceed(BuildContext context) async {
    final changed = await _openAddAddress(context);
    if (!context.mounted || !changed) {
      return;
    }

    await _proceedToCheckout(context);
  }

  Future<void> _openAddressList(BuildContext context) async {
    await context.push(RouteNames.addresses);
    if (!mounted) {
      return;
    }

    ref.read(addressProvider.notifier).refresh();
  }

  Future<void> _removeItem(BuildContext context, String productId, {String? shopProductId}) async {
    final result = await ref.read(cartProvider.notifier).removeItem(productId, shopProductId: shopProductId);
    if (!result.isSuccess && context.mounted) {
      showCartSnackBar(context, result.failure!.message);
    }
  }

  Future<void> _updateItemQuantity(
    BuildContext context,
    String productId,
    int quantity, {
    String? shopProductId,
  }) async {
    final result = await ref.read(cartProvider.notifier).updateItem(
          productId,
          quantity,
          shopProductId: shopProductId,
        );
    if (!result.isSuccess && context.mounted) {
      showCartSnackBar(context, result.failure!.message);
    }
  }

  Future<void> _proceedToCheckout(BuildContext context) async {
    final selectedAddress = ref.read(cartSelectedAddressProvider);
    if (selectedAddress == null) {
      await _ensureAddressAndProceed(context);
      return;
    }

    final validation =
        await ref.read(cartProvider.notifier).validateAndProceed();
    if (!context.mounted) {
      return;
    }
    if (validation.hasFailure) {
      showCartSnackBar(context, validation.failure!.message);
      return;
    }
    if (!validation.valid) {
      showCartSnackBar(context, validation.warnings.join('\n'));
      return;
    }

    final checkoutNotifier = ref.read(checkoutProvider.notifier);
    checkoutNotifier.selectAddress(selectedAddress);
    checkoutNotifier.selectPaymentMethod(PaymentMethod.online);
    context.push('${RouteNames.cart}/checkout');
  }

  BillSummaryEntity _displayBillSummary({
    required CartEntity cart,
    required CheckoutSummaryEntity checkoutSummary,
    required BillSummaryEntity? remoteSummary,
  }) {
    // The backend TotalsEngine is the single source of truth — when its
    // summary is available we render it verbatim (dynamic delivery fee,
    // handling/platform fees, distance, free-delivery progress, total).
    if (remoteSummary != null) {
      return remoteSummary;
    }

    // Fallback shown only while the backend summary is still loading: show the
    // item subtotal without fabricating any fees (no hardcoded ₹25/₹5 math).
    final mrpSavings = cart.totalSavings;
    return BillSummaryEntity(
      itemTotal: ItemTotal(
        original: cart.subtotal + mrpSavings,
        discounted: cart.subtotal,
      ),
      deliveryFee: const DeliveryFeeInfo(),
      handlingFee: const FeeInfo(),
      lateNightFee: const LateNightFeeInfo(),
      toPay: BillToPay(
        original: cart.subtotal + mrpSavings,
        finalAmount: cart.subtotal,
      ),
      savings: SavingsBreakdownEntity(
        total: mrpSavings,
        items: <SavingsLineItem>[
          if (mrpSavings > 0)
            SavingsLineItem(
              type: 'mrp_discount',
              label: 'Discount on MRP',
              amount: mrpSavings,
            ),
        ],
      ),
      deliveryEstimate: const DeliveryEstimate(),
      totalPayable: cart.subtotal,
      tipAmount: cart.tipAmount,
      itemCount: cart.itemCount,
    );
  }
}
