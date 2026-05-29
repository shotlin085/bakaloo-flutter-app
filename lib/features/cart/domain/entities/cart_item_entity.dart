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
    String? thumbnailUrl,
    String? shopProductId,
    String? shopId,
    String? optionLabel,
    String? familyName,
    String? foodType,
    String? originTag,
  }) = _CartItemEntity;

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
