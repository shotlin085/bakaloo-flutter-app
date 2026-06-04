import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:bakaloo_flutter_app/core/analytics/analytics_service.dart';
import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:bakaloo_flutter_app/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/payment_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/repositories/payment_repository.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/usecases/create_payment_order.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/usecases/get_history.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/usecases/verify_payment.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/service/razorpay_service.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';

part 'payment_provider.freezed.dart';
part 'payment_provider.g.dart';

@freezed
abstract class PaymentState with _$PaymentState {
  const factory PaymentState({
    @Default(false) bool isLoading,
    @Default(false) bool isVerifying,
    String? errorMessage,
    PaymentEntity? lastPayment,
    String? activeOrderId,
    String? activeRazorpayOrderId,
    @Default(false) bool isWalletTopupFlow,
  }) = _PaymentState;

  factory PaymentState.idle() => const PaymentState();
}

class PaymentActionResult {
  const PaymentActionResult({
    this.errorMessage,
  });

  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

final paymentRemoteDataSourceProvider = Provider<PaymentRemoteDataSource>((
  Ref ref,
) {
  return PaymentRemoteDataSource(ref.watch(apiClientProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((Ref ref) {
  return PaymentRepositoryImpl(
    remoteDataSource: ref.watch(paymentRemoteDataSourceProvider),
  );
});

final createPaymentOrderUseCaseProvider = Provider<CreatePaymentOrderUseCase>((
  Ref ref,
) {
  return CreatePaymentOrderUseCase(ref.watch(paymentRepositoryProvider));
});

final verifyPaymentUseCaseProvider = Provider<VerifyPaymentUseCase>((Ref ref) {
  return VerifyPaymentUseCase(ref.watch(paymentRepositoryProvider));
});

final getPaymentHistoryUseCaseProvider = Provider<GetHistoryUseCase>((Ref ref) {
  return GetHistoryUseCase(ref.watch(paymentRepositoryProvider));
});

final razorpayServiceProvider = Provider<RazorpayService>((Ref ref) {
  final service = RazorpayService();
  ref.onDispose(service.dispose);
  return service;
});

@Riverpod(keepAlive: true)
Future<double> walletBalance(Ref ref) async {
  final result = await ref.read(paymentRepositoryProvider).getWalletBalance();
  return result.fold((failure) {
    throw StateError(failure.message);
  }, (balance) {
    return balance;
  });
}

@Riverpod(keepAlive: true)
class PaymentNotifier extends _$PaymentNotifier {
  RazorpayService get _razorpayService => ref.read(razorpayServiceProvider);

  PaymentRepository get _repository => ref.read(paymentRepositoryProvider);

  UserEntity? get _currentUser => ref.read(currentUserProvider);

  @override
  PaymentState build() {
    ref.onDispose(_resetCallbacks);
    return PaymentState.idle();
  }

  Future<PaymentActionResult> startRazorpayFlow(
    PlacedOrderEntity order,
  ) async {
    if (state.isLoading || state.isVerifying) {
      const message = 'A payment is already in progress.';
      state = state.copyWith(errorMessage: message);
      return const PaymentActionResult(errorMessage: message);
    }

    state = state.copyWith(
      isLoading: true,
      isVerifying: false,
      errorMessage: null,
      activeOrderId: order.id,
      isWalletTopupFlow: false,
    );

    final result = await ref.read(createPaymentOrderUseCaseProvider).call(
          order.id,
        );

    return result.fold(
      (failure) {
        state = PaymentState.idle().copyWith(errorMessage: failure.message);
        return PaymentActionResult(errorMessage: failure.message);
      },
      (razorpayOrder) {
        final validationMessage = _validateRazorpayOrder(razorpayOrder);
        if (validationMessage != null) {
          state = PaymentState.idle().copyWith(errorMessage: validationMessage);
          return PaymentActionResult(errorMessage: validationMessage);
        }

        _attachOrderCallbacks(
          orderId: order.id,
          razorpayOrderId: razorpayOrder.razorpayOrderId,
        );

        try {
          _razorpayService.open(
            RazorpayOptions(
              key: razorpayOrder.key,
              amount: razorpayOrder.amount,
              razorpayOrderId: razorpayOrder.razorpayOrderId,
              name: 'Bakaloo',
              description: 'Order #${order.orderNumber}',
              contact: _currentUser?.phone,
              email: _currentUser?.email,
              prefillName: _currentUser?.name,
              themeColorHex: '#0C831F',
            ),
          );
          state = state.copyWith(
            isLoading: false,
            activeRazorpayOrderId: razorpayOrder.razorpayOrderId,
          );
          return const PaymentActionResult();
        } catch (_) {
          const message = 'Unable to open Razorpay right now.';
          state = PaymentState.idle().copyWith(errorMessage: message);
          return const PaymentActionResult(errorMessage: message);
        }
      },
    );
  }

  Future<PaymentActionResult> startWalletTopup({
    required double amount,
  }) async {
    if (state.isLoading || state.isVerifying) {
      const message = 'A payment is already in progress.';
      state = state.copyWith(errorMessage: message);
      return const PaymentActionResult(errorMessage: message);
    }

    state = state.copyWith(
      isLoading: true,
      isVerifying: false,
      errorMessage: null,
      activeOrderId: null,
      isWalletTopupFlow: true,
    );

    final result = await _repository.createWalletTopup(
      WalletTopupParams(amount: amount),
    );

    return result.fold(
      (failure) {
        state = PaymentState.idle().copyWith(errorMessage: failure.message);
        return PaymentActionResult(errorMessage: failure.message);
      },
      (razorpayOrder) {
        final validationMessage = _validateRazorpayOrder(razorpayOrder);
        if (validationMessage != null) {
          state = PaymentState.idle().copyWith(errorMessage: validationMessage);
          return PaymentActionResult(errorMessage: validationMessage);
        }

        _attachTopupCallbacks(razorpayOrderId: razorpayOrder.razorpayOrderId);

        try {
          _razorpayService.open(
            RazorpayOptions(
              key: razorpayOrder.key,
              amount: razorpayOrder.amount,
              razorpayOrderId: razorpayOrder.razorpayOrderId,
              name: 'Bakaloo',
              description: 'Wallet Top-up',
              contact: _currentUser?.phone,
              email: _currentUser?.email,
              prefillName: _currentUser?.name,
              themeColorHex: '#0C831F',
            ),
          );
          state = state.copyWith(
            isLoading: false,
            activeRazorpayOrderId: razorpayOrder.razorpayOrderId,
          );
          return const PaymentActionResult();
        } catch (_) {
          const message = 'Unable to open Razorpay right now.';
          state = PaymentState.idle().copyWith(errorMessage: message);
          return const PaymentActionResult(errorMessage: message);
        }
      },
    );
  }

  Future<PaymentActionResult> payOrderFromWallet(
    PlacedOrderEntity order,
  ) async {
    if (state.isLoading || state.isVerifying) {
      const message = 'A payment is already in progress.';
      state = state.copyWith(errorMessage: message);
      return const PaymentActionResult(errorMessage: message);
    }

    state = state.copyWith(
      isLoading: true,
      isVerifying: false,
      errorMessage: null,
      activeOrderId: order.id,
      isWalletTopupFlow: false,
    );

    final result = await _repository.payFromWallet(order.id);
    return result.fold(
      (failure) {
        state = PaymentState.idle().copyWith(errorMessage: failure.message);
        return PaymentActionResult(errorMessage: failure.message);
      },
      (_) {
        ref.invalidate(walletBalanceProvider);
        // ignore: cascade_invocations
        ref.invalidate(cartProvider); // Clear cart after wallet payment success
        state = PaymentState.idle();
        ref.read(appRouterProvider).go('/orders/success/${order.id}');
        return const PaymentActionResult();
      },
    );
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(errorMessage: null);
  }

  void _attachOrderCallbacks({
    required String orderId,
    required String razorpayOrderId,
  }) {
    _razorpayService
      ..onSuccess = (response) {
        unawaited(
          _verifyPayment(
            orderId: orderId,
            razorpayOrderId: razorpayOrderId,
            response: response,
          ),
        );
      }
      ..onFailure = _handleFailure
      ..onExternalWallet = (_) {
        state = state.copyWith(isLoading: false);
      };
  }

  void _attachTopupCallbacks({
    required String razorpayOrderId,
  }) {
    _razorpayService
      ..onSuccess = (response) {
        unawaited(
          _verifyWalletTopup(
            orderId: razorpayOrderId,
            response: response,
          ),
        );
      }
      ..onFailure = _handleFailure
      ..onExternalWallet = (_) {
        state = state.copyWith(isLoading: false);
      };
  }

  Future<void> _verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required PaymentSuccessResponse response,
  }) async {
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      state = PaymentState.idle().copyWith(
        errorMessage: 'Payment verification details are missing.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      isVerifying: true,
      errorMessage: null,
    );

    final result = await ref.read(verifyPaymentUseCaseProvider).call(
          PaymentVerificationParams(
            orderId: orderId,
            razorpayOrderId: razorpayOrderId,
            paymentId: paymentId,
            signature: signature,
          ),
        );

    result.fold(
      (failure) {
        state = PaymentState.idle().copyWith(errorMessage: failure.message);
      },
      (payment) {
        ref.invalidate(cartProvider); // Clear cart ONLY after confirmed payment
        state = PaymentState.idle().copyWith(lastPayment: payment);
        unawaited(
          ref.read(analyticsServiceProvider).logPurchase(
                orderId,
                payment.amount,
                (payment.method ?? 'ONLINE').toUpperCase(),
              ),
        );
        ref.read(appRouterProvider).go('/orders/success/$orderId');
      },
    );
  }

  Future<void> _verifyWalletTopup({
    required String orderId,
    required PaymentSuccessResponse response,
  }) async {
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      state = PaymentState.idle().copyWith(
        errorMessage: 'Top-up verification details are missing.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      isVerifying: true,
      errorMessage: null,
    );

    final result = await _repository.verifyWalletTopup(
      WalletTopupVerificationParams(
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
      ),
    );

    result.fold(
      (failure) {
        state = PaymentState.idle().copyWith(errorMessage: failure.message);
      },
      (_) {
        ref.invalidate(walletBalanceProvider);
        state = PaymentState.idle();
      },
    );
  }

  void _handleFailure(PaymentFailureResponse response) {
    final orderId = state.activeOrderId;
    final normalizedMessage = response.message?.trim();
    final hasMeaningfulMessage = normalizedMessage != null &&
        normalizedMessage.isNotEmpty &&
        normalizedMessage.toLowerCase() != 'undefined' &&
        normalizedMessage.toLowerCase() != 'null';
    final isCancellation =
        response.code == Razorpay.PAYMENT_CANCELLED || !hasMeaningfulMessage;

    // Best-effort: cancel the pending backend order so it doesn't linger
    if (orderId != null) {
      unawaited(
        _cancelPendingOrder(
          orderId,
          reason: isCancellation
              ? 'Payment cancelled by user'
              : 'Payment failed: $normalizedMessage',
        ),
      );
    }

    state = PaymentState.idle().copyWith(
      errorMessage: isCancellation
          ? 'Payment cancelled. You can try again.'
          : (hasMeaningfulMessage
              ? normalizedMessage
              : 'Payment failed. Please try again.'),
    );
    // NOTE: cartProvider is NOT invalidated here.
    // The user's cart items are preserved for retry.
  }

  Future<void> _cancelPendingOrder(
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
      // Silent fail — backend auto-cancels unpaid orders after timeout.
      // Best effort only. If reorder fails, the existing cart state in memory
      // still lets the user retry without getting stuck on a blank flow.
    }
  }

  void _resetCallbacks() {
    _razorpayService
      ..onSuccess = null
      ..onFailure = null
      ..onExternalWallet = null;
  }

  String? _validateRazorpayOrder(RazorpayOrderEntity order) {
    if (order.key.trim().isEmpty) {
      return 'Online payment is not configured. Please try wallet payment.';
    }
    if (order.razorpayOrderId.trim().isEmpty) {
      return 'Payment order ID is missing. Please try again.';
    }
    if (order.amount <= 0) {
      return 'Invalid payment amount received. Please try again.';
    }
    return null;
  }
}
