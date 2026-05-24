import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_entity.freezed.dart';

@freezed
abstract class ProductEntity with _$ProductEntity {
  const ProductEntity._();

  const factory ProductEntity({
    required String id,
    required String name,
    required String slug,
    required double price,
    required int stockQuantity,
    required String unit,
    required List<String> images,
    required List<String> tags,
    required bool isFeatured,
    required bool isActive,
    required int totalSold,
    double? salePrice,
    String? categoryId,
    String? categoryName,
    String? thumbnailUrl,
    String? description,
    String? ingredients,
    Map<String, dynamic>? nutritionInfo,
    String? storageInstructions,
    String? brand,
    String? brandLogoUrl,
    String? netQuantity,
    Map<String, dynamic>? highlights,
    List<Map<String, dynamic>>? attributes,
    String? vendorName,
    String? vendorAddress,
    String? vendorFssai,
    @Default('no_return') String returnPolicy,
    @Default(0.0) double avgRating,
    @Default(0) int ratingCount,
    @Default(true) bool isAuthentic,
  }) = _ProductEntity;

  bool get isOnSale =>
      salePrice != null && salePrice! > 0 && salePrice! < price;

  double get effectivePrice => isOnSale ? salePrice! : price;

  bool get inStock => stockQuantity > 0 && isActive;

  bool get lowStock => inStock && stockQuantity < 10;

  String get brandDisplay => brand ?? categoryName ?? '';

  bool get hasHighlights => highlights != null && highlights!.isNotEmpty;

  bool get hasAttributes => attributes != null && attributes!.isNotEmpty;

  bool get hasVendorDetails => vendorName != null && vendorName!.isNotEmpty;

  String get formattedRating {
    if (avgRating <= 0) return '';
    final count = ratingCount >= 1000
        ? '${(ratingCount / 1000).toStringAsFixed(1)}k'
        : '$ratingCount';
    return '${avgRating.toStringAsFixed(1)} ★ $count';
  }

  bool get hasNoReturn => returnPolicy == 'no_return';

  int get discountPercent {
    if (salePrice == null || salePrice! >= price) return 0;
    return (((price - salePrice!) / price) * 100).round();
  }
}
