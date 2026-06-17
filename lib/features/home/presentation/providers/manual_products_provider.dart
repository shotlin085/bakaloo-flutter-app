import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

/// Fetches a list of specific product IDs directly from the API.
///
/// Used by manual-source product grid sections so that hand-picked products
/// always render even when they are not in the home page's base product pool
/// (e.g. products from categories not loaded on the home feed).
///
/// Results are cached per unique sorted list of IDs for the session.
final manualProductsByIdsProvider = FutureProvider.autoDispose
    .family<List<ProductEntity>, List<String>>(
  (ref, ids) async {
    if (ids.isEmpty) return const <ProductEntity>[];

    final dio = ref.watch(dioClientProvider);

    // Fetch all IDs concurrently
    final futures = ids.map((id) async {
      try {
        final response =
            await dio.get<dynamic>('/api/v1/products/$id');
        final body = response.data;
        if (body is! Map) return null;
        final data = body['data'];
        if (data is! Map) return null;
        return ProductModel.fromJson(
          Map<String, dynamic>.from(data),
        ).toEntity();
      } catch (_) {
        return null; // skip failed individual fetches
      }
    });

    final results = await Future.wait(futures);
    return results.whereType<ProductEntity>().toList();
  },
);
