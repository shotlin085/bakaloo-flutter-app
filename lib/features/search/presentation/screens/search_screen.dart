import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/search/domain/entities/search_result_entity.dart';
import 'package:bakaloo_flutter_app/features/search/presentation/providers/search_history_provider.dart';
import 'package:bakaloo_flutter_app/features/search/presentation/providers/search_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/quantity_control.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _hints = <String>[
    'Search atta, fruits, milk...',
    'Try onions, tomatoes, rice...',
    'Find chips, juices, bread...',
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final PagingController<int, ProductEntity> _pagingController =
      PagingController<int, ProductEntity>(firstPageKey: 1);

  late final AnimationController _overlayController;
  late final Animation<Offset> _slideAnimation;
  Timer? _hintTimer;
  int _hintIndex = 0;
  String _pagedQuery = '';
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _overlayController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _pagingController.addPageRequestListener(_fetchPage);
    _overlayController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _searchController.text.trim().isNotEmpty) {
        return;
      }

      setState(() {
        _hintIndex = (_hintIndex + 1) % _hints.length;
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _overlayController.dispose();
    _pagingController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    if (pageKey <= 1 || _pagedQuery.isEmpty) {
      return;
    }

    final requestQuery = _pagedQuery;
    try {
      final result = await ref.read(searchProvider.notifier).searchPage(
            query: requestQuery,
            page: pageKey,
          );

      if (!mounted || requestQuery != _pagedQuery) {
        return;
      }

      final isLastPage = result.pagination.totalPages == 0 ||
          result.pagination.page >= result.pagination.totalPages;

      if (isLastPage) {
        _pagingController.appendLastPage(result.products);
      } else {
        _pagingController.appendPage(
          result.products,
          pageKey + 1,
        );
      }
    } catch (error) {
      if (!mounted || requestQuery != _pagedQuery) {
        return;
      }
      _pagingController.error = error;
    }
  }

  Future<void> _dismiss() async {
    if (_isDismissing) {
      return;
    }

    _isDismissing = true;
    await _overlayController.reverse();
    if (!mounted) {
      return;
    }

    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }

    context.go(RouteNames.home);
  }

  void _onQueryChanged(String value) {
    if (mounted) {
      setState(() {});
    }

    if (value.trim().isEmpty) {
      _pagedQuery = '';
      _pagingController.refresh();
    }

    ref.read(searchProvider.notifier).onQueryChanged(value);
  }

  void _applyFirstPage(SearchResultEntity result) {
    _pagedQuery = _searchController.text.trim();
    final nextPageKey = result.pagination.totalPages > 1 ? 2 : null;
    _pagingController.value = PagingState<int, ProductEntity>(
      itemList: result.products,
      error: null,
      nextPageKey: nextPageKey,
    );
  }

  void _fillQuery(String query) {
    _searchController
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _focusNode.requestFocus();
    _onQueryChanged(query);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final history = ref.watch(searchHistoryProvider);
    final categoriesAsync = ref.watch(categoryCollectionProvider);
    final hasQuery = _searchController.text.trim().isNotEmpty;
    ref.listen<AsyncValue<SearchResultEntity>>(searchProvider,
        (previous, next) {
      next.whenOrNull(
        data: (result) {
          ref.read(searchHistoryProvider.notifier).refresh();

          if (_searchController.text.trim().isEmpty) {
            _pagedQuery = '';
            _pagingController.refresh();
            return;
          }

          if (result.products.isEmpty) {
            _pagedQuery = _searchController.text.trim();
            _pagingController.value = const PagingState<int, ProductEntity>(
              itemList: <ProductEntity>[],
              error: null,
              nextPageKey: null,
            );
            return;
          }

          _applyFirstPage(result);
        },
        error: (error, stackTrace) {
          _pagingController.error = error;
        },
      );
    });

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_dismiss());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              color: AppColors.bgPrimary,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: _dismiss,
                          icon: PhosphorIcon(
                            PhosphorIcons.arrowLeft(),
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Expanded(
                          child: _SearchInput(
                            controller: _searchController,
                            focusNode: _focusNode,
                            hint: _hints[_hintIndex],
                            onChanged: _onQueryChanged,
                          ),
                        ),
                        SizedBox(
                          width: 48.w,
                          child: IconButton(
                            onPressed: _searchController.text.trim().isEmpty
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Voice search is coming soon.',
                                        ),
                                      ),
                                    );
                                  }
                                : () {
                                    _searchController.clear();
                                    _focusNode.requestFocus();
                                    _onQueryChanged('');
                                  },
                            icon: PhosphorIcon(
                              _searchController.text.trim().isEmpty
                                  ? PhosphorIcons.microphone()
                                  : PhosphorIcons.xCircle(),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: !hasQuery
                          ? _EmptySearchState(
                              key: const ValueKey<String>('empty'),
                              history: history,
                              categories: categoriesAsync.asData?.value ??
                                  const <CategoryEntity>[],
                              onChipTap: _fillQuery,
                              onRemoveHistory: (query) {
                                ref
                                    .read(searchHistoryProvider.notifier)
                                    .removeQuery(query);
                              },
                              onClearHistory: () {
                                ref
                                    .read(searchHistoryProvider.notifier)
                                    .clearAll();
                              },
                            )
                          : searchState.when(
                              loading: () => const _DebouncingState(
                                key: ValueKey<String>('loading'),
                              ),
                              error: (error, stackTrace) => _SearchErrorState(
                                key: const ValueKey<String>('error'),
                                message: error
                                    .toString()
                                    .replaceFirst('Bad state: ', ''),
                                onRetry: () {
                                  ref.read(searchProvider.notifier).retry();
                                },
                              ),
                              data: (result) {
                                if (result.products.isEmpty) {
                                  return _NoResultsState(
                                    key: const ValueKey<String>('no-results'),
                                    query: _searchController.text.trim(),
                                    suggestions: result.suggestions,
                                  );
                                }

                                return _SearchResultsState(
                                  key: const ValueKey<String>('results'),
                                  pagingController: _pagingController,
                                );
                              },
                            ),
                    ),
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

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.searchBarHeight.h,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Stack(
        children: <Widget>[
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            onChanged: onChanged,
            cursorColor: AppColors.primaryGreen,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: PhosphorIcon(
                PhosphorIcons.magnifyingGlass(),
                color: AppColors.textSecondary,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 14.h),
            ),
          ),
          if (controller.text.isEmpty)
            Positioned(
              left: 52.w,
              right: 16.w,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      hint,
                      key: ValueKey<String>(hint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ).animate().fadeIn(duration: 250.ms),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.history,
    required this.categories,
    required this.onChipTap,
    required this.onRemoveHistory,
    required this.onClearHistory,
    super.key,
  });

  final List<String> history;
  final List<CategoryEntity> categories;
  final ValueChanged<String> onChipTap;
  final ValueChanged<String> onRemoveHistory;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final popularCategories = categories
        .where((category) => category.isActive && category.isParent)
        .take(6)
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      children: <Widget>[
        if (history.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Recent searches',
                  style: AppTextStyles.h3,
                ),
              ),
              TextButton(
                onPressed: onClearHistory,
                child: Text(
                  'Clear all',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 42.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: history.length,
              separatorBuilder: (_, __) => Gap(8.w),
              itemBuilder: (context, index) {
                final query = history[index];
                return _RecentSearchChip(
                  query: query,
                  onTap: () => onChipTap(query),
                  onRemove: () => onRemoveHistory(query),
                );
              },
            ),
          ),
          const Gap(AppDimensions.spacing24),
        ],
        Text(
          'Popular categories',
          style: AppTextStyles.h3,
        ),
        const Gap(AppDimensions.spacing12),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: popularCategories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) {
            final category = popularCategories[index];
            return _PopularCategoryTile(
              category: category,
              onTap: () => onChipTap(category.name),
            );
          },
        ),
      ],
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  const _RecentSearchChip({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              query,
              style: AppTextStyles.chip.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Gap(8.w),
            GestureDetector(
              onTap: onRemove,
              child: PhosphorIcon(
                PhosphorIcons.x(),
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularCategoryTile extends StatelessWidget {
  const _PopularCategoryTile({
    required this.category,
    required this.onTap,
  });

  final CategoryEntity category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: Container(
                  color: AppColors.primaryGreenLight,
                  width: double.infinity,
                  child: (category.imageUrl ?? '').isEmpty
                      ? Center(
                          child: PhosphorIcon(
                            PhosphorIcons.gridFour(),
                            color: AppColors.primaryGreen,
                            size: 28,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: category.imageUrl!,
                          memCacheWidth: 300,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                            child: PhosphorIcon(
                              PhosphorIcons.imageBroken(),
                              color: AppColors.textDisabled,
                              size: 24,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const Gap(AppDimensions.spacing12),
            Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(AppDimensions.spacing4),
            Text(
              '${category.productCount} items',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DebouncingState extends StatelessWidget {
  const _DebouncingState({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      itemCount: 3,
      separatorBuilder: (_, __) => Gap(12.h),
      itemBuilder: (_, __) {
        return Row(
          children: <Widget>[
            const SkeletonLoader(height: 64, width: 64, radius: 12),
            Gap(12.w),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SkeletonLoader(height: 14, radius: 8),
                  Gap(AppDimensions.spacing8),
                  SkeletonLoader(height: 12, width: 100, radius: 8),
                  Gap(AppDimensions.spacing8),
                  SkeletonLoader(height: 12, width: 80, radius: 8),
                ],
              ),
            ),
            Gap(12.w),
            const SkeletonLoader(height: 36, width: 80, radius: 12),
          ],
        );
      },
    );
  }
}

class _SearchResultsState extends StatelessWidget {
  const _SearchResultsState({
    required this.pagingController,
    super.key,
  });

  final PagingController<int, ProductEntity> pagingController;

  @override
  Widget build(BuildContext context) {
    return PagedListView<int, ProductEntity>.separated(
      pagingController: pagingController,
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      separatorBuilder: (_, __) => Gap(12.h),
      builderDelegate: PagedChildBuilderDelegate<ProductEntity>(
        itemBuilder: (context, product, index) {
          return _SearchResultTile(product: product);
        },
        firstPageProgressIndicatorBuilder: (_) => const SizedBox.shrink(),
        newPageProgressIndicatorBuilder: (_) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          ),
        ),
        firstPageErrorIndicatorBuilder: (_) => const SizedBox.shrink(),
        newPageErrorIndicatorBuilder: (_) => Center(
          child: Text(
            'Unable to load more results.',
            style: AppTextStyles.bodySmall,
          ),
        ),
        noItemsFoundIndicatorBuilder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  const _SearchResultTile({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);
    final quantity = ref.watch(cartItemQuantityProvider(product.id));

    return InkWell(
      onTap: () => context.push('/product/${product.id}'),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Container(
                width: 64.w,
                height: 64.w,
                color: AppColors.bgSection,
                child: imageUrl == null || imageUrl.isEmpty
                    ? Center(
                        child: PhosphorIcon(
                          PhosphorIcons.image(),
                          color: AppColors.textDisabled,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        memCacheWidth: 300,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: PhosphorIcon(
                            PhosphorIcons.imageBroken(),
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ),
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(AppDimensions.spacing4),
                  Text(
                    product.unit,
                    style: AppTextStyles.bodySmall,
                  ),
                  const Gap(AppDimensions.spacing8),
                  RichText(
                    text: TextSpan(
                      text: '₹${product.effectivePrice.toStringAsFixed(0)}',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                      children: <InlineSpan>[
                        if (product.isOnSale)
                          TextSpan(
                            text: '  ₹${product.price.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            QuantityControl(
              quantity: quantity,
              width: 80,
              onAdd: product.inStock
                  ? () async {
                      final authGate = ref.read(authGateControllerProvider);
                      final allowed = await authGate.protectAddToCart(
                        context,
                        product,
                      );
                      if (!allowed || !context.mounted) {
                        return;
                      }
                      final result =
                          await ref.read(cartProvider.notifier).addItem(
                                product.id,
                                1,
                                product: product,
                              );
                      if (!context.mounted) {
                        return;
                      }
                      if (!result.isSuccess) {
                        showCartSnackBar(
                          context,
                          result.failure!.message,
                        );
                      }
                    }
                  : null,
              onIncrement: product.inStock && quantity < 50
                  ? () async {
                      final result = await ref
                          .read(cartProvider.notifier)
                          .updateItem(product.id, quantity + 1);
                      if (!context.mounted) {
                        return;
                      }
                      if (!result.isSuccess) {
                        showCartSnackBar(
                          context,
                          result.failure!.message,
                        );
                      }
                    }
                  : null,
              onDecrement: product.inStock && quantity > 0
                  ? () async {
                      final result = quantity == 1
                          ? await ref
                              .read(cartProvider.notifier)
                              .removeItem(product.id)
                          : await ref
                              .read(cartProvider.notifier)
                              .updateItem(product.id, quantity - 1);
                      if (!context.mounted) {
                        return;
                      }
                      if (!result.isSuccess) {
                        showCartSnackBar(
                          context,
                          result.failure!.message,
                        );
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({
    required this.query,
    required this.suggestions,
    super.key,
  });

  final String query;
  final List<ProductEntity> suggestions;

  static const String _sadMagnifierSvg = '''
<svg width="132" height="132" viewBox="0 0 132 132" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="56" cy="56" r="32" stroke="#0C831F" stroke-width="8"/>
  <path d="M78 78L110 110" stroke="#0C831F" stroke-width="8" stroke-linecap="round"/>
  <circle cx="47" cy="50" r="4" fill="#0C831F"/>
  <circle cx="65" cy="50" r="4" fill="#0C831F"/>
  <path d="M44 69C48 63 64 63 68 69" stroke="#D32F2F" stroke-width="6" stroke-linecap="round"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 24.h),
      children: <Widget>[
        SvgPicture.string(
          _sadMagnifierSvg,
          width: 132.w,
          height: 132.w,
        ),
        const Gap(AppDimensions.spacing20),
        Text(
          'No results',
          textAlign: TextAlign.center,
          style: AppTextStyles.h2,
        ),
        const Gap(AppDimensions.spacing8),
        Text(
          'We could not find anything for "$query".',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
        if (suggestions.isNotEmpty) ...<Widget>[
          const Gap(AppDimensions.spacing24),
          Text(
            'You might like',
            style: AppTextStyles.h3,
          ),
          const Gap(AppDimensions.spacing12),
          SizedBox(
            height: 246.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => Gap(12.w),
              itemBuilder: (_, index) {
                return ProductCard(
                  product: suggestions[index],
                  style: ProductCardStyle.scroll,
                  onOptionsTap: suggestions[index].hasMultipleOptions
                      ? () => showProductOptionsSheet(context, suggestions[index])
                      : null,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchErrorState extends StatelessWidget {
  const _SearchErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.warningCircle(),
              size: 48,
              color: AppColors.warningOrange,
            ),
            const Gap(AppDimensions.spacing16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge,
            ),
            const Gap(AppDimensions.spacing16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              ),
              child: Text(
                'Retry',
                style: AppTextStyles.buttonMedium.copyWith(
                  color: AppColors.textOnGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
