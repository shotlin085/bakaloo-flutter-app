import 'package:bakaloo_flutter_app/features/orders/domain/entities/b2b_settlement_entity.dart';

class B2BSettlementModel {
  const B2BSettlementModel({
    required this.id,
    required this.method,
    required this.amount,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String method;
  final double amount;
  final DateTime createdAt;
  final String? note;

  factory B2BSettlementModel.fromJson(Map<String, dynamic> json) {
    return B2BSettlementModel(
      id: _readString(json, <String>['id']),
      method: _readString(json, <String>['method'], fallback: 'OTHER'),
      amount: _readDouble(json, <String>['amount']),
      createdAt: _readDateTime(
            json,
            <String>['createdAt', 'created_at'],
          ) ??
          DateTime.now(),
      note: _readNullableString(json, <String>['note']),
    );
  }

  B2BSettlementEntity toEntity() {
    return B2BSettlementEntity(
      id: id,
      method: method,
      amount: amount,
      createdAt: createdAt,
      note: note,
    );
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
}
