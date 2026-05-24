import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';

final activeOrderProvider = FutureProvider<OrderEntity?>((Ref ref) async {
  final isAuthenticated = ref.watch(authStateProvider) is AuthAuthenticated;
  if (!isAuthenticated) {
    return null;
  }

  final result = await ref.read(getActiveOrderUseCaseProvider).call();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (order) => order,
  );
});
