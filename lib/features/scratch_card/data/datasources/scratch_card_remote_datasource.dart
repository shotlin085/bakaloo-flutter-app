import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_appearance.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_eligibility.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_result.dart';

class ScratchCardRemoteDataSource {
  const ScratchCardRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<ScratchAppearance> getAppearance() async {
    final response = await _apiClient.getScratchCardAppearance();
    final payload = _parsePayload(response.data, ApiConstants.scratchCardAppearance);
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.scratchCardAppearance),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.scratchCardAppearance),
          statusCode: 500,
          data: payload,
        ),
      );
    }
    return ScratchAppearance.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ScratchEligibility> getEligibility() async {
    final response = await _apiClient.getScratchCardEligibility();
    final payload = _parsePayload(response.data, ApiConstants.scratchCardEligibility);
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.scratchCardEligibility),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.scratchCardEligibility),
          statusCode: 500,
          data: payload,
        ),
      );
    }
    return ScratchEligibility.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ScratchResult> scratch() async {
    final response = await _apiClient.scratchCard();
    final payload = _parsePayload(response.data, ApiConstants.scratchCardScratch);
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.scratchCardScratch),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.scratchCardScratch),
          statusCode: 500,
          data: payload,
        ),
      );
    }
    return ScratchResult.fromJson(Map<String, dynamic>.from(data));
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
