import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/data/models/spin_prize_model.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_appearance.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_eligibility.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_result.dart';

class SpinWheelRemoteDataSource {
  const SpinWheelRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SpinPrizeModel>> getConfig() async {
    final response = await _apiClient.getSpinWheelConfig();
    final payload = _parsePayload(response.data, ApiConstants.spinWheelConfig);
    final data = payload['data'];
    if (data is! List) {
      return const <SpinPrizeModel>[];
    }
    return data
        .whereType<Map>()
        .map((item) => SpinPrizeModel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<SpinAppearance> getAppearance() async {
    final response = await _apiClient.getSpinWheelAppearance();
    final payload = _parsePayload(
      response.data,
      ApiConstants.spinWheelAppearance,
    );
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.spinWheelAppearance),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.spinWheelAppearance),
          statusCode: 500,
          data: payload,
        ),
      );
    }
    return SpinAppearance.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SpinEligibility> getEligibility() async {
    final response = await _apiClient.getSpinWheelEligibility();
    final payload = _parsePayload(
      response.data,
      ApiConstants.spinWheelEligibility,
    );
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.spinWheelEligibility),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.spinWheelEligibility),
          statusCode: 500,
          data: payload,
        ),
      );
    }
    return SpinEligibility.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SpinResult> spin() async {
    final response = await _apiClient.spinWheel();
    final payload = _parsePayload(response.data, ApiConstants.spinWheelSpin);
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.spinWheelSpin),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.spinWheelSpin),
          statusCode: 500,
          data: payload,
        ),
      );
    }
    return SpinResult.fromJson(Map<String, dynamic>.from(data));
  }

  Map<String, dynamic> _parsePayload(dynamic raw, String path) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw DioException.badResponse(
      statusCode: 500,
      requestOptions: RequestOptions(path: path),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: 500,
        data: raw,
      ),
    );
  }
}
