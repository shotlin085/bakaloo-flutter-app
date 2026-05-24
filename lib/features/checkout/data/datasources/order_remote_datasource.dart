import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/models/order_model.dart';

class OrderRemoteDataSource {
  const OrderRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<OrderModel> placeOrder(Map<String, dynamic> body) async {
    final response = await _apiClient.placeOrder(body);
    final payload = _parsePayload(response.data, ApiConstants.orders);
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.orders),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.orders),
          statusCode: 500,
          data: payload,
        ),
      );
    }

    return OrderModel.fromJson(Map<String, dynamic>.from(data));
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
