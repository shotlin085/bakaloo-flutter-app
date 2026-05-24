import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';

final orderDetailProvider = FutureProvider.family<OrderEntity, String>((
  Ref ref,
  String orderId,
) async {
  final result = await ref.read(getOrderDetailUseCaseProvider).call(orderId);
  return result.fold(
    (failure) => throw StateError(failure.message),
    (order) => order,
  );
});
