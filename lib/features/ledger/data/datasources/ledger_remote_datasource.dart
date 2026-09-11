import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/entities/ledger_account_entity.dart';

class LedgerRemoteDataSource {
  const LedgerRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// The caller's own ledger account, or null if none exists yet. Unlike
  /// business-accounts/me (which returns 200 with data:null), the backend
  /// returns a plain 404 here when there's no ledger account.
  Future<LedgerAccountEntity?> getMine() async {
    try {
      final response = await _apiClient.getMyLedgerAccount();
      return _parseNullable(response.data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> payFromLedger(String orderId) async {
    await _apiClient.payFromLedger(<String, dynamic>{'orderId': orderId});
  }

  LedgerAccountEntity? _parseNullable(dynamic payload) {
    final data = _extractData(payload);
    if (data == null) {
      return null;
    }
    return _fromJson(data);
  }

  Map<String, dynamic>? _extractData(dynamic payload) {
    if (payload is! Map) {
      return null;
    }
    final data = payload['data'];
    if (data is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(data);
  }

  LedgerAccountEntity _fromJson(Map<String, dynamic> json) {
    return LedgerAccountEntity(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'CLOSED').toString(),
      currentBalance: _readDouble(json, <String>['current_balance', 'currentBalance']),
      monthlyCreditLimit:
          _readDouble(json, <String>['monthly_credit_limit', 'monthlyCreditLimit']),
      hardLimit: _readDouble(json, <String>['hard_limit', 'hardLimit']),
      billingDay: _readInt(json, <String>['billing_day', 'billingDay']),
    );
  }

  double _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  int _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 1;
  }
}
