import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/analytics/analytics_service.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/datasources/order_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/repositories/checkout_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/checkout_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/usecases/place_order.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/coupon_provider.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/providers/payment_provider.dart';

part 'checkout_provider.freezed.dart';
part 'checkout_provider.g.dart';

typedef CartValidationEntity = CartValidationResult;

enum PaymentMethod {
  cod,
  online,
  wallet,
}

extension PaymentMethodX on PaymentMethod {
  String get apiValue => switch (this) {
        PaymentMethod.cod => 'COD',
        PaymentMethod.online => 'ONLINE',
        PaymentMethod.wallet => 'WALLET',
      };

  String get title => switch (this) {
        PaymentMethod.cod => 'Cash on Delivery',
        PaymentMethod.online => 'Pay Online',
        PaymentMethod.wallet => 'Bakaloo Wallet',
      };
}

enum CheckoutStep {
  address,
  coupon,
  payment,
  review,
}

@freezed
abstract class CheckoutState with _$CheckoutState {
  const factory CheckoutState({
    AddressEntity? selectedAddress,
    CouponEntity? appliedCoupon,
    @Default(PaymentMethod.online) PaymentMethod paymentMethod,
    CartValidationEntity? validatedCart,
    @Default(CheckoutStep.address) CheckoutStep currentStep,
    @Default(false) bool isPlacingOrder,
    String? errorMessage,
  }) = _CheckoutState;
}

class CheckoutPlacementResult {
  const CheckoutPlacementResult({
    this.order,
    this.errorMessage,
    this.handedOffToPayment = false,
  });

  final PlacedOrderEntity? order;
  final String? errorMessage;
  final bool handedOffToPayment;

  bool get isSuccess => order != null && errorMessage == null;
}

final orderRemoteDataSourceProvider =
    Provider<OrderRemoteDataSource>((Ref ref) {
  return OrderRemoteDataSource(ref.watch(apiClientProvider));
});

final checkoutRepositoryProvider = Provider<CheckoutRepository>((Ref ref) {
  return CheckoutRepositoryImpl(
    remoteDataSource: ref.watch(orderRemoteDataSourceProvider),
  );
});

final placeOrderUseCaseProvider = Provider<PlaceOrderUseCase>((Ref ref) {
  return PlaceOrderUseCase(ref.watch(checkoutRepositoryProvider));
});

