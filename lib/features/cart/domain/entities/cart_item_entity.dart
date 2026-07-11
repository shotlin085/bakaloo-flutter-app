import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_item_entity.freezed.dart';

@freezed
abstract class CartItemEntity with _$CartItemEntity {
  const CartItemEntity._();

  const factory CartItemEntity({
    required String productId,
    required String name,
    required double price,
    required int quantity,
    required double total,
    double? salePrice,
    String? unit,
    /// Full pack-size string as the shopper should see it (e.g. "200 gm"),
    /// distinct from [unit] which is just the bare unit code (e.g. "g").
    String? netQuantity,
    String? thumbnailUrl,
    String? shopProductId,
    String? shopId,
    String? optionLabel,
    String? familyName,
    String? foodType,
    String? originTag,
    int? displayDeliveryMinutes,
  }) = _CartItemEntity;

  /// Mirrors [ProductEntity.displayUnit]: prefer the specific option label,
  /// then the full pack-size string, falling back to the bare unit code.
  String get displayUnit => optionLabel ?? netQuantity ?? unit ?? '1 unit';

  double get effectivePrice {
    if (salePrice != null && salePrice! > 0 && salePrice! < price) {
      return salePrice!;
    }
    return price;
  }

  double get savingsPerUnit {
    if (salePrice == null || salePrice! >= price) {
      return 0;
    }
    return price - salePrice!;
  }

  double get totalSavings => savingsPerUnit * quantity;
}
