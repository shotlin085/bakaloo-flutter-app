import 'package:bakaloo_flutter_app/routing/route_names.dart';

class NotificationRouter {
  NotificationRouter._();

  static String? getPath(Map<String, dynamic> data) {
    final type = _readString(
      data,
      const <String>['type', 'notificationType'],
    ).toUpperCase();

    final orderId = _readString(
      data,
      const <String>['orderId', 'order_id', 'id'],
    );

    switch (type) {
      case 'ORDER_STATUS':
        return orderId.isEmpty ? null : '/orders/$orderId';
      case 'PAYMENT':
        return RouteNames.wallet;
      case 'PROMOTION':
        return RouteNames.categories;
      case 'DELIVERY':
        return orderId.isEmpty ? null : '/orders/$orderId/track';
      case 'ADMIN_BROADCAST':
      case 'SYSTEM':
        return RouteNames.notifications;
      default:
        return null;
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
