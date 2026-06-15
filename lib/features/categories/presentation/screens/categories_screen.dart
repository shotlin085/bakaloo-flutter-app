import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/empty_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

/// Categories accent (premium violet, consistent with Orders/Product screens).
const Color _accent = AppColors.orderViolet;
const Color _accentSurface = AppColors.orderVioletSurface;

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String? _selectedParentId;
  String? _selectedFeedId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryCollectionProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const _CategoriesHeader(),
            Expanded(
              child: categoriesAsync.when(
                loading: _buildLoading,
                error: (error, stackTrace) => ErrorState(
                  message: 'Categories could not be loaded.',
                  onRetry: () => ref.invalidate(categoryCollectionProvider),
                ),
                data: _buildData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildData(List<CategoryEntity> categories) {
    if (categories.isEmpty) {
      return const EmptyState(
        title: 'No categories available',
        message: 'Categories will show up here once the API returns them.',
      );
    }

    final sorted = <CategoryEntity>[
      ...categories.where((category) => category.isActive),
    ]..sort((a, b) {
        final sortOrder = a.sortOrder.compareTo(b.sortOrder);
        if (sortOrder != 0) {
          return sortOrder;
        }
        return a.name.compareTo(b.name);
      });

    final parents =
        sorted.where((category) => category.isParent).toList(growable: false);
    final rootCategories = parents.isNotEmpty ? parents : sorted;
    _selectedParentId ??= rootCategories.first.id;

    final selectedParent = rootCategories.firstWhere(
      (category) => category.id == _selectedParentId,
      orElse: () => rootCategories.first,
    );
    final childCategories = sorted
        .where((category) => category.parentId == selectedParent.id)
        .toList(growable: false);

    final validFeedIds = <String>{
      selectedParent.id,
      ...childCategories.map((category) => category.id),
    };
    final selectedFeedId = validFeedIds.contains(_selectedFeedId)
        ? _selectedFeedId!
        : selectedParent.id;
    _selectedFeedId = selectedFeedId;

    final activeCategoryIds = selectedFeedId == selectedParent.id
        ? <String>[
            selectedParent.id,
            ...childCategories.map((category) => category.id),
          ]
        : <String>[selectedFeedId];

    final highlightedCategory = selectedFeedId == selectedParent.id
        ? selectedParent
        : childCategories.firstWhere(
            (category) => category.id == selectedFeedId,
            orElse: () => selectedParent,
          );

    final productsAsync = ref.watch(
      categoryProductShelfProvider(
        CategoryProductShelfRequest(
          categoryIds: activeCategoryIds,
          limitPerCategory: selectedFeedId == selectedParent.id ? 8 : 14,
          maxItems: 24,
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CategoryRail(
          categories: rootCategories,
          selectedCategoryId: selectedParent.id,
          onSelect: (category) {
            setState(() {
              _selectedParentId = category.id;
              _selectedFeedId = category.id;
            });
          },
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _CategoryProductPane(
              key: ValueKey<String>('${selectedParent.id}-$selectedFeedId'),
              selectedParent: selectedParent,
              highlightedCategory: highlightedCategory,
              childCategories: childCategories,
              selectedFeedId: selectedFeedId,
              productsAsync: productsAsync,
              onSelectChild: (categoryId) {
                setState(() {
                  _selectedFeedId = categoryId;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 92.w,
          color: AppColors.bgPrimary,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < 8; i++) ...<Widget>[
                const SkeletonLoader(height: 64, radius: 16),
                Gap(12.h),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 24.h),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 14.h,
                mainAxisExtent: 256.h,
              ),
              itemBuilder: (_, __) =>
                  const SkeletonLoader(height: 220, radius: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoriesHeader extends ConsumerWidget {
  const _CategoriesHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Categories', style: AppTextStyles.h1),
                SizedBox(height: 2.h),
                Text(
                  'Shop from the widest range',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          _HeaderIconButton(
            icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
            semanticLabel: 'Search',
            onTap: () => context.push(RouteNames.search),
          ),
          SizedBox(width: 10.w),
          _HeaderIconButton(
            icon: PhosphorIcons.shoppingCartSimple(PhosphorIconsStyle.bold),
            semanticLabel: 'Cart',
            badgeCount: cartCount,
            onTap: () => context.push(RouteNames.cart),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.badgeCount = 0,
  });

  final PhosphorIconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46.w,
          height: 46.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Center(
                  child: PhosphorIcon(icon, size: 19.sp, color: _accent),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 2.w,
                  top: 2.h,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    constraints: BoxConstraints(minWidth: 16.w),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(100.r),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  final List<CategoryEntity> categories;
  final String selectedCategoryId;
  final ValueChanged<CategoryEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92.w,
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(
          right: BorderSide(color: AppColors.divider),
        ),
      ),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryRailItem(
            category: category,
            isSelected: category.id == selectedCategoryId,
            onTap: () => onSelect(category),
          );
        },
      ),
    );
  }
}

class _CategoryRailItem extends StatelessWidget {
  const _CategoryRailItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final CategoryEntity category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Material(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Stack(
            children: <Widget>[
              // Active indicator bar on the left edge.
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 14.h,
                  bottom: 14.h,
                  child: Container(
                    width: 3.w,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isSelected ? AppColors.orderVioletBorder
                        : Colors.transparent,
                  ),
                ),
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
                child: Column(
                  children: <Widget>[
                    _CategoryThumb(
                      imageUrl: category.imageUrl,
                      name: category.name,
                      isSelected: isSelected,
                    ),
                    Gap(6.h),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5.sp,
                        color: isSelected ? _accent : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category thumbnail with a premium fallback (tinted monogram) when the API
/// returns no image — which is currently the common case.
class _CategoryThumb extends StatelessWidget {
  const _CategoryThumb({
    required this.imageUrl,
    required this.name,
    required this.isSelected,
  });

  final String? imageUrl;
  final String name;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final size = 46.w;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSelected ? _accentSurface : AppColors.bgInput,
        borderRadius: BorderRadius.circular(14.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              memCacheWidth: 160,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const SkeletonLoader(height: 46, radius: 14),
              errorWidget: (context, url, error) =>
                  _Monogram(name: name, isSelected: isSelected),
            )
          : _Monogram(name: name, isSelected: isSelected),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.isSelected});

  final String name;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final letter =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: isSelected ? _accent : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _CategoryProductPane extends StatelessWidget {
  const _CategoryProductPane({
    required this.selectedParent,
    required this.highlightedCategory,
    required this.childCategories,
    required this.selectedFeedId,
    required this.productsAsync,
    required this.onSelectChild,
    super.key,
  });

  final CategoryEntity selectedParent;
  final CategoryEntity highlightedCategory;
  final List<CategoryEntity> childCategories;
  final String selectedFeedId;
  final AsyncValue<List<ProductEntity>> productsAsync;
  final ValueChanged<String> onSelectChild;

  @override
  Widget build(BuildContext context) {
    final loadedCount = productsAsync.asData?.value.length ?? 0;
    final totalCount = selectedParent.productCount;
    final countLabel = loadedCount == 0
        ? '$totalCount products'
        : '$loadedCount products';

    final feedCategoryId = selectedFeedId;
    final feedCategoryName = selectedFeedId == selectedParent.id
        ? selectedParent.name
        : highlightedCategory.name;

    return CustomScrollView(
      key: key,
      slivers: <Widget>[
        if (childCategories.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 38.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _CategoryFilterChip(
                      label: 'All',
                      selected: selectedFeedId == selectedParent.id,
                      onTap: () => onSelectChild(selectedParent.id),
                    ),
                    ...childCategories.map(
                      (category) => Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: _CategoryFilterChip(
                          label: category.name,
                          selected: selectedFeedId == category.id,
                          onTap: () => onSelectChild(category.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 10.h),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        feedCategoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        countLabel,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        productsAsync.when(
          loading: _buildLoadingSliver,
          error: (error, stackTrace) => SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              message: error.toString().replaceFirst('Bad state: ', ''),
              onRetry: () {},
            ),
          ),
          data: (products) {
            if (products.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: 'No products in this aisle yet',
                  message:
                      'Try a different category or check back once more inventory is added.',
                ),
              );
            }

            return SliverPadding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 4.h),
              sliver: SliverGrid.builder(
                itemCount: products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 14.h,
                  mainAxisExtent: 256.h,
                ),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return TweenAnimationBuilder<double>(
                        duration: Duration(
                          milliseconds: 220 + ((index % 6) * 30),
                        ),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: 1),
                        child: ProductCard(
                          product: product,
                          width: constraints.maxWidth,
                          style: ProductCardStyle.grid,
                          useCompactAddButton: true,
                          showImageBorder: true,
                          accentColor: _accent,
                          onTap: () => context.push('/product/${product.id}'),
                          onOptionsTap: product.hasMultipleOptions
                              ? () => showProductOptionsSheet(context, product)
                              : null,
                        ),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 16),
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        // View All button — navigate to dedicated full product list
        if (productsAsync.asData != null)
          SliverToBoxAdapter(
            child: _ViewAllButton(
              categoryId: feedCategoryId,
              categoryName: feedCategoryName,
              totalCount: totalCount,
              loadedCount: loadedCount,
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingSliver() {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 20.h),
      sliver: SliverGrid.builder(
        itemCount: 6,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 14.h,
          mainAxisExtent: 256.h,
        ),
        itemBuilder: (_, __) => const SkeletonLoader(
          height: 220,
          radius: 16,
        ),
      ),
    );
  }
}

// ── Glassmorphism "View All" button ──────────────────────────────────────────

class _ViewAllButton extends StatefulWidget {
  const _ViewAllButton({
    required this.categoryId,
    required this.categoryName,
    required this.totalCount,
    required this.loadedCount,
  });

  final String categoryId;
  final String categoryName;
  final int totalCount;
  final int loadedCount;

  @override
  State<_ViewAllButton> createState() => _ViewAllButtonState();
}

class _ViewAllButtonState extends State<_ViewAllButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.totalCount > widget.loadedCount
        ? 'View All ${widget.totalCount} Products'
        : 'View All Products';

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 28.h),
      child: Center(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            context.push('/categories/${widget.categoryId}/products');
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 110),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 13.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: AppColors.orderViolet.withOpacity(0.28),
                  width: 1.3,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.orderViolet.withOpacity(0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.55),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orderViolet,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Gap(5.w),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.orderViolet,
                    size: 15.sp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _accent : Colors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(
              color: selected ? _accent : AppColors.borderLight,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
