import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/empty_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

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
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16.w,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Categories', style: AppTextStyles.h2),
            Text(
              'Browse by aisle and add faster',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: categoriesAsync.when(
        loading: _buildLoading,
        error: (error, stackTrace) => ErrorState(
          message: 'Categories could not be loaded.',
          onRetry: () => ref.invalidate(categoryCollectionProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const EmptyState(
              title: 'No categories available',
              message:
                  'Categories will show up here once the API returns them.',
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

          final parents = sorted
              .where((category) => category.isParent)
              .toList(growable: false);
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
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.08, 0),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: _CategoryProductPane(
                    key: ValueKey<String>(
                      '${selectedParent.id}-$selectedFeedId',
                    ),
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
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Row(
      children: <Widget>[
        Container(
          width: 116.w,
          color: const Color(0xFFF2F8F0),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
            children: <Widget>[
              const SkeletonLoader(height: 46, radius: 18),
              Gap(18.h),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  mainAxisExtent: 238.h,
                ),
                itemBuilder: (_, __) => const SkeletonLoader(
                  height: 220,
                  radius: 18,
                ),
              ),
            ],
          ),
        ),
      ],
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
      width: 126.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFF7FBF4),
            Color(0xFFF0F7EC),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        itemCount: categories.length,
        separatorBuilder: (_, __) => Gap(4.h),
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
    return SizedBox(
      height: 120.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 7.w),
        child: AnimatedScale(
          scale: isSelected ? 1 : 0.97,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE8F7E5)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryGreen.withValues(alpha: 0.18)
                    : AppColors.primaryGreen.withValues(alpha: 0.05),
              ),
              boxShadow: isSelected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primaryGreen.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onTap,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      top: 18.h,
                      bottom: 18.h,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: isSelected ? 4.w : 0,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusFull,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 48.h,
                            width: 48.h,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFF8FAF7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primaryGreen.withValues(
                                        alpha: 0.05,
                                      ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: category.imageUrl == null ||
                                      category.imageUrl!.isEmpty
                                  ? Icon(
                                      Icons.grid_view_rounded,
                                      color: AppColors.primaryGreen,
                                      size: 22.sp,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: category.imageUrl!,
                                      memCacheWidth: 200,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const SkeletonLoader(
                                        height: 48,
                                        radius: 16,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Icon(
                                        Icons.grid_view_rounded,
                                        color: AppColors.primaryGreen,
                                        size: 22.sp,
                                      ),
                                    ),
                            ),
                          ),
                          Gap(6.h),
                          Text(
                            category.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 11.sp,
                              color: isSelected
                                  ? AppColors.primaryGreenDark
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              height: 1.18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    final loadedCount = productsAsync.asData?.value.length;
    final countLabel = loadedCount == null
        ? '${selectedParent.productCount} products'
        : '$loadedCount products ready';

    return CustomScrollView(
      key: key,
      slivers: <Widget>[
        if (childCategories.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 0),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 44.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _CategoryFilterChip(
                      label: 'All picks',
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
          padding: EdgeInsets.fromLTRB(14.w, 18.h, 14.w, 8.h),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    selectedFeedId == selectedParent.id
                        ? 'Popular in ${selectedParent.name}'
                        : '${highlightedCategory.name} picks',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  countLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryGreenDark,
                    fontWeight: FontWeight.w700,
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
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 20.h),
              sliver: SliverGrid.builder(
                itemCount: products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  mainAxisExtent: 232.h,
                ),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return TweenAnimationBuilder<double>(
                        duration: Duration(
                          milliseconds: 220 + ((index % 6) * 35),
                        ),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: 1),
                        child: ProductCard(
                          product: product,
                          width: constraints.maxWidth,
                          style: ProductCardStyle.grid,
                          onTap: () => context.push('/product/${product.id}'),
                          onOptionsTap: product.hasMultipleOptions
                              ? () => showProductOptionsSheet(context, product)
                              : null,
                        ),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 18),
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
          mainAxisSpacing: 12.h,
          mainAxisExtent: 232.h,
        ),
        itemBuilder: (_, __) => const SkeletonLoader(
          height: 220,
          radius: 18,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryGreen : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(
          color: selected ? AppColors.primaryGreen : AppColors.borderLight,
        ),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Text(
              label,
              style: AppTextStyles.buttonSmall.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
