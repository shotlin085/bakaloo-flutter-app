// Plain Dart classes for the product options API response.
// Uses manual fromJson to avoid build_runner complexity.

class ProductOptionsFamily {
  const ProductOptionsFamily({
    this.id,
    this.name,
    this.slug,
    this.thumbnailUrl,
  });

  final String? id;
  final String? name;
  final String? slug;
  final String? thumbnailUrl;

  factory ProductOptionsFamily.fromJson(Map<String, dynamic> json) {
    return ProductOptionsFamily(
      id: json['id'] as String?,
      name: json['name'] as String?,
      slug: json['slug'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}

class ProductOptionItem {
  const ProductOptionItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.isAvailable,
    this.shopProductId,
    this.shopId,
    this.optionLabel,
    this.netQuantity,
    this.salePrice,
    this.stockQuantity,
    this.maxOrderQty,
    this.thumbnailUrl,
    this.images = const <String>[],
    this.foodType = 'NONE',
    this.originTag = 'NONE',
    this.customBadges = const <String>[],
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.displayDeliveryMinutes,
  });

  final String id;
  final String? shopProductId;
  final String? shopId;
  final String name;
  final String? optionLabel;
  final String unit;
  final String? netQuantity;
  final double price;
  final double? salePrice;
  final int? stockQuantity;
  final int? maxOrderQty;
  final bool isAvailable;
  final String? thumbnailUrl;
  final List<String> images;
  final String foodType;
  final String originTag;
  final List<String> customBadges;
  final double avgRating;
  final int ratingCount;
  final int? displayDeliveryMinutes;

  double get effectivePrice {
    if (salePrice != null && salePrice! > 0 && salePrice! < price) {
      return salePrice!;
    }
    return price;
  }

  int get discountPercent {
    if (salePrice == null || salePrice! >= price || price <= 0) return 0;
    return (((price - salePrice!) / price) * 100).round();
  }

  double get discountAmount {
    if (salePrice == null || salePrice! >= price) return 0;
    return price - salePrice!;
  }

  bool get inStock =>
      isAvailable && (stockQuantity == null || stockQuantity! > 0);

  bool get isVeg => foodType == 'VEG';
  bool get isNonVeg => foodType == 'NON_VEG';
  bool get isEgg => foodType == 'EGG';
  bool get hasFoodMarker => foodType != 'NONE';

  String get displayUnit => optionLabel ?? netQuantity ?? unit;

  factory ProductOptionItem.fromJson(Map<String, dynamic> json) {
    return ProductOptionItem(
      id: json['id'] as String? ?? '',
      shopProductId: json['shopProductId'] as String?,
      shopId: json['shopId'] as String?,
      name: json['name'] as String? ?? '',
      optionLabel: json['optionLabel'] as String?,
      unit: json['unit'] as String? ?? 'unit',
      netQuantity: json['netQuantity'] as String?,
      price: _toDouble(json['price']),
      salePrice: _toNullableDouble(json['salePrice']),
      stockQuantity: json['stockQuantity'] as int?,
      maxOrderQty: json['maxOrderQty'] as int?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      images: _toStringList(json['images']),
      foodType: json['foodType'] as String? ?? 'NONE',
      originTag: json['originTag'] as String? ?? 'NONE',
      customBadges: _toStringList(json['customBadges']),
      avgRating: _toDouble(json['avgRating']),
      ratingCount: json['ratingCount'] as int? ?? 0,
      displayDeliveryMinutes: json['displayDeliveryMinutes'] as int?,
    );
  }
}

class ProductOptionsResponse {
  const ProductOptionsResponse({
    this.family,
    this.options = const <ProductOptionItem>[],
  });

  final ProductOptionsFamily? family;
  final List<ProductOptionItem> options;

  factory ProductOptionsResponse.fromJson(Map<String, dynamic> json) {
    final familyJson = json['family'];
    final optionsJson = json['options'];

    return ProductOptionsResponse(
      family: familyJson is Map
          ? ProductOptionsFamily.fromJson(
              Map<String, dynamic>.from(familyJson),
            )
          : null,
      options: optionsJson is List
          ? optionsJson
              .whereType<Map>()
              .map(
                (item) => ProductOptionItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ProductOptionItem>[],
    );
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? _toNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<String> _toStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}
