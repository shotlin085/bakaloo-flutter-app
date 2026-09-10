import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';

/// Appends `priceMode=wholesale` to every outgoing request while the
/// customer has wholesale pricing active — confirmed against the backend
/// (products/cart/orders controllers) that `priceMode` is read uniformly
/// from the query string regardless of HTTP method, so one central
/// interceptor covers every current and future priceMode-aware endpoint
/// without each repository/datasource needing to thread the param through
/// by hand. The backend re-verifies the account is actually APPROVED and
/// enabled before honoring this — it is never trusted from the client
/// alone, so sending it on an endpoint that ignores it (or for a B2C
/// account) is inert.
///
/// Reads Hive directly (not a Riverpod ref) so this stays a plain,
/// synchronous, zero-dependency Interceptor — mirrors how ApiInterceptor
/// reads the auth token from SecureStorageService rather than through the
/// provider graph.
class PriceModeInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final cached = HiveService.settingsBox.get(StorageKeys.cachePriceMode);
    if (cached == 'wholesale') {
      options.queryParameters = <String, dynamic>{
        ...options.queryParameters,
        'priceMode': 'wholesale',
      };
    }
    handler.next(options);
  }
}
