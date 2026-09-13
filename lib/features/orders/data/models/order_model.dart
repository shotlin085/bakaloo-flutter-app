import 'dart:convert';

import 'package:bakaloo_flutter_app/features/orders/data/models/b2b_settlement_model.dart';
import 'package:bakaloo_flutter_app/features/orders/data/models/order_item_model.dart';
import 'package:bakaloo_flutter_app/features/orders/data/models/order_timeline_model.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';

class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.platformFee,
    required this.total,
    required this.deliveryAddress,
    required this.tracking,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    this.walletAmountUsed = 0,
    this.razorpayPaymentId,
    this.couponCode,
    this.deliveredAt,
    this.cancelledAt,
    this.estimatedDelivery,
    this.timeline = const <OrderTimelineModel>[],
    this.deliveryMode = 'ASAP',
    this.scheduledSlotLabel,
    this.scheduledSlotStart,
    this.scheduledSlotEnd,
    this.deliveryOtp,
    this.b2bApprovalStatus,
    this.b2bAmountSettled = 0,
    this.b2bPaymentDueDate,
    this.b2bSettlements = const <B2BSettlementModel>[],
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final List<OrderItemModel> items;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double platformFee;
  final double total;
  final Map<String, dynamic> deliveryAddress;
  final Map<String, dynamic> tracking;
  final String paymentMethod;
  final String paymentStatus;
  final double walletAmountUsed;
  final String? razorpayPaymentId;
  final String? couponCode;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime? estimatedDelivery;
  final List<OrderTimelineModel> timeline;
  final String deliveryMode;
  final String? scheduledSlotLabel;
  final DateTime? scheduledSlotStart;
  final DateTime? scheduledSlotEnd;
  final String? deliveryOtp;
  final String? b2bApprovalStatus;
  final double b2bAmountSettled;
  final DateTime? b2bPaymentDueDate;
  final List<B2BSettlementModel> b2bSettlements;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final createdAt = _readDateTime(
          json,
          <String>['createdAt', 'created_at'],
        ) ??
        DateTime.now();

    final status = orderStatusFromRaw(
      _readString(json, <String>['status'], fallback: 'PENDING'),
    );

    final deliveredAt =
        _readDateTime(json, <String>['deliveredAt', 'delivered_at']);
    final cancelledAt =
        _readDateTime(json, <String>['cancelledAt', 'cancelled_at']);
    final updatedAt = _readDateTime(json, <String>['updatedAt', 'updated_at']);

    final timeline = _readTimeline(json);
    final normalizedTimeline = timeline.isNotEmpty
        ? timeline
        : _fallbackTimeline(
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deliveredAt: deliveredAt,
            cancelledAt: cancelledAt,
          );

    return OrderModel(
      id: _readString(json, <String>['id']),
      orderNumber: _readString(
        json,
        <String>['orderNumber', 'order_number'],
      ),
      status: status,
      items: _readItems(json),
      subtotal: _readDouble(json, <String>['subtotal']),
      discount: _readDouble(
        json,
        <String>['discount', 'discountAmount', 'discount_amount'],
      ),
      deliveryFee: _readDouble(
        json,
        <String>['deliveryFee', 'delivery_fee'],
      ),
      platformFee: _readDouble(
        json,
        <String>['platformFee', 'platform_fee'],
      ),
      total: _readDouble(
        json,
        <String>['total', 'totalAmount', 'total_amount'],
      ),
      deliveryAddress: _readMap(
        json,
        <String>['deliveryAddress', 'delivery_address'],
      ),
      tracking: _readMap(json, <String>['tracking']),
      paymentMethod: _readString(
        json,
        <String>['paymentMethod', 'payment_method'],
      ),
      paymentStatus: _readString(
        json,
        <String>['paymentStatus', 'payment_status'],
      ),
      walletAmountUsed: _readDouble(
        json,
        <String>['walletAmountUsed', 'wallet_amount_used'],
      ),
      razorpayPaymentId: _readNullableString(
        json,
        <String>['razorpayPaymentId', 'razorpay_payment_id'],
      ),
      couponCode: _readNullableString(
        json,
        <String>['couponCode', 'coupon_code'],
      ),
      createdAt: createdAt,
      deliveredAt: deliveredAt,
      cancelledAt: cancelledAt,
      estimatedDelivery: _readDateTime(
        json,
        <String>['estimatedDelivery', 'estimated_delivery'],
      ),
      timeline: normalizedTimeline,
      deliveryMode: _readString(
        json, <String>['deliveryMode', 'delivery_mode'], fallback: 'ASAP',),
      scheduledSlotLabel: _readNullableString(
        json, <String>['scheduledSlotLabel', 'scheduled_slot_label'],),
      scheduledSlotStart: _readDateTime(
        json, <String>['scheduledSlotStart', 'scheduled_slot_start'],),
      scheduledSlotEnd: _readDateTime(
        json, <String>['scheduledSlotEnd', 'scheduled_slot_end'],),
      deliveryOtp: _readNullableString(
        json, <String>['deliveryOtp', 'delivery_otp'],),
      b2bApprovalStatus: _readNullableString(
        json, <String>['b2bApprovalStatus', 'b2b_approval_status'],),
      b2bAmountSettled: _readDouble(
        json, <String>['b2bAmountSettled', 'b2b_amount_settled'],),
      b2bPaymentDueDate: _readDateTime(
        json, <String>['b2bPaymentDueDate', 'b2b_payment_due_date'],),
      b2bSettlements: _readSettlements(json),
    );
  }

  OrderEntity toEntity() {
    return OrderEntity(
      id: id,
      orderNumber: orderNumber,
      status: status,
      items: items.map((item) => item.toEntity()).toList(growable: false),
      subtotal: subtotal,
      discount: discount,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      total: total,
      deliveryAddress: Map<String, dynamic>.from(deliveryAddress),
      tracking: Map<String, dynamic>.from(tracking),
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      walletAmountUsed: walletAmountUsed,
      razorpayPaymentId: razorpayPaymentId,
      couponCode: couponCode,
      createdAt: createdAt,
      deliveredAt: deliveredAt,
      cancelledAt: cancelledAt,
      estimatedDelivery: estimatedDelivery,
      timeline: timeline.map((item) => item.toEntity()).toList(growable: false),
      deliveryMode: deliveryMode,
      scheduledSlotLabel: scheduledSlotLabel,
      scheduledSlotStart: scheduledSlotStart,
      scheduledSlotEnd: scheduledSlotEnd,
      deliveryOtp: deliveryOtp,
      b2bApprovalStatus: b2bApprovalStatus,
      b2bAmountSettled: b2bAmountSettled,
      b2bPaymentDueDate: b2bPaymentDueDate,
      b2bSettlements:
          b2bSettlements.map((item) => item.toEntity()).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'orderNumber': orderNumber,
      'status': status.name,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'subtotal': subtotal,
      'discount': discount,
      'deliveryFee': deliveryFee,
      'platformFee': platformFee,
      'total': total,
      'deliveryAddress': deliveryAddress,
      'tracking': tracking,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'walletAmountUsed': walletAmountUsed,
      'razorpayPaymentId': razorpayPaymentId,
      'couponCode': couponCode,
      'createdAt': createdAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'estimatedDelivery': estimatedDelivery?.toIso8601String(),
      'timeline': timeline.map((item) => item.toJson()).toList(growable: false),
    };
  }

  static List<OrderItemModel> _readItems(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      return const <OrderItemModel>[];
    }

    return rawItems
        .whereType<Map>()
        .map((item) => OrderItemModel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static List<B2BSettlementModel> _readSettlements(Map<String, dynamic> json) {
    final raw = json['b2bSettlements'] ?? json['b2b_settlements'];
    if (raw is! List) {
      return const <B2BSettlementModel>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => B2BSettlementModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  static List<OrderTimelineModel> _readTimeline(Map<String, dynamic> json) {
    final raw =
        json['timeline'] ?? json['statusHistory'] ?? json['status_history'];
    if (raw is! List) {
      return const <OrderTimelineModel>[];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => OrderTimelineModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  static List<OrderTimelineModel> _fallbackTimeline({
    required OrderStatus status,
    required DateTime createdAt,
    required DateTime? updatedAt,
    required DateTime? deliveredAt,
    required DateTime? cancelledAt,
  }) {
    final entries = <OrderTimelineModel>[
      OrderTimelineModel(
        type: OrderTimelineType.PENDING,
        status: OrderStatus.PENDING,
        timestamp: createdAt,
        message: 'Order placed',
      ),
    ];

    if (status != OrderStatus.PENDING) {
      entries.add(
        OrderTimelineModel(
          type: orderTimelineTypeForStatus(status),
          status: status,
          timestamp: deliveredAt ?? cancelledAt ?? updatedAt ?? createdAt,
        ),
      );
    }
    return entries;
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static double _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  static DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static Map<String, dynamic> _readMap(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      if (value is String && value.trim().isNotEmpty) {
        try {
          final decoded = _decodeMap(value);
          if (decoded.isNotEmpty) {
            return decoded;
          }
        } catch (_) {}
      }
    }
    return const <String, dynamic>{};
  }

  static Map<String, dynamic> _decodeMap(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty || !normalized.startsWith('{')) {
      return const <String, dynamic>{};
    }
    final decoded = jsonDecode(normalized);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return const <String, dynamic>{};
  }
}
