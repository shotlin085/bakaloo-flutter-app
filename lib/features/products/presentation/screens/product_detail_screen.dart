import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bakaloo_flutter_app/core/analytics/analytics_service.dart';
import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/recently_viewed_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_detail_compat.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_detail_socket_delegate.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_list_screen.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_bottom_bar.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_description_section.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_detail_loading_view.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_details_section.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_image_gallery.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_info_header.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_promo_banner.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_recommendation_wrappers.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_store_row.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_trust_badges.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_variant_selector.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_vendor_section.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_ids_provider.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    required this.id,
    super.key,
  });

  final String id;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late final ScrollController _scrollController;
  late ProductDetailSocketDelegate _socketDelegate;
  bool _isAppBarCollapsed = false;
  double _scrollOffset = 0;
  bool _hasLoggedView = false;
  // Which family member is currently displayed. Starts as widget.id but can
  // be swapped in place via the "Select Unit" chip row (product_variant_
  // selector.dart) without a route change — see _selectVariant.
  late String _selectedProductId;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.id;
    _scrollController = ScrollController()..addListener(_onScroll);
    _socketDelegate = _createSocketDelegate();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _socketDelegate.dispose();
    super.dispose();
  }

  ProductDetailSocketDelegate _createSocketDelegate() {
    return ProductDetailSocketDelegate(
      ref: ref,
      productId: _selectedProductId,
      onProductDataChanged: _refreshProductData,
      onCartChanged: () => ref.read(cartProvider.notifier).refresh(),
    )..setup();
  }

  // The socket delegate filters live stock/price events by a fixed
  // productId set at construction time, so swapping variants needs a fresh
  // delegate bound to the newly selected id — otherwise socket pushes for
  // the new variant would be silently ignored.
  void _selectVariant(String productId) {
    if (productId == _selectedProductId) {
      return;
    }
    _socketDelegate.dispose();
    setState(() {
      _selectedProductId = productId;
      _hasLoggedView = false;
    });
    _socketDelegate = _createSocketDelegate();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollOffset = _scrollController.offset;
    final collapsed = _scrollOffset > 260;
    if (collapsed != _isAppBarCollapsed) {
      setState(() => _isAppBarCollapsed = collapsed);
    }
  }

  void _refreshProductData() {
    ref
      ..invalidate(productDetailProvider(_selectedProductId))
      ..invalidate(pairWithProductsProvider(_selectedProductId))
      ..invalidate(relatedProductsProvider(_selectedProductId));
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(_selectedProductId));

    return productAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: ProductDetailLoadingView(),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: ErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: _refreshProductData,
        ),
      ),
      data: (product) {
        final effectiveProduct = normalizedProductForDetail(product);
        final effectiveAttributes = effectiveAttributesForDetail(
          effectiveProduct,
        );
        final isWishlisted = ref.watch(
          wishlistIdsProvider.select(
            (ids) => ids.contains(effectiveProduct.id),
          ),
        );
        final cartQty =
            ref.watch(cartItemQuantityProvider(effectiveProduct.id));

        if (!_hasLoggedView) {
          _hasLoggedView = true;
          unawaited(
            ref.read(analyticsServiceProvider).logProductView(
                  effectiveProduct.id,
                  effectiveProduct.categoryId,
                ),
          );
          unawaited(
            ref
                .read(recentlyViewedProvider.notifier)
                .recordView(effectiveProduct.id),
          );
        }

        // The gallery photo up top can be light-toned (wood/plant lifestyle
        // shots), which made the platform-default light status bar icons
        // (white time/battery/signal) unreadable against it — force dark
        // icons here regardless of collapsed state, matching the pattern
        // already used on the Home screen.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, _) => CustomScrollView(
                controller: _scrollController,
                slivers: <Widget>[
                  ProductImageGallery(
                    images: effectiveProduct.images,
                    thumbnailUrl: effectiveProduct.thumbnailUrl,
                    productName: effectiveProduct.name,
                    price: effectiveProduct.price,
                    salePrice: effectiveProduct.salePrice,
                    avgRating: effectiveProduct.avgRating,
                    ratingCount: effectiveProduct.ratingCount,
                    highlights: effectiveProduct.highlights,
                    isCollapsed: _isAppBarCollapsed,
                    scrollOffset: _scrollOffset,
                    onSearch: _navigateToSearch,
                    onShare: () => _shareProduct(effectiveProduct),
                    onBack: _handleBack,
                    onImageChanged: (index) => _logProductImageSwipe(
                      effectiveProduct,
                      index,
                    ),
                    onHighlightsToggle: () => _logProductHighlightsView(
                      effectiveProduct,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: ProductPromoBanner(scrollOffset: _scrollOffset),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: ProductInfoHeader(
                        product: effectiveProduct,
                        isWishlisted: isWishlisted,
                        onWishlistToggle: () => _toggleWishlist(
                          effectiveProduct,
                          action: isWishlisted ? 'remove' : 'add',
                        ),
                      ),
                    ),
                  ),
                  if (effectiveProduct.hasMultipleOptions)
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: ProductVariantSelector(
                          familyProductId: widget.id,
                          selectedProductId: _selectedProductId,
                          onSelect: _selectVariant,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: ProductStoreRow(productId: effectiveProduct.id),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: ProductTrustBadges(
                        product: effectiveProduct,
                        onBrandTap: () => _navigateToBrand(effectiveProduct),
                      ),
                    ),
                  ),
                  if (effectiveAttributes.isNotEmpty)
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: ProductDetailsSection(
                          attributes: effectiveAttributes,
                          onExpand: () => _logProductDetailsExpand(
                            effectiveProduct,
                            'details',
                          ),
                        ),
                      ),
                    ),
                  if ((effectiveProduct.description ?? '').trim().isNotEmpty)
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: ProductDescriptionSection(
                          description: effectiveProduct.description,
                          onExpand: () => _logProductDetailsExpand(
                            effectiveProduct,
                            'description',
                          ),
                        ),
                      ),
                    ),
                  if (effectiveProduct.hasVendorDetails)
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: ProductVendorSection(
                          vendorName: effectiveProduct.vendorName,
                          vendorAddress: effectiveProduct.vendorAddress,
                          vendorFssai: effectiveProduct.vendorFssai,
                          onExpand: () => _logProductDetailsExpand(
                            effectiveProduct,
                            'vendor',
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: SimilarWrapper(
                        productId: effectiveProduct.id,
                        enabled: _scrollOffset >= 80,
                        onProductTap: (targetProduct) => _handleSimilarTap(
                          effectiveProduct,
                          targetProduct,
                        ),
                        onSeeAll: () => _openSimilarProducts(effectiveProduct),
                        onAddToCart: _addToCart,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: RecentlyViewedWrapper(
                        productId: effectiveProduct.id,
                        enabled: _scrollOffset >= 180,
                        onProductTap: (targetProduct) =>
                            _openProduct(targetProduct),
                        onAddToCart: _addToCart,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: PairWithWrapper(
                        productId: effectiveProduct.id,
                        enabled: _scrollOffset >= 180,
                        onProductTap: (targetProduct) => _handlePairWithTap(
                          effectiveProduct,
                          targetProduct,
                        ),
                        onSeeAll: _openRecommendedProducts,
                        onAddToCart: _addToCart,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: SizedBox(height: 80),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: ProductBottomBar(
              product: effectiveProduct,
              quantity: cartQty,
              onAddToCart: () => _addSelectedVariantToCart(effectiveProduct),
              onViewCart: () => context.push(RouteNames.cart),
              onQuantityChange: (qty) => _updateCart(effectiveProduct, qty),
            ),
          ),
        );
      },
    );
  }

  void _navigateToSearch() {
    context.push(RouteNames.search);
  }

  /// A shared product link (e.g. bakaloo.in/products/:slug, opened via App
  /// Links) cold-starts the app directly onto this screen with nothing
  /// else on the navigation stack. `Navigator.pop` on an empty stack left
  /// the user staring at a black screen instead of leaving the app or
  /// going anywhere useful — check canPop first and fall back to home.
  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go(RouteNames.home);
    }
  }

  void _openProduct(ProductEntity product) {
    if (product.id == _selectedProductId) {
      return;
    }
    context.push('/product/${product.id}');
  }

  void _navigateToBrand(ProductEntity product) {
    final title = product.brandDisplay.trim().isNotEmpty
        ? product.brandDisplay.trim()
        : 'Products';
    unawaited(
      ref.read(analyticsServiceProvider).logProductBrandTap(
            product.id,
            title,
          ),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductListScreen(
          categoryId: product.categoryId,
          title: title,
        ),
      ),
    );
  }

  void _openRecommendedProducts() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProductListScreen(title: 'Recommended products'),
      ),
    );
  }

  void _openSimilarProducts(ProductEntity product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductListScreen(
          categoryId: product.categoryId,
          title: 'Similar Products',
        ),
      ),
    );
  }

  Future<void> _shareProduct(ProductEntity product) async {
    // Must match bakaloo-customer-web's actual route shape
    // (src/app/(shop)/products/[slug]/page.tsx) — plural "products", by
    // slug, not the app's own internal /product/:id route — or the link
    // 404s for anyone without the app installed (e.g. a WhatsApp preview
    // or a desktop click).
    final shareUri = Uri.tryParse(ApiConstants.webBaseUrl)?.replace(
      path: '/products/${product.slug}',
      queryParameters: null,
    );
    final message = shareUri == null
        ? 'Check out ${product.name} on Bakaloo.'
        : 'Check out ${product.name} on Bakaloo.\n$shareUri';
    await Share.share(message);
  }

  void _handlePairWithTap(
    ProductEntity currentProduct,
    ProductEntity targetProduct,
  ) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductPairWithTap(
            currentProduct.id,
            targetProduct.id,
          ),
    );
    _openProduct(targetProduct);
  }

  void _handleSimilarTap(
    ProductEntity currentProduct,
    ProductEntity targetProduct,
  ) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductSimilarTap(
            currentProduct.id,
            targetProduct.id,
          ),
    );
    _openProduct(targetProduct);
  }

  void _logProductImageSwipe(ProductEntity product, int imageIndex) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductImageSwipe(
            product.id,
            imageIndex,
          ),
    );
  }

  void _logProductHighlightsView(ProductEntity product) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductHighlightsView(product.id),
    );
  }

  void _logProductDetailsExpand(
    ProductEntity product,
    String sectionName,
  ) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductDetailsExpand(
            product.id,
            sectionName,
          ),
    );
  }

  Future<void> _toggleWishlist(
    ProductEntity product, {
    required String action,
  }) async {
    final authGate = ref.read(authGateControllerProvider);
    final allowed = await authGate.protectWishlist(context, product);
    if (!allowed || !mounted) {
      return;
    }

    unawaited(
      ref.read(analyticsServiceProvider).logWishlistToggle(
            product.id,
            action,
          ),
    );
    final result =
        await ref.read(wishlistProvider.notifier).toggleWishlist(product);
    if (!mounted || result.isSuccess) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
  }

  // Used by the recommendation rails (Pair With / Similar / Recently
  // Viewed), which have no inline unit selector of their own — a
  // multi-option product tapped from one of those rows still needs the
  // picker sheet to choose which variant to add.
  Future<void> _addToCart(ProductEntity product) async {
    if (!product.inStock) {
      showCartSnackBar(context, 'This product is currently unavailable.');
      return;
    }

    if (product.hasMultipleOptions) {
      showProductOptionsSheet(context, product);
      return;
    }

    await _addProductToCart(product);
  }

  // Used by this screen's own bottom bar. The "Select Unit" chip row
  // (when present) already lets the customer choose the exact variant
  // in place, so — unlike _addToCart — this skips straight to adding
  // whichever variant is currently displayed instead of popping the
  // options sheet again on top of it.
  Future<void> _addSelectedVariantToCart(ProductEntity product) async {
    if (!product.inStock) {
      showCartSnackBar(context, 'This product is currently unavailable.');
      return;
    }

    await _addProductToCart(product);
  }

  Future<void> _addProductToCart(ProductEntity product) async {
    final authGate = ref.read(authGateControllerProvider);
    final allowed = await authGate.protectAddToCart(context, product);
    if (!allowed || !mounted) {
      return;
    }

    unawaited(
      ref.read(analyticsServiceProvider).logAddToCart(
            product.id,
            1,
            product.effectivePrice,
          ),
    );
    final result = await ref.read(cartProvider.notifier).addItem(
          product.id,
          1,
          product: product,
        );
    if (!mounted || result.isSuccess) {
      return;
    }

    showCartSnackBar(context, result.failure!.message);
  }

  Future<void> _updateCart(ProductEntity product, int qty) async {
    final result = qty <= 0
        ? await ref.read(cartProvider.notifier).removeItem(product.id)
        : await ref.read(cartProvider.notifier).updateItem(product.id, qty);

    if (!mounted || result.isSuccess) {
      return;
    }
    showCartSnackBar(context, result.failure!.message);
  }
}
