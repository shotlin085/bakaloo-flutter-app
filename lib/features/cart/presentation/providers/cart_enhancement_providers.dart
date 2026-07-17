import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/data/datasources/cart_enhancements_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/payment_offer_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/tip_preset_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';

part 'cart_enhancement_providers.g.dart';

final cartEnhancementsDataSourceProvider =
    Provider<CartEnhancementsRemoteDataSource>((Ref ref) {
  return CartEnhancementsRemoteDataSource(ref.watch(apiClientProvider));
});

@riverpod
class BillSummaryNotifier extends _$BillSummaryNotifier {
  @override
  Future<BillSummaryEntity> build() async {
    final cart = await ref.watch(cartProvider.future);
    if (cart.isEmpty) {
      return BillSummaryEntity.empty();
    }

    // Watch the applied coupon so the bill summary rebuilds whenever the user
    // applies or removes a coupon, without requiring a separate refresh call.
    final appliedCoupon = ref.watch(checkoutProvider).appliedCoupon;

    // Watch the confirmed Quick Delivery selection so the bill (and the
    // surcharge line + faster delivery estimate that come with it) rebuild
    // the moment the customer confirms it in the schedule sheet — this was
    // previously never sent to the backend at all, so the surcharge silently
    // never applied to the total.
    final quickDeliverySelected = ref.watch(
      checkoutProvider.select(
        (s) => s.selectedDeliverySlot?.quickDeliverySelected ?? false,
      ),
    );

    final result = await ref
        .read(cartEnhancementsDataSourceProvider)
        .getCartSummary(quickDeliverySelected: quickDeliverySelected);

    return result.fold(
      (failure) => throw StateError(failure.message),
      (summary) {
        // A manually-typed coupon code lives in client-side Riverpod state,
        // not the server session, so it isn't reflected in the backend
        // response at all. `summary.couponDiscount`/`totalPayable` may
        // already carry an auto-applied first-time-offer discount though
        // (backend-resolved, no customer action needed) — a manual coupon
        // takes priority over that and replaces it rather than stacking on
        // top (single discount slot, matching OrdersService.placeOrder()'s
        // rule), so the first-time-offer amount is added back before the
        // coupon discount is subtracted.
        //
        // CASHBACK/FREE_DELIVERY coupons always have discountAmount == 0
        // by backend design (they don't reduce the bill — a cashback is a
        // separate wallet credit after delivery, free delivery waives the
        // delivery fee instead of subtracting from the total). Previously
        // this guard only checked discountAmount > 0, so applying one of
        // these silently changed nothing on screen — the customer saw the
        // "applied" banner but the bill looked untouched, indistinguishable
        // from the coupon not working at all.
        if (appliedCoupon == null) {
          return summary;
        }

        final hasDiscount = appliedCoupon.discountAmount > 0;
        final hasFreeDelivery = appliedCoupon.freeDelivery;
        final hasCashback = appliedCoupon.cashbackAmount > 0;
        if (!hasDiscount && !hasFreeDelivery && !hasCashback) {
          return summary;
        }

        final discount = appliedCoupon.discountAmount;
        final basePayable =
            summary.totalPayable > 0 ? summary.totalPayable : summary.toPay.finalAmount;
        final basePayableBeforeAutoDiscount = basePayable + summary.couponDiscount;
        var newPayable =
            (basePayableBeforeAutoDiscount - discount).clamp(0.0, double.infinity);

        var deliveryFee = summary.deliveryFee;
        if (hasFreeDelivery && !deliveryFee.isFree) {
          // The FTO's own free-delivery waiver (if any) is already reflected
          // in basePayableBeforeAutoDiscount's delivery component via the
          // backend response — only waive here (and refund the fee into the
          // payable total) when delivery wasn't already free.
          newPayable = (newPayable - deliveryFee.amount).clamp(0.0, double.infinity);
          deliveryFee = deliveryFee.copyWith(amount: 0, isFree: true, freeIn: 0);
        }

        // The "Your savings" breakdown is computed server-side from the
        // auto-applied first-time-offer only (the backend has no idea a
        // manual coupon exists client-side) — when the coupon replaces the
        // FTO above, drop its now-stale line here too, or the savings card
        // and the main bill row disagree about which reward is active.
        var savings = summary.savings;
        final ftoLine = savings.items
            .where((item) => item.type == 'first_time_offer')
            .toList();
        if (ftoLine.isNotEmpty) {
          final ftoAmount = ftoLine.first.amount;
          savings = savings.copyWith(
            total: (savings.total - ftoAmount).clamp(0.0, double.infinity),
            items: savings.items
                .where((item) => item.type != 'first_time_offer')
                .toList(),
          );
        }

        return summary.copyWith(
          couponDiscount: discount,
          totalPayable: newPayable,
          deliveryFee: deliveryFee,
          savings: savings,
          firstTimeOffer: null,
        );
      },
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

@riverpod
class PaymentOffersNotifier extends _$PaymentOffersNotifier {
  @override
  Future<List<PaymentOfferEntity>> build() async {
    final summary = await ref.watch(billSummaryProvider.future);
    final result = await ref
        .read(cartEnhancementsDataSourceProvider)
        .getPaymentOffers(summary.itemTotal.discounted);

    return result.fold(
      (failure) => throw StateError(failure.message),
      (offers) => offers,
    );
  }
}

@riverpod
Future<List<TipPresetEntity>> tipPresets(Ref ref) async {
  final result =
      await ref.read(cartEnhancementsDataSourceProvider).getTipPresets();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (presets) => presets,
  );
}

@riverpod
class CartTipNotifier extends _$CartTipNotifier {
  @override
  double build() {
    final cartAsync = ref.watch(cartProvider);
    return cartAsync.asData?.value.tipAmount ?? 0;
  }

  Future<void> setTip(double amount) async {
    final previous = state;
    state = amount;

    final result =
        await ref.read(cartEnhancementsDataSourceProvider).updateTip(amount);
    result.fold(
      (_) {
        state = previous;
      },
      (_) {
        ref.invalidate(billSummaryProvider);
      },
    );
  }

  void clearTip() {
    state = 0;
  }
}

@riverpod
class DeliveryInstructionsNotifier extends _$DeliveryInstructionsNotifier {
  @override
  String build() {
    final cartAsync = ref.watch(cartProvider);
    return cartAsync.asData?.value.deliveryInstructions ?? '';
  }

  Future<void> setInstructions(String instructions) async {
    final previous = state;
    state = instructions;

    final result = await ref
        .read(cartEnhancementsDataSourceProvider)
        .updateDeliveryInstructions(instructions);
    result.fold(
      (_) {
        state = previous;
      },
      (_) {},
    );
  }
}

@riverpod
Future<List<Map<String, dynamic>>> priceDropProducts(Ref ref) async {
  final result =
      await ref.read(cartEnhancementsDataSourceProvider).getPriceDropProducts();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (products) => products,
  );
}

@riverpod
Future<List<Map<String, dynamic>>> lastMinuteProducts(Ref ref) async {
  final result = await ref
      .read(cartEnhancementsDataSourceProvider)
      .getLastMinuteProducts();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (products) => products,
  );
}

@riverpod
AddressEntity? cartSelectedAddress(Ref ref) {
  final checkoutState = ref.watch(checkoutProvider);
  if (checkoutState.selectedAddress != null) {
    return checkoutState.selectedAddress;
  }

  final addresses = ref.watch(addressProvider);
  return addresses.when(
    data: (list) => list.isNotEmpty
        ? list.firstWhere((a) => a.isDefault, orElse: () => list.first)
        : null,
    loading: () => null,
    error: (_, __) => null,
  );
}

@riverpod
class TipTabNotifier extends _$TipTabNotifier {
  @override
  int build() => 0;

  void setTab(int tab) {
    state = tab;
  }
}