@riverpod
class CheckoutNotifier extends _$CheckoutNotifier {
  @override
  CheckoutState build() {
    ref
      ..listen<AsyncValue<List<AddressEntity>>>(addressProvider, (_, next) {
        next.whenData(_syncAddresses);
      })
      ..listen<AsyncValue<CartEntity>>(cartProvider, (_, next) {
        next.whenData(_syncCart);
      });

    final initialAddresses = switch (ref.watch(addressProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final initialCart = switch (ref.watch(cartProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };

    return CheckoutState(
      selectedAddress: _defaultAddress(initialAddresses),
      validatedCart: initialCart == null
          ? null
          : CartValidationResult(
              valid: true,
              cart: initialCart,
            ),
    );
  }

  void selectAddress(AddressEntity address) {
    state = state.copyWith(
      selectedAddress: address,
      currentStep: CheckoutStep.coupon,
      errorMessage: null,
    );
  }

  void selectPaymentMethod(PaymentMethod method) {
    state = state.copyWith(
      paymentMethod: method,
      currentStep: CheckoutStep.review,
      errorMessage: null,
    );
  }

  Future<bool> applyCoupon(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter a coupon code to continue.',
      );
      return false;
    }

    final cartTotal = subtotal;
    if (cartTotal <= 0) {
      state = state.copyWith(
        errorMessage: 'Your cart is empty.',
      );
      return false;
    }

    final result = await ref.read(validateCouponUseCaseProvider).call(
          code: normalizedCode,
          cartTotal: cartTotal,
        );

    return result.fold(
      (failure) {
        final message = _mapCouponError(failure.message);
        state = state.copyWith(errorMessage: message);
        return false;
      },
      (coupon) {
        state = state.copyWith(
          appliedCoupon: coupon,
          currentStep: CheckoutStep.payment,
          errorMessage: null,
        );
        unawaited(
          ref.read(analyticsServiceProvider).logCouponApplied(
                coupon.code,
                coupon.discountAmount,
              ),
        );
        return true;
      },
    );
  }

  void removeCoupon() {
    state = state.copyWith(
      appliedCoupon: null,
      currentStep: CheckoutStep.coupon,
      errorMessage: null,
    );
  }

  /// Maps raw backend coupon error messages / codes to user-friendly copy.
  String _mapCouponError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('uuid') || lower.contains('syntax')) {
      return 'This coupon is not available.';
    }
    if (lower.contains('expired')) {
      return 'This coupon has expired.';
    }
    if (lower.contains('minimum') || lower.contains('min_order') || lower.contains('min order')) {
      return raw; // already includes the ₹ amount — keep as is
    }
    if (lower.contains('usage limit') || lower.contains('limit reached')) {
      return 'This coupon has reached its usage limit.';
    }
    if (lower.contains('already used') || lower.contains('user_limit') || lower.contains('maximum number')) {
      return 'You have already used this coupon.';
    }
    if (lower.contains('not found') || lower.contains('invalid coupon') || lower.contains('inactive')) {
      return 'This coupon is not available.';
    }
    if (lower.contains('not yet active') || lower.contains('not started')) {
      return 'This coupon is not yet active.';
    }
    if (lower.contains('multi-shop')) {
      return 'Coupons are not supported for orders from multiple stores.';
    }
    if (lower.contains('validation error')) {
      return 'Could not apply coupon. Please try again.';
    }
    return raw;
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(errorMessage: null);
  }

  Future<CheckoutPlacementResult> placeOrder() async {
    // Prevent double-tap: if already placing, reject immediately
    if (state.isPlacingOrder) {
      return const CheckoutPlacementResult(
        errorMessage: 'Order already in progress.',
      );
    }

    final selectedPaymentMethod = state.paymentMethod;

    if (state.selectedAddress == null) {
      const message = 'Choose a delivery address to continue.';
      state = state.copyWith(errorMessage: message);
      return const CheckoutPlacementResult(errorMessage: message);
    }

    if (subtotal <= 0) {
      const message = 'Your cart is empty.';
      state = state.copyWith(errorMessage: message);
      return const CheckoutPlacementResult(errorMessage: message);
    }

    final walletBalance = await _walletBalance;
    if (selectedPaymentMethod == PaymentMethod.wallet &&
        walletBalance < total) {
      const message = 'Insufficient wallet balance. Please add money first.';
      state = state.copyWith(errorMessage: message);
      return const CheckoutPlacementResult(errorMessage: message);
    }

    state = state.copyWith(isPlacingOrder: true, errorMessage: null);
    unawaited(
      ref.read(analyticsServiceProvider).logBeginCheckout(
            total,
            cart.itemCount,
          ),
    );

    final result = await ref.read(placeOrderUseCaseProvider).call(
          PlaceOrderParams(
            addressId: state.selectedAddress!.id,
            paymentMethod: selectedPaymentMethod.apiValue,
            couponCode: state.appliedCoupon?.code,
          ),
        );

    // IMPORTANT: dartz's fold() does NOT await async callbacks.
    // Extract the Either result synchronously, then run async logic after.
    if (result.isLeft()) {
      final failure =
          result.fold((l) => l, (_) => throw StateError('unreachable'));
      state = state.copyWith(
        isPlacingOrder: false,
        errorMessage: failure.message,
      );
      return CheckoutPlacementResult(errorMessage: failure.message);
    }

    final order = result.fold((_) => throw StateError('unreachable'), (r) => r);
    // Cart invalidation moved to payment_provider.dart success paths only.
    // This prevents the blank-page-after-Razorpay-cancel bug.
    var handedOffToPayment = false;

    if (selectedPaymentMethod == PaymentMethod.online) {
      final paymentResult =
          await ref.read(paymentProvider.notifier).startRazorpayFlow(order);
      if (!paymentResult.isSuccess) {
        await _tryCancelOrder(
          order.id,
          reason: 'Payment gateway failed to launch',
        );
        state = state.copyWith(
          isPlacingOrder: false,
          errorMessage: paymentResult.errorMessage,
        );
        return CheckoutPlacementResult(
          errorMessage: paymentResult.errorMessage,
        );
      }
      // Razorpay is now open. Reset isPlacingOrder so checkout UI is usable
      // when Razorpay dismisses (cancel or success). The payment_provider
      // handles navigation on success.
      state = state.copyWith(isPlacingOrder: false);
      handedOffToPayment = true;
    }

    if (selectedPaymentMethod == PaymentMethod.wallet) {
      final paymentResult =
          await ref.read(paymentProvider.notifier).payOrderFromWallet(order);
      if (!paymentResult.isSuccess) {
        await _tryCancelOrder(
          order.id,
          reason: 'Wallet payment failed',
        );
        state = state.copyWith(
          isPlacingOrder: false,
          errorMessage: paymentResult.errorMessage,
        );
        return CheckoutPlacementResult(
          errorMessage: paymentResult.errorMessage,
        );
      }
      handedOffToPayment = true;
    }

    state = state.copyWith(
      isPlacingOrder: false,
      currentStep: CheckoutStep.review,
      errorMessage: null,
    );
    return CheckoutPlacementResult(
      order: order,
      handedOffToPayment: handedOffToPayment,
    );
  }

  Future<double> get _walletBalance async {
    final current = ref.read(walletBalanceProvider);
    final value = current.asData?.value;
    if (value != null) {
      return value;
    }
    try {
      return await ref.read(walletBalanceProvider.future);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _tryCancelOrder(
    String orderId, {
    required String reason,
  }) async {
    try {
      await ref.read(dioClientProvider).post<dynamic>(
        ApiConstants.orderCancel(orderId),
        data: <String, dynamic>{'reason': reason},
      );
      await ref.read(dioClientProvider).post<dynamic>(
        ApiConstants.orderReorder(orderId),
        data: const <String, dynamic>{},
      );
    } catch (_) {
      // If cancellation fails, keep the original payment failure visible.
    }
  }

  CheckoutSummaryEntity get summary {
    return CheckoutSummaryEntity(
      subtotal: subtotal,
      discount: discount,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      total: total,
      itemCount: cart.itemCount,
    );
  }

  CartEntity get cart {
    final cartAsync = ref.read(cartProvider);
    return state.validatedCart?.cart ??
        switch (cartAsync) {
          AsyncData(:final value) => value,
          _ => CartEntity.empty(),
        };
  }

  double get subtotal => cart.subtotal;

  double get deliveryFee => subtotal >= AppConstants.freeDeliveryThreshold
      ? 0
      : AppConstants.standardDeliveryFee;

  double get discount {
    final amount = state.appliedCoupon?.discountAmount ?? 0;
    if (amount <= 0) {
      return 0;
    }
    return amount > subtotal ? subtotal : amount;
  }

  double get platformFee => cart.isEmpty ? 0 : AppConstants.platformFee;

  double get total {
    final value = subtotal - discount + deliveryFee + platformFee;
    return value < 0 ? 0 : value;
  }

  void _syncAddresses(List<AddressEntity> addresses) {
    if (addresses.isEmpty) {
      if (state.selectedAddress == null) {
        return;
      }
      state = state.copyWith(selectedAddress: null);
      return;
    }

    final current = state.selectedAddress;
    AddressEntity? selected;
    if (current != null) {
      for (final address in addresses) {
        if (address.id == current.id) {
          selected = address;
          break;
        }
      }
    }

    selected ??= _defaultAddress(addresses);
    if (selected?.id == current?.id) {
      if (selected != current) {
        state = state.copyWith(selectedAddress: selected);
      }
      return;
    }

    state = state.copyWith(selectedAddress: selected);
  }

  void _syncCart(CartEntity nextCart) {
    final currentCoupon = state.appliedCoupon;
    var nextState = state.copyWith(
      validatedCart: CartValidationResult(
        valid: true,
        cart: nextCart,
      ),
    );

    if (currentCoupon != null &&
        nextCart.subtotal < currentCoupon.minOrderAmount) {
      nextState = nextState.copyWith(
        appliedCoupon: null,
        errorMessage:
            'Coupon removed because the cart total is below the minimum order amount.',
      );
    }

    state = nextState;
  }

  AddressEntity? _defaultAddress(List<AddressEntity>? addresses) {
    if (addresses == null || addresses.isEmpty) {
      return null;
    }
    for (final address in addresses) {
      if (address.isDefault) {
        return address;
      }
    }
    return addresses.first;
  }
}
