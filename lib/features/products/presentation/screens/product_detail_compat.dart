import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

ProductEntity normalizedProductForDetail(ProductEntity product) {
  final netQuantity = (product.netQuantity ?? '').trim().isNotEmpty
      ? product.netQuantity!.trim()
      : product.unit;
  return product.copyWith(netQuantity: netQuantity);
}

List<Map<String, dynamic>> effectiveAttributesForDetail(ProductEntity product) {
  if (product.hasAttributes) {
    return product.attributes!;
  }

  final attrs = <Map<String, dynamic>>[];
  if ((product.ingredients ?? '').trim().isNotEmpty) {
    attrs.add(<String, dynamic>{
      'label': 'Ingredients',
      'value': product.ingredients!,
    });
  }
  if ((product.storageInstructions ?? '').trim().isNotEmpty) {
    attrs.add(<String, dynamic>{
      'label': 'Storage Instructions',
      'value': product.storageInstructions!,
    });
  }
  if ((product.nutritionInfo ?? const <String, dynamic>{}).isNotEmpty) {
    for (final entry in product.nutritionInfo!.entries) {
      attrs.add(<String, dynamic>{
        'label': entry.key,
        'value': '${entry.value}',
      });
    }
  }
  if ((product.description ?? '').trim().isNotEmpty && attrs.isEmpty) {
    attrs.add(<String, dynamic>{
      'label': 'Description',
      'value': product.description!,
    });
  }
  return attrs;
}
