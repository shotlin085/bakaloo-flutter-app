import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/entities/business_account_entity.dart';

class BusinessAccountRemoteDataSource {
  const BusinessAccountRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<BusinessAccountEntity?> getMine() async {
    final response = await _apiClient.getMyBusinessAccount();
    return _parseNullable(response.data);
  }

  Future<BusinessAccountEntity> apply(Map<String, dynamic> body) async {
    final response = await _apiClient.applyBusinessAccount(body);
    return _parse(response.data);
  }

  Future<BusinessAccountEntity> toggle(bool enabled) async {
    final response = await _apiClient.toggleBusinessAccount(
      <String, dynamic>{'enabled': enabled},
    );
    return _parse(response.data);
  }

  BusinessAccountEntity? _parseNullable(dynamic payload) {
    final data = _extractData(payload);
    if (data == null) {
      return null;
    }
    return _fromJson(data);
  }

  BusinessAccountEntity _parse(dynamic payload) {
    final data = _extractData(payload);
    if (data == null) {
      throw StateError('Malformed business account response');
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

  BusinessAccountEntity _fromJson(Map<String, dynamic> json) {
    return BusinessAccountEntity(
      id: (json['id'] ?? '').toString(),
      companyName: (json['company_name'] ?? json['companyName'] ?? '').toString(),
      gstNumber: (json['gst_number'] ?? json['gstNumber'] ?? '').toString(),
      status: (json['status'] ?? 'PENDING').toString(),
      b2bEnabled: (json['b2b_enabled'] ?? json['b2bEnabled']) == true,
      rejectionReason: _readNullableString(
        json,
        <String>['rejection_reason', 'rejectionReason'],
      ),
      submittedAt: _readDateTime(json, <String>['submitted_at', 'submittedAt']) ??
          DateTime.now(),
      reviewedAt: _readDateTime(json, <String>['reviewed_at', 'reviewedAt']),
    );
  }

  String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
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
