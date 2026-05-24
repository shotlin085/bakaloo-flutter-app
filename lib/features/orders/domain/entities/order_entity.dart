import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';

part 'order_entity.freezed.dart';

@freezed
abstract class OrderEntity with _$OrderEntity {
  const OrderEntity._();

  const factory OrderEntity({
    required String id,
    required String orderNumber,
    required OrderStatus status,
    required List<OrderItemEntity> items,
    required double subtotal,
    required double discount,
    required double deliveryFee,
    required double platformFee,
    required double total,
    required Map<String, dynamic> deliveryAddress,
    required String paymentMethod,
    required String paymentStatus,
    required DateTime createdAt,
    String? razorpayPaymentId,
    String? couponCode,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    DateTime? estimatedDelivery,
    @Default(<String, dynamic>{}) Map<String, dynamic> tracking,
    @Default(<OrderTimelineEntity>[]) List<OrderTimelineEntity> timeline,
  }) = _OrderEntity;

  List<OrderTimelineEntity> get statusHistory => timeline;

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  bool get isActive => status.isActive;
}
