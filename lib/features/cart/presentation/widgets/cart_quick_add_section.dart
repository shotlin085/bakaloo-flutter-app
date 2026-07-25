import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_misc_widgets.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_pair_with_section.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';

/// "Quick Add" rail — sits below the cart's item list, surfacing products
/// the customer is likely to want given what's already in the cart (see
/// cartQuickAddProductsProvider for the same/related/random-popular mix).
class CartQuickAddSection extends ConsumerWidget {
  const CartQuickAddSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(cartQuickAddProductsProvider);

    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) => products.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: <Widget>[
                ProductRecommendationsStrip(
                  title: 'Quick Add',
                  products: products,
                  onProductTap: (product) =>
                      context.push('/product/${product.id}'),
                  onAddToCart: (product) => _addToCart(context, ref, product),
                ),
                const CartSectionDivider(),
              ],
            ),
    );
  }

  Future<void> _addToCart(
    BuildContext context,
    WidgetRef ref,
    ProductEntity product,
  ) async {
    if (!product.inStock) {
      showCartSnackBar(context, 'This product is currently unavailable.');
      return;
    }

    // A multi-option product has no inline unit selector on this card —
    // same as the product-detail recommendation rails, route it through
    // the picker sheet instead of guessing which variant to add.
    if (product.hasMultipleOptions) {
      showProductOptionsSheet(context, product);
      return;
    }

    final result = await ref
        .read(cartProvider.notifier)
        .addItem(product.id, 1, product: product);
    if (!context.mounted || result.isSuccess) {
      return;
    }
    showCartSnackBar(context, result.failure!.message);
  }
}
