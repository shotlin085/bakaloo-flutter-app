import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// Maps FCM data payload to an in-app GoRouter path.
///
/// Priority:
///   1. Explicit `deepLink` field in data
///   2. Type-based routing with ID fields
///   3. null → no navigation (stay on current screen)
class NotificationRouter {
  NotificationRouter._();

  static String? getPath(Map<String, dynamic> data) {
    // 1. Explicit deepLink field takes priority
    final deepLink = _readString(data, const ['deepLink', 'deep_link']);
    if (deepLink.isNotEmpty && deepLink.startsWith('/')) {
      return deepLink;
    }

    final type = _readString(
      data,
      const ['type', 'notificationType'],
    ).toUpperCase();

    final orderId = _readString(data, const ['orderId', 'order_id']);
    final productId = _readString(data, const ['productId', 'product_id']);
    final categoryId = _readString(data, const ['categoryId', 'category_id']);

    // 2. Type-based routing
    switch (type) {
      case 'ORDER_STATUS':
      case 'ORDER_UPDATE':
        return orderId.isEmpty ? RouteNames.orders : '/orders/$orderId';

      case 'PAYMENT':
      case 'WALLET':
        return RouteNames.wallet;

      case 'PROMOTION':
      case 'OFFER':
      case 'COUPON':
        return RouteNames.categories;

      case 'DELIVERY':
      case 'RIDER_UPDATE':
        return orderId.isEmpty ? null : '/orders/$orderId/track';

      case 'CAMPAIGN':
      case 'ADMIN_BROADCAST':
      case 'SYSTEM':
        return RouteNames.notifications;

      case 'RESTOCK':
      case 'PRODUCT_OFFER':
        if (productId.isNotEmpty) return '/product/$productId';
        return RouteNames.categories;

      case 'CATEGORY_OFFER':
        if (categoryId.isNotEmpty) return '/categories/$categoryId/products';
        return RouteNames.categories;

      case 'CART_REMINDER':
        return RouteNames.cart;

      default:
        return RouteNames.notifications;
    }
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
