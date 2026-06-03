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
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                    child: Row(
                      children: <Widget>[
                        _CircleIconButton(
                          icon: PhosphorIcons.arrowLeft(
                            PhosphorIconsStyle.bold,
                          ),
                          semanticLabel: 'Back',
                          onTap: _dismiss,
                        ),
                        Gap(12.w),
                        Expanded(
                          child: _SearchInput(
                            controller: _searchController,
                            focusNode: _focusNode,
                            hint: _hints[_hintIndex],
                            onChanged: _onQueryChanged,
                          ),
                        ),
                        Gap(12.w),
                        _CircleIconButton(
                          icon: _searchController.text.trim().isEmpty
                              ? PhosphorIcons.microphone(
                                  PhosphorIconsStyle.bold,
                                )
                              : PhosphorIcons.x(PhosphorIconsStyle.bold),
                          iconColor: _searchController.text.trim().isEmpty
                              ? AppColors.orderViolet
                              : AppColors.textSecondary,
                          semanticLabel: _searchController.text.trim().isEmpty
                              ? 'Voice search'
                              : 'Clear search',
                          onTap: _searchController.text.trim().isEmpty
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
                              onCategoryTap: (category) {
                                context.push(
                                  '/categories/${category.id}/products',
                                );
                              },
                              onViewAllProducts: () {
                                context.push(RouteNames.categories);
                              },
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
                                  resultCount: result.total > 0
                                      ? result.total
                                      : (result.pagination.total > 0
                                          ? result.pagination.total
                                          : result.products.length),
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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: AppColors.bgCard,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44.w,
            height: 44.w,
            child: Center(
              child: PhosphorIcon(
                icon,
                size: 20.sp,
                color: iconColor ?? AppColors.textPrimary,
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
      height: 50.h,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Stack(
        children: <Widget>[
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            cursorColor: AppColors.orderViolet,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 16.w, right: 10.w),
                child: PhosphorIcon(
                  PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
                  size: 20.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              contentPadding: EdgeInsets.symmetric(vertical: 15.h),
            ),
          ),
          if (controller.text.isEmpty)
            Positioned(
              left: 46.w,
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

class _CategoryCardPalette {
  const _CategoryCardPalette({
    required this.background,
    required this.iconBackground,
    required this.iconColor,
    required this.icon,
  });

  final Color background;
  final Color iconBackground;
  final Color iconColor;
  final IconData icon;
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.history,
    required this.categories,
    required this.onChipTap,
    required this.onCategoryTap,
    required this.onViewAllProducts,
    required this.onRemoveHistory,
    required this.onClearHistory,
    super.key,
  });

  final List<String> history;
  final List<CategoryEntity> categories;
  final ValueChanged<String> onChipTap;
  final ValueChanged<CategoryEntity> onCategoryTap;
  final VoidCallback onViewAllProducts;
  final ValueChanged<String> onRemoveHistory;
  final VoidCallback onClearHistory;

  static const List<_CategoryCardPalette> _palettes = <_CategoryCardPalette>[
    _CategoryCardPalette(
      background: Color(0xFFEAF6EC),
      iconBackground: Color(0xFFD6EDDA),
      iconColor: Color(0xFF0C831F),
      icon: Icons.eco_rounded,
    ),
    _CategoryCardPalette(
      background: Color(0xFFEDEFFB),
      iconBackground: Color(0xFFDDE2F7),
      iconColor: Color(0xFF3949AB),
      icon: Icons.egg_alt_rounded,
    ),
    _CategoryCardPalette(
      background: Color(0xFFFFF1E6),
      iconBackground: Color(0xFFFCE0CC),
      iconColor: Color(0xFFEE8F00),
      icon: Icons.fastfood_rounded,
    ),
    _CategoryCardPalette(
      background: Color(0xFFFFF7E0),
      iconBackground: Color(0xFFFBEBC0),
      iconColor: Color(0xFFD9A400),
      icon: Icons.grass_rounded,
    ),
    _CategoryCardPalette(
      background: Color(0xFFFCE9EF),
      iconBackground: Color(0xFFF7D4E0),
      iconColor: Color(0xFFD81B60),
      icon: Icons.local_fire_department_rounded,
    ),
  ];

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
              GestureDetector(
                onTap: onClearHistory,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Clear all',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.orderViolet,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppDimensions.spacing12),
          SizedBox(
            height: 38.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: history.length,
              separatorBuilder: (_, __) => Gap(10.w),
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
        const Gap(AppDimensions.spacing16),
        ...List<Widget>.generate(popularCategories.length, (index) {
          final category = popularCategories[index];
          final palette = _palettes[index % _palettes.length];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _PopularCategoryCard(
              category: category,
              palette: palette,
              onTap: () => onCategoryTap(category),
            )
                .animate()
                .fadeIn(
                  delay: (40 * index).ms,
                  duration: 280.ms,
                )
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          );
        }),
        const Gap(AppDimensions.spacing8),
        _ViewAllProductsCard(onTap: onViewAllProducts),
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.orderVioletSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(color: AppColors.orderVioletBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.clockCounterClockwise(),
              size: 15.sp,
              color: AppColors.orderViolet,
            ),
            Gap(7.w),
            Text(
              query,
              style: AppTextStyles.chip.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Gap(8.w),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
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

class _PopularCategoryCard extends StatelessWidget {
  const _PopularCategoryCard({
    required this.category,
    required this.palette,
    required this.onTap,
  });

  final CategoryEntity category;
  final _CategoryCardPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.imageUrl ?? '';

    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 92.h,
          child: Row(
            children: <Widget>[
              Gap(16.w),
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: palette.iconBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(
                  palette.icon,
                  size: 26.sp,
                  color: palette.iconColor,
                ),
              ),
              Gap(14.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(AppDimensions.spacing4),
                    Text(
                      '${category.productCount} items',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (imageUrl.isNotEmpty) ...<Widget>[
                SizedBox(
                  width: 88.w,
                  height: 92.h,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    memCacheWidth: 300,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                Gap(8.w),
              ],
              Container(
                width: 36.w,
                height: 36.w,
                margin: EdgeInsets.only(right: 14.w),
                decoration: const BoxDecoration(
                  color: AppColors.bgCard,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[AppShadows.cardShadow],
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                    size: 16.sp,
                    color: AppColors.textPrimary,
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

class _ViewAllProductsCard extends StatelessWidget {
  const _ViewAllProductsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40.w,
            height: 40.w,
            decoration: const BoxDecoration(
              color: AppColors.orderVioletSurface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                size: 20.sp,
                color: AppColors.orderViolet,
              ),
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Can't find what you're looking for?",
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(AppDimensions.spacing2),
                Text(
                  'Search from 10,000+ products',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Gap(8.w),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: AppColors.orderVioletSurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Text(
                'View all products',
                style: AppTextStyles.buttonSmall.copyWith(
                  color: AppColors.orderViolet,
                ),
              ),
            ),
          ),
        ],
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
    required this.resultCount,
    super.key,
  });

  final PagingController<int, ProductEntity> pagingController;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  resultCount == 1 ? '1 result' : '$resultCount results',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _SortFilterPill(
                icon: PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                label: 'Relevance',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sorting options are coming soon.'),
                    ),
                  );
                },
              ),
              Gap(14.w),
              _SortFilterPill(
                icon: PhosphorIcons.slidersHorizontal(
                  PhosphorIconsStyle.bold,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Filters are coming soon.'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.divider),
        Expanded(
          child: PagedListView<int, ProductEntity>.separated(
            pagingController: pagingController,
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
            separatorBuilder: (_, __) => Gap(12.h),
            builderDelegate: PagedChildBuilderDelegate<ProductEntity>(
              itemBuilder: (context, product, index) {
                return _SearchResultTile(product: product);
              },
              firstPageProgressIndicatorBuilder: (_) =>
                  const SizedBox.shrink(),
              newPageProgressIndicatorBuilder: (_) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
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
          ),
        ),
      ],
    );
  }
}

class _SortFilterPill extends StatelessWidget {
  const _SortFilterPill({
    required this.icon,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label != null) ...<Widget>[
            Text(
              label!,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(4.w),
          ],
          PhosphorIcon(
            icon,
            size: 16.sp,
            color: AppColors.textPrimary,
          ),
        ],
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
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Container(
                width: 72.w,
                height: 72.w,
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
            Gap(14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontSize: 14.sp,
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
            Gap(12.w),
            QuantityControl(
              quantity: quantity,
              width: 84,
              height: 38,
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
