import 'package:flutter/material.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_option_bottom_sheet.dart';

void showProductOptionsSheet(BuildContext context, ProductEntity product) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProductOptionBottomSheet(product: product),
  );
}
