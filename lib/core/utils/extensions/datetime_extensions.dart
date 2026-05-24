import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

extension DateTimeExtensions on DateTime {
  String get toRelative {
    return timeago.format(this);
  }

  String get toIndianDate {
    return DateFormat('d MMM yyyy').format(this);
  }

  String get toIndianDateTime {
    return DateFormat('d MMM yyyy · h:mm a').format(this);
  }

  bool get isExpired => isBefore(DateTime.now());
}
