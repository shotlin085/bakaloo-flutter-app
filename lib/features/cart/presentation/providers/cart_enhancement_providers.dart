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

    final result =
        await ref.read(cartEnhancementsDataSourceProvider).getCartSummary();

    return result.fold(
      (failure) => throw StateError(failure.message),
      (summary) {
        // The backend always returns couponDiscount: 0 because the applied
        // coupon lives in client-side Riverpod state, not in the server session.
        // Patch the summary here with the locally-stored discount so both the
        // discount row and the final "To pay" amount are correct.
        if (appliedCoupon != null && appliedCoupon.discountAmount > 0) {
          final discount = appliedCoupon.discountAmount;
          final basePayable =
              summary.totalPayable > 0 ? summary.totalPayable : summary.toPay.finalAmount;
          final newPayable = (basePayable - discount).clamp(0.0, double.infinity);
          return summary.copyWith(
            couponDiscount: discount,
            totalPayable: newPayable,
          );
        }
        return summary;
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
