import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';

part 'cart_item_model.freezed.dart';
part 'cart_item_model.g.dart';

double _cartDoubleFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _cartNullableDoubleFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

@freezed
abstract class CartItemModel with _$CartItemModel {
  const CartItemModel._();

  const factory CartItemModel({
    required String productId,
    required String name,
    @JsonKey(fromJson: _cartDoubleFromJson) required double price,
    required int quantity,
    @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson)
    required double total,
    @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
    double? salePrice,
    String? unit,
    String? thumbnailUrl,
  }) = _CartItemModel;

  factory CartItemModel.fromJson(Map<String, dynamic> json) =>
      _$CartItemModelFromJson(json);

  CartItemEntity toEntity() {
    return CartItemEntity(
      productId: productId,
      name: name,
      price: price,
      salePrice: salePrice,
      quantity: quantity,
      total: total,
      unit: unit,
      thumbnailUrl: thumbnailUrl,
    );
  }
}
