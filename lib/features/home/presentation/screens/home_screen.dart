import 'dart:async';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/tab_home_content_model.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/shared/utils/address_utils.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/home_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/utils/home_product_palettes.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/animated_banner_section.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/dynamic_home_sections.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/seasonal_deal_mosaic.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/category_tabs_row.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_header.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_search_bar.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/shared_painters.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';

double _horizontalRailExtent(
  int index,
  int itemCount,
  double itemWidth,
  double separatorWidth,
) {
  if (itemCount <= 1 || index == itemCount - 1) {
    return itemWidth;
  }
  return itemWidth + separatorWidth;
}

/// Logical (design-unit) width for a card in the 3-column home grid.
///
/// The grid uses 16w horizontal padding on each side and two 10w gaps between
/// the three columns. [ProductCard] multiplies its `width` by `.w` internally,
/// so we return the design-unit width (raw px ÷ current width scale) to avoid
/// double-scaling.
double _threeColumnCardWidth(BuildContext context) {
  final double screenWidth = MediaQuery.sizeOf(context).width;
  final double horizontalPadding = 16.w * 2;
  final double totalGap = 10.w * 2;
  final double columnPx = (screenWidth - horizontalPadding - totalGap) / 3;
  final double scale = ScreenUtil().scaleWidth;
  return scale > 0 ? columnPx / scale : columnPx;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late final ScrollController _homeScrollController;
  late final ProviderSubscription<AsyncValue<Map<String, dynamic>>>
      _themeSocketSub;
  late final ProviderSubscription<AsyncValue<Map<String, dynamic>>>
      _sectionSocketSub;
  late final ProviderSubscription<Timer> _themeRefreshTimerSub;
  late final ProviderSubscription<AsyncValue<HomeScreenData>> _homeDataSub;
  late final ProviderSubscription<AsyncValue<TabHomeContentResponse?>>
      _tabHomeContentSub;
  final GlobalKey _topSearchZoneKey = GlobalKey();
  double? _stickyHeaderTriggerOffset;
  final ValueNotifier<double> _stickyHeaderProgress = ValueNotifier<double>(0);
  final ValueNotifier<int> _deferredSectionStage = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isStickyHeaderActive = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isTopChromeMotionEnabled =
      ValueNotifier<bool>(true);
  bool _isThemeLayoutRefreshInFlight = false;
  List<CategoryEntity> _sortedCategories = const <CategoryEntity>[];
  List<CategoryEntity> _parentCategories = const <CategoryEntity>[];
  List<CategoryEntity> _showcaseCategories = const <CategoryEntity>[];
  List<CategoryEntity> _stagedCategories = const <CategoryEntity>[];
  List<CategoryEntity> _priorityCategories = const <CategoryEntity>[];
  List<CategoryEntity> _deferredCategories = const <CategoryEntity>[];
  List<BannerEntity> _banners = const <BannerEntity>[];
  List<ProductEntity> _homeFeaturedProducts = const <ProductEntity>[];
  List<_HomePromoData> _bannerCarouselCards = const <_HomePromoData>[];
  List<ProductEntity> _managedSeasonalProducts = const <ProductEntity>[];
  List<ProductEntity> _managedFeaturedProducts = const <ProductEntity>[];
  List<ProductEntity> _managedTrendingProducts = const <ProductEntity>[];
  List<TabCategorySection> _managedCategorySections =
      const <TabCategorySection>[];
  List<ProductEntity> _featuredPool = const <ProductEntity>[];
  final ValueNotifier<List<Widget>> _cachedStagedSlivers =
      ValueNotifier<List<Widget>>(const <Widget>[]);
  int _lastRenderedStage = -1;

  double get _stickyRevealStartDistance => 48.h;
  double get _stickyRevealEndDistance => 24.h;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeScrollController = ScrollController()..addListener(_handleHomeScroll);
    _themeSocketSub = ref.listenManual(
      socketThemeUpdateStreamProvider,
      (previous, next) {
        next.whenData((event) {
          unawaited(handleThemeSocketEvent(ref, event));
        });
      },
    );
    _sectionSocketSub = ref.listenManual(
      socketSectionUpdateStreamProvider,
      (previous, next) {
        next.whenData((event) {
          unawaited(handleSectionSocketEvent(ref, event));
        });
      },
    );
    _themeRefreshTimerSub = ref.listenManual(
      themeRefreshTimerProvider,
      (_, __) {},
    );
    _deferredSectionStage.addListener(_rebuildStagedSlivers);
    _homeDataSub = ref.listenManual(
      homeProvider,
      (previous, next) {
        next.whenData(_recomputeHomeData);
      },
      fireImmediately: true,
    );
    _tabHomeContentSub = ref.listenManual(
      selectedTabHomeContentProvider,
      (previous, next) {
        if (next case AsyncData(:final value?)) {
          _recomputeTabContent(value);
          return;
        }
        _clearTabContentCache();
      },
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateStickyHeaderTriggerOffset();
        _handleHomeScroll();
      }
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _handleHomeScroll() {
    if (!_homeScrollController.hasClients) {
      return;
    }

    final pixels = _homeScrollController.position.pixels;
    final currentTopChromeMotionEnabled = _isTopChromeMotionEnabled.value;
    final nextStage = pixels > 1500
        ? 3
        : pixels > 920
            ? 2
            : pixels > 320
                ? 1
                : 0;
    var nextTopChromeMotionEnabled = currentTopChromeMotionEnabled;
    if (currentTopChromeMotionEnabled && pixels > 36) {
      nextTopChromeMotionEnabled = false;
    } else if (!currentTopChromeMotionEnabled && pixels < 12) {
      nextTopChromeMotionEnabled = true;
    }
    var nextStickyProgress = 0.0;
    final triggerOffset = _stickyHeaderTriggerOffset;
    if (triggerOffset != null) {
      final transitionStart = triggerOffset - _stickyRevealStartDistance;
      final transitionEnd = triggerOffset + _stickyRevealEndDistance;
      final transitionRange = transitionEnd - transitionStart;
      if (transitionRange > 0) {
        nextStickyProgress =
            ((pixels - transitionStart) / transitionRange).clamp(0.0, 1.0);
      }
    }

    if ((nextStickyProgress - _stickyHeaderProgress.value).abs() > 0.01) {
      _stickyHeaderProgress.value = nextStickyProgress;
    }

    final shouldShowStickyHeader = nextStickyProgress > 0.58;

    if (nextStage != _deferredSectionStage.value) {
      _deferredSectionStage.value = nextStage;
    }
    if (shouldShowStickyHeader != _isStickyHeaderActive.value) {
      _isStickyHeaderActive.value = shouldShowStickyHeader;
    }
    if (nextTopChromeMotionEnabled != currentTopChromeMotionEnabled) {
      _isTopChromeMotionEnabled.value = nextTopChromeMotionEnabled;
    }
  }

  void _updateStickyHeaderTriggerOffset() {
    if (!_homeScrollController.hasClients) {
      return;
    }

    final searchZoneContext = _topSearchZoneKey.currentContext;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (searchZoneContext == null || mediaQuery == null) {
      return;
    }

    final renderObject = searchZoneContext.findRenderObject();
    if (renderObject case final RenderBox box when box.hasSize) {
      final pixels = _homeScrollController.position.pixels;
      final topOffset = box.localToGlobal(Offset.zero).dy;
      _stickyHeaderTriggerOffset =
          pixels + topOffset + box.size.height - mediaQuery.padding.top;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeSocketSub.close();
    _sectionSocketSub.close();
    _themeRefreshTimerSub.close();
    _homeDataSub.close();
    _tabHomeContentSub.close();
    _deferredSectionStage
      ..removeListener(_rebuildStagedSlivers)
      ..dispose();
    _isStickyHeaderActive.dispose();
    _isTopChromeMotionEnabled.dispose();
    _stickyHeaderProgress.dispose();
    _cachedStagedSlivers.dispose();
    _homeScrollController
      ..removeListener(_handleHomeScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshThemeDrivenLayout());
    }
  }

  Future<void> _refreshThemeDrivenLayout() async {
    if (!mounted || _isThemeLayoutRefreshInFlight) {
      return;
    }

    _isThemeLayoutRefreshInFlight = true;
    try {
      final activeTabKey = ref.read(activeTabKeyProvider);
      await Future.wait<void>(<Future<void>>[
        refreshCurrentStoreThemes(ref),
        refreshSectionManifest(ref, activeTabKey),
      ]);
    } finally {
      _isThemeLayoutRefreshInFlight = false;
    }
  }

  Future<void> _refresh() async {
    final activeTabKey = ref.read(activeTabKeyProvider);
    ref
      ..invalidate(homeProvider)
      ..invalidate(bannerProvider)
      ..invalidate(categoryCollectionProvider)
      ..invalidate(homeFeaturedProductsProvider)
      ..invalidate(homeDealsProvider)
      ..invalidate(homeTrendingProductsProvider)
      ..invalidate(tabThemesProvider)
      ..invalidate(selectedTabHomeContentProvider)
      ..invalidate(sectionManifestProvider(activeTabKey))
      ..invalidate(activeSectionManifestProvider);
    _stickyHeaderTriggerOffset = null;
    _stickyHeaderProgress.value = 0;
    await Future.wait<void>(<Future<void>>[
      ref.read(homeProvider.future).then((_) {}),
      _refreshThemeDrivenLayout(),
    ]);
  }

  void _openSearch() {
    context.go(RouteNames.search);
  }

  void _recomputeHomeData(HomeScreenData data) {
    final sorted = data.categories
        .where((category) => category.isActive)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final parents = _buildParentCategories(sorted);
    final showcase = _categoriesWithRenderableImages(parents);
    final staged = parents.take(6).toList(growable: false);
    final priority = staged.take(3).toList(growable: false);
    final deferred = staged.skip(3).toList(growable: false);
    final bannerCards = _buildBannerCarouselCards(data.banners);
    final featuredPool = _buildFeaturedPool(
      managedFeaturedProducts: _managedFeaturedProducts,
      homeFeaturedProducts: data.featuredProducts,
    );

    void applyCache() {
      _sortedCategories = sorted;
      _parentCategories = parents;
      _showcaseCategories = showcase;
      _stagedCategories = staged;
      _priorityCategories = priority;
      _deferredCategories = deferred;
      _banners = data.banners;
      _homeFeaturedProducts = data.featuredProducts;
      _bannerCarouselCards = bannerCards;
      _featuredPool = featuredPool;
      _refreshStagedSliversCache();
    }

    if (!mounted) {
      applyCache();
      return;
    }

    setState(applyCache);
  }

  void _recomputeTabContent(TabHomeContentResponse content) {
    final seasonalProducts = content.seasonalProducts
        .where((product) => product.inStock)
        .toList(growable: false);
    final featuredProducts = content.featuredProducts
        .where((product) => product.inStock)
        .toList(growable: false);
    final trendingProducts = content.trendingProducts
        .where((product) => product.inStock)
        .toList(growable: false);
    final categorySections = content.categorySections
        .where((section) => section.products.isNotEmpty)
        .toList(growable: false);
    final featuredPool = _buildFeaturedPool(
      managedFeaturedProducts: featuredProducts,
      homeFeaturedProducts: _homeFeaturedProducts,
    );

    void applyCache() {
      _managedSeasonalProducts = seasonalProducts;
      _managedFeaturedProducts = featuredProducts;
      _managedTrendingProducts = trendingProducts;
      _managedCategorySections = categorySections;
      _featuredPool = featuredPool;
      _refreshStagedSliversCache();
    }

    if (!mounted) {
      applyCache();
      return;
    }

    setState(applyCache);
  }

  void _clearTabContentCache() {
    final featuredPool = _buildFeaturedPool(
      managedFeaturedProducts: const <ProductEntity>[],
      homeFeaturedProducts: _homeFeaturedProducts,
    );

    void applyCache() {
      _managedSeasonalProducts = const <ProductEntity>[];
      _managedFeaturedProducts = const <ProductEntity>[];
      _managedTrendingProducts = const <ProductEntity>[];
      _managedCategorySections = const <TabCategorySection>[];
      _featuredPool = featuredPool;
      _refreshStagedSliversCache();
    }

    if (!mounted) {
      applyCache();
      return;
    }

    setState(applyCache);
  }

  List<ProductEntity> _buildFeaturedPool({
    required List<ProductEntity> managedFeaturedProducts,
    required List<ProductEntity> homeFeaturedProducts,
  }) {
    final source = managedFeaturedProducts.isNotEmpty
        ? managedFeaturedProducts
        : homeFeaturedProducts;
    return _filterProducts(
      source.where((product) => product.inStock).toList(growable: false),
      null,
    );
  }

  void _refreshStagedSliversCache() {
    final stage = _deferredSectionStage.value;
    _lastRenderedStage = stage;
    _cachedStagedSlivers.value = _buildStagedSlivers(stage);
  }

  void _rebuildStagedSlivers() {
    final stage = _deferredSectionStage.value;
    if (stage == _lastRenderedStage) {
      return;
    }

    _lastRenderedStage = stage;
    _cachedStagedSlivers.value = _buildStagedSlivers(stage);
  }

  List<Widget> _buildStagedSlivers(int stage) {
    if (_stagedCategories.isEmpty || stage < 2) {
      return const <Widget>[];
    }

    final slivers = <Widget>[];
    var bannerInserted = false;
    final stagedCategoryList = <CategoryEntity>[
      if (stage >= 2) ..._priorityCategories,
      if (stage >= 3) ..._deferredCategories,
    ];

    for (final cat in stagedCategoryList) {
      final normalizedName = cat.name.trim().toLowerCase();
      final shouldInsertBannerBeforeCategory = !bannerInserted &&
          _banners.isNotEmpty &&
          _bannerCarouselCards.isNotEmpty &&
          (normalizedName.contains('bakery') ||
              normalizedName.contains('bread'));

      slivers.add(
        Consumer(
          builder: (context, ref, _) {
            final catProducts =
                ref.watch(homeCategoryProductsProvider(cat.id)).asData?.value;
            if (catProducts == null || catProducts.isEmpty) {
              return const SizedBox.shrink();
            }

            final renderable = catProducts
                .where((product) => product.inStock)
                .toList(growable: false);
            if (renderable.length < 2) {
              return const SizedBox.shrink();
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (shouldInsertBannerBeforeCategory)
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 6.h, 0, 6.h),
                    child: RepaintBoundary(
                      child: _HeroPromoCarousel(cards: _bannerCarouselCards),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: RepaintBoundary(
                    child: _CategoryProductSection(
                      title: _fancyCategoryName(cat.name),
                      categoryId: cat.id,
                      products: renderable.take(6).toList(growable: false),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      if (shouldInsertBannerBeforeCategory) {
        bannerInserted = true;
      }
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final topBarTheme = TopBarTheme(
      backgroundColor: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.topBar.backgroundColor,
        ),
      ),
      textColor: ref.watch(
        activeTabThemeProvider
            .select((theme) => theme.sections.topBar.textColor),
      ),
    );
    final searchZoneTheme = SearchZoneTheme(
      backgroundColor: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.searchZone.backgroundColor,
        ),
      ),
      waveColor: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.searchZone.waveColor,
        ),
      ),
      searchHints: () {
        final serializedHints = ref.watch(
          activeTabThemeProvider.select(
            (theme) => theme.sections.searchZone.searchHints.join('\u0001'),
          ),
        );
        return serializedHints.isEmpty
            ? const <String>[]
            : serializedHints.split('\u0001');
      }(),
      promoBoxImageUrl: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.searchZone.promoBoxImageUrl,
        ),
      ),
    );
    final activeTabKey = ref.watch(activeTabKeyProvider);
    final manifestIsLoading = ref.watch(
      sectionManifestProvider(activeTabKey).select(
        (manifestAsync) => manifestAsync.isLoading,
      ),
    );
    final manifestIsEmpty = ref.watch(
      activeSectionManifestProvider.select(
        (manifest) => manifest.sections.isEmpty,
      ),
    );
    final showLegacySections = manifestIsEmpty && manifestIsLoading;
    final showCategoryTabs = ref.watch(
      activeTabThemeProvider.select(
        (theme) => theme.sections.categoryTabs.visible,
      ),
    );
    final homeAsync = ref.watch(homeProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return ValueListenableBuilder<bool>(
      valueListenable: _isStickyHeaderActive,
      builder: (context, isStickyHeaderActive, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isStickyHeaderActive
              ? const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                  systemNavigationBarColor: Colors.white,
                  systemNavigationBarIconBrightness: Brightness.dark,
                )
              : const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                  systemNavigationBarColor: Colors.white,
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
          child: child!,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: homeAsync.when(
          loading: () => const _HomeLoadingView(),
          error: (error, stackTrace) => _HomeErrorView(onRetry: _refresh),
          data: (_) {
            final sortedCategories = _sortedCategories;
            final parentCategories = _parentCategories;
            final showcaseCategories = _showcaseCategories;
            final managedSeasonalProducts = _managedSeasonalProducts;
            final managedFeaturedProducts = _managedFeaturedProducts;
            final managedTrendingProducts = _managedTrendingProducts;
            final managedCategorySections = _managedCategorySections;
            final featuredProducts = _featuredPool;
            if (_stickyHeaderTriggerOffset == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _updateStickyHeaderTriggerOffset();
                  _handleHomeScroll();
                }
              });
            }
            return SafeArea(
              top: false,
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.warmOrangeDark,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomScrollView(
                        controller: _homeScrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: <Widget>[
                          SliverToBoxAdapter(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _isTopChromeMotionEnabled,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final currentUser = ref.watch(
                                        currentUserProvider,
                                      );
                                      final addresses = currentUser == null
                                          ? null
                                          : ref
                                              .watch(addressProvider)
                                              .asData
                                              ?.value;
                                      return HomeHeader(
                                        addressText: resolveAddressLabel(
                                          isLoggedIn: currentUser != null,
                                          addresses: addresses,
                                        ),
                                        onAddressTap: () {
                                          showModalBottomSheet<void>(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) =>
                                                const _AddressBottomSheet(),
                                          );
                                        },
                                        onProfileTap: () =>
                                            context.go(RouteNames.profile),
                                        onWalletTap: () =>
                                            context.go(RouteNames.wallet),
                                        topBarTheme: topBarTheme,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              builder: (
                                context,
                                isTopChromeMotionEnabled,
                                child,
                              ) {
                                return ColoredBox(
                                  color: topBarTheme.backgroundColor,
                                  child: TickerMode(
                                    enabled: isTopChromeMotionEnabled,
                                    child: child!,
                                  ),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _isTopChromeMotionEnabled,
                              builder: (
                                context,
                                isTopChromeMotionEnabled,
                                _,
                              ) {
                                return Container(
                                  key: _topSearchZoneKey,
                                  color: searchZoneTheme.backgroundColor,
                                  child: TickerMode(
                                    enabled: isTopChromeMotionEnabled,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        SizedBox(
                                          height: 0,
                                          child: ClipPath(
                                            clipper:
                                                const StoreToSearchWaveClipper(),
                                            child: ColoredBox(
                                              color: searchZoneTheme.waveColor,
                                            ),
                                          ),
                                        ),
                                        HomeSearchBar(
                                          onSearchTap: _openSearch,
                                          animateHints:
                                              isTopChromeMotionEnabled,
                                          searchTheme: searchZoneTheme,
                                          outerPadding: EdgeInsets.fromLTRB(
                                            12.w,
                                            0,
                                            0,
                                            0,
                                          ),
                                        ),
                                        if (showCategoryTabs) ...<Widget>[
                                          Gap(10.h),
                                          const CategoryTabsRow(),
                                        ] else
                                          Gap(18.h),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (showLegacySections) ...<Widget>[
                            SliverToBoxAdapter(
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _isTopChromeMotionEnabled,
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final remoteTheme = ref.watch(
                                      activeTabThemeProvider,
                                    );
                                    return RepaintBoundary(
                                      child: AnimatedBannerSection(
                                        assetPath:
                                            'assets/lottie/summer_banner.lottie',
                                        bannerTheme: remoteTheme
                                            .sections.bannerAnimation,
                                        feeStripTheme:
                                            remoteTheme.sections.feeStrip,
                                      ),
                                    );
                                  },
                                ),
                                builder: (
                                  context,
                                  isTopChromeMotionEnabled,
                                  child,
                                ) {
                                  return TickerMode(
                                    enabled: isTopChromeMotionEnabled,
                                    child: child!,
                                  );
                                },
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: managedSeasonalProducts.isNotEmpty
                                  ? Padding(
                                      padding: EdgeInsets.only(top: 0.h),
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          final seasonalMosaicTheme = ref
                                              .watch(activeTabThemeProvider)
                                              .sections
                                              .seasonalMosaic;
                                          return RepaintBoundary(
                                            child: SeasonalDealMosaic(
                                              products: managedSeasonalProducts,
                                              heroCandidates:
                                                  _mergeUniqueProducts(
                                                <List<ProductEntity>>[
                                                  if (managedTrendingProducts
                                                      .isNotEmpty)
                                                    managedTrendingProducts,
                                                  if (managedFeaturedProducts
                                                      .isNotEmpty)
                                                    managedFeaturedProducts,
                                                  managedSeasonalProducts,
                                                ],
                                              ),
                                              mosaicTheme: seasonalMosaicTheme,
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Consumer(
                                      builder: (context, ref, _) {
                                        final seasonalMosaicTheme = ref
                                            .watch(activeTabThemeProvider)
                                            .sections
                                            .seasonalMosaic;
                                        final dealsAsync =
                                            ref.watch(homeDealsProvider);
                                        final trendingAsync = ref.watch(
                                          homeTrendingProductsProvider,
                                        );
                                        final dealsPool =
                                            dealsAsync.asData?.value
                                                    .where(
                                                      (product) =>
                                                          product.inStock,
                                                    )
                                                    .toList() ??
                                                const <ProductEntity>[];
                                        final trendingPool =
                                            trendingAsync.asData?.value
                                                    .where(
                                                      (product) =>
                                                          product.inStock,
                                                    )
                                                    .toList() ??
                                                const <ProductEntity>[];
                                        final seasonalProducts =
                                            _mergeUniqueProducts(
                                          <List<ProductEntity>>[
                                            if (dealsPool.isNotEmpty) dealsPool,
                                            featuredProducts,
                                            if (trendingPool.isNotEmpty)
                                              trendingPool,
                                          ],
                                        );

                                        return Padding(
                                          padding: EdgeInsets.only(top: 0.h),
                                          child: RepaintBoundary(
                                            child: SeasonalDealMosaic(
                                              products: seasonalProducts,
                                              heroCandidates:
                                                  _mergeUniqueProducts(
                                                <List<ProductEntity>>[
                                                  if (trendingPool.isNotEmpty)
                                                    trendingPool,
                                                  if (featuredProducts
                                                      .isNotEmpty)
                                                    featuredProducts,
                                                  seasonalProducts,
                                                ],
                                              ),
                                              mosaicTheme: seasonalMosaicTheme,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            if (showcaseCategories.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding:
                                      EdgeInsets.fromLTRB(22.w, 8.h, 22.w, 0),
                                  child: RepaintBoundary(
                                    child: _RoundCategoryShowcase(
                                      categories: showcaseCategories,
                                    ),
                                  ),
                                ),
                              ),
                            if (managedCategorySections.isNotEmpty)
                              SliverToBoxAdapter(
                                child: () {
                                  final primarySection =
                                      managedCategorySections.first;
                                  final CategoryEntity? primaryCategory =
                                      _findCategoryById(
                                    sortedCategories,
                                    primarySection.categoryId,
                                  );
                                  final subCats = primaryCategory == null
                                      ? const <CategoryEntity>[]
                                      : sortedCategories
                                          .where(
                                            (c) =>
                                                c.parentId ==
                                                    primaryCategory.id &&
                                                c.isActive,
                                          )
                                          .take(5)
                                          .toList();

                                  if (primaryCategory != null) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        const RepaintBoundary(
                                          child: _FreshBankOfferStrip(),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(top: 4.h),
                                          child: RepaintBoundary(
                                            child: _FreshCategorySection(
                                              category: primaryCategory,
                                              subCategories: subCats,
                                              products: primarySection.products
                                                  .take(8)
                                                  .toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Padding(
                                    padding: EdgeInsets.only(top: 6.h),
                                    child: RepaintBoundary(
                                      child: _CategoryProductSection(
                                        title: primarySection.title,
                                        categoryId: primarySection.categoryId,
                                        products: primarySection.products
                                            .take(6)
                                            .toList(),
                                      ),
                                    ),
                                  );
                                }(),
                              )
                            else if (parentCategories.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final freshCat = parentCategories.first;
                                    final freshAsync = ref.watch(
                                      homeCategoryProductsProvider(freshCat.id),
                                    );
                                    final freshProducts = freshAsync
                                        .asData?.value
                                        .where((p) => p.inStock)
                                        .toList();
                                    if (freshProducts == null ||
                                        freshProducts.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    final subCats = sortedCategories
                                        .where(
                                          (c) =>
                                              c.parentId == freshCat.id &&
                                              c.isActive,
                                        )
                                        .take(5)
                                        .toList();

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        const RepaintBoundary(
                                          child: _FreshBankOfferStrip(),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(top: 4.h),
                                          child: RepaintBoundary(
                                            child: _FreshCategorySection(
                                              category: freshCat,
                                              subCategories: subCats,
                                              products: freshProducts
                                                  .take(8)
                                                  .toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ValueListenableBuilder<int>(
                              valueListenable: _deferredSectionStage,
                              builder: (context, deferredSectionStage, _) {
                                if (deferredSectionStage < 1) {
                                  return const SliverToBoxAdapter(
                                    child: SizedBox.shrink(),
                                  );
                                }

                                return SliverToBoxAdapter(
                                  child: managedTrendingProducts.isNotEmpty
                                      ? Padding(
                                          padding: EdgeInsets.only(top: 6.h),
                                          child: RepaintBoundary(
                                            child: _TrendingNearYouSection(
                                              products: managedTrendingProducts
                                                  .take(6)
                                                  .toList(),
                                            ),
                                          ),
                                        )
                                      : Consumer(
                                          builder: (context, ref, _) {
                                            final trendingAsync = ref.watch(
                                              homeTrendingProductsProvider,
                                            );
                                            final trendingProducts =
                                                trendingAsync.asData?.value
                                                        .where((p) => p.inStock)
                                                        .toList() ??
                                                    const <ProductEntity>[];
                                            if (trendingProducts.isEmpty) {
                                              return const SizedBox.shrink();
                                            }

                                            return Padding(
                                              padding:
                                                  EdgeInsets.only(top: 6.h),
                                              child: RepaintBoundary(
                                                child: _TrendingNearYouSection(
                                                  products: trendingProducts
                                                      .take(6)
                                                      .toList(),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                );
                              },
                            ),
                            ...() {
                              if (managedCategorySections.length > 1) {
                                final remaining = managedCategorySections
                                    .skip(1)
                                    .toList(growable: false);
                                return <Widget>[
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final section = remaining[index];
                                        return Padding(
                                          padding: EdgeInsets.only(top: 6.h),
                                          child: RepaintBoundary(
                                            child: _CategoryProductSection(
                                              title: section.title,
                                              categoryId: section.categoryId,
                                              products: section.products
                                                  .take(6)
                                                  .toList(),
                                            ),
                                          ),
                                        );
                                      },
                                      childCount: remaining.length,
                                    ),
                                  ),
                                ];
                              }

                              return <Widget>[
                                ValueListenableBuilder<List<Widget>>(
                                  valueListenable: _cachedStagedSlivers,
                                  builder: (context, slivers, _) {
                                    if (slivers.isEmpty) {
                                      return const SliverToBoxAdapter(
                                        child: SizedBox.shrink(),
                                      );
                                    }
                                    return SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => slivers[index],
                                        childCount: slivers.length,
                                      ),
                                    );
                                  },
                                ),
                              ];
                            }(),
                          ] else
                            const DynamicHomeSections(),
                          SliverToBoxAdapter(child: Gap(0)),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _stickyHeaderProgress,
                        child: _StickySearchOverlayChrome(
                          topInset: topInset,
                          onSearchTap: _openSearch,
                          searchTheme: searchZoneTheme,
                          showCategoryTabs: showCategoryTabs,
                        ),
                        builder: (context, progress, child) {
                          return _StickySearchOverlay(
                            progress: progress,
                            topInset: topInset,
                            showCategoryTabs: showCategoryTabs,
                            child: child!,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<CategoryEntity> _buildParentCategories(
    List<CategoryEntity> categories,
  ) {
    final parents = categories
        .where((category) => category.isParent && category.productCount > 0)
        .toList(growable: false);
    return parents.isNotEmpty ? parents : categories.take(8).toList();
  }

  CategoryEntity? _findCategoryById(
    List<CategoryEntity> categories,
    String categoryId,
  ) {
    for (final category in categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  List<ProductEntity> _filterProducts(
    List<ProductEntity> products,
    CategoryEntity? category,
  ) {
    if (category == null) {
      return products;
    }

    final filtered = products.where((product) {
      if (product.categoryId == category.id) {
        return true;
      }

      return (product.categoryName ?? '').trim().toLowerCase() ==
          category.name.trim().toLowerCase();
    }).toList(growable: false);
    return filtered.isNotEmpty ? filtered : products;
  }

  List<ProductEntity> _mergeUniqueProducts(List<List<ProductEntity>> groups) {
    final seen = <String>{};
    final merged = <ProductEntity>[];

    for (final group in groups) {
      for (final product in group) {
        if (seen.add(product.id)) {
          merged.add(product);
        }
      }
    }

    return merged;
  }

  List<CategoryEntity> _categoriesWithRenderableImages(
    List<CategoryEntity> categories,
  ) {
    return categories
        .where((category) => _hasRenderableMediaUrl(category.imageUrl))
        .toList(growable: false);
  }

  List<_HomePromoData> _buildBannerCarouselCards(List<BannerEntity> banners) {
    final validBanners = banners.where(
      (banner) => _hasRenderableMediaUrl(banner.imageUrl),
    );

    return validBanners
        .map(
          (banner) => _HomePromoData(
            eyebrow: (banner.title ?? '').trim(),
            headline: (banner.subtitle ?? '').trim(),
            supporting: (banner.linkType).trim(),
            cta: 'Explore',
            imageUrl: banner.imageUrl,
            routePath: _routePathForBanner(banner),
          ),
        )
        .toList(growable: false);
  }

  String? _routePathForBanner(BannerEntity banner) {
    final linkValue = banner.linkValue;
    if (linkValue == null || linkValue.isEmpty) {
      return null;
    }

    final lowerType = banner.linkType.toLowerCase();
    if (lowerType.contains('product')) {
      return '/product/$linkValue';
    }
    if (lowerType.contains('category')) {
      return '/categories/$linkValue/products';
    }
    return null;
  }
}

class _StickySearchOverlay extends StatelessWidget {
  const _StickySearchOverlay({
    required this.child,
    required this.progress,
    required this.topInset,
    required this.showCategoryTabs,
  });

  final Widget child;
  final double progress;
  final double topInset;
  final bool showCategoryTabs;

  double get _searchTopPadding => 8.h;
  double get _betweenSections => 6.h;
  double get _tabsHeight => showCategoryTabs ? 44.h : 0;
  double get _tabsBlockSpacing => showCategoryTabs ? _betweenSections : 0;
  double get _hiddenTabsBottomSpacing => showCategoryTabs ? 0 : 12.h;
  double get _bottomPadding => 6.h;
  double get _headerExtent =>
      topInset +
      _searchTopPadding +
      56.h +
      _tabsBlockSpacing +
      _tabsHeight +
      _hiddenTabsBottomSpacing +
      _bottomPadding;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0) {
      return const SizedBox.shrink();
    }

    final backgroundProgress = Curves.easeOutCubic.transform(clampedProgress);
    final contentProgress = Curves.easeOutCubic.transform(
      ((clampedProgress - 0.12) / 0.88).clamp(0.0, 1.0),
    );

    return IgnorePointer(
      ignoring: clampedProgress < 0.82,
      child: RepaintBoundary(
        child: SizedBox(
          height: _headerExtent,
          child: Transform.translate(
            offset: Offset(0, (-14.h) * (1 - backgroundProgress)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.transparent,
                  Colors.white,
                  backgroundProgress,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Color.lerp(
                          Colors.transparent,
                          const Color(0xFFE8E8E8),
                          backgroundProgress,
                        ) ??
                        Colors.transparent,
                  ),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.05 * backgroundProgress,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Opacity(
                opacity: contentProgress,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickySearchOverlayChrome extends StatelessWidget {
  const _StickySearchOverlayChrome({
    required this.topInset,
    required this.onSearchTap,
    required this.showCategoryTabs,
    this.searchTheme,
  });

  final double topInset;
  final VoidCallback onSearchTap;
  final bool showCategoryTabs;
  final SearchZoneTheme? searchTheme;

  double get _searchTopPadding => 8.h;
  double get _betweenSections => 6.h;
  double get _bottomPadding => 6.h;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: topInset),
        HomeSearchBar(
          onSearchTap: onSearchTap,
          animateHints: false,
          searchTheme: searchTheme,
          outerPadding: EdgeInsets.fromLTRB(12.w, _searchTopPadding, 0, 0),
        ),
        if (showCategoryTabs) ...<Widget>[
          Gap(_betweenSections),
          const CategoryTabsRow(textOnly: true),
        ] else
          Gap(12.h),
        Gap(_bottomPadding),
      ],
    );
  }
}

class _HeroPromoCarousel extends StatefulWidget {
  const _HeroPromoCarousel({required this.cards});

  final List<_HomePromoData> cards;

  @override
  State<_HeroPromoCarousel> createState() => _HeroPromoCarouselState();
}

class _HeroPromoCarouselState extends State<_HeroPromoCarousel> {
  static const int _loopSeedMultiplier = 1000;

  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _virtualPage = 0;

  @override
  void initState() {
    super.initState();
    _virtualPage = _startingVirtualPage(widget.cards.length);
    _pageController = PageController(
      viewportFraction: 0.88,
      initialPage: _virtualPage,
    );
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _HeroPromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards.length != widget.cards.length) {
      _autoPlayTimer?.cancel();
      _virtualPage = _startingVirtualPage(widget.cards.length);
      _jumpToVirtualPage(_virtualPage);
      _startAutoPlay();
    }
  }

  int _startingVirtualPage(int length) {
    if (length <= 1) {
      return 0;
    }
    return length * _loopSeedMultiplier;
  }

  int _effectiveIndex(int page) {
    final length = widget.cards.length;
    if (length == 0) {
      return 0;
    }
    final remainder = page % length;
    return remainder < 0 ? remainder + length : remainder;
  }

  void _jumpToVirtualPage(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.jumpToPage(page);
    });
  }

  void _startAutoPlay() {
    if (widget.cards.length <= 1) {
      return;
    }
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      final nextPage = _virtualPage + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: SizedBox(
            height: 198.h,
            child: PageView.builder(
              controller: _pageController,
              padEnds: true,
              clipBehavior: Clip.none,
              itemCount: widget.cards.length <= 1 ? widget.cards.length : null,
              onPageChanged: (value) {
                _virtualPage = value;
              },
              itemBuilder: (context, index) {
                final card = widget.cards[_effectiveIndex(index)];
                return Padding(
                  padding: EdgeInsets.fromLTRB(6.w, 4.h, 6.w, 6.h),
                  child: _HeroPromoCard(card: card),
                );
              },
            ),
          ),
        ),
        Gap(2.h),
      ],
    );
  }
}

class _HeroPromoCard extends StatelessWidget {
  const _HeroPromoCard({required this.card});

  final _HomePromoData card;

  @override
  Widget build(BuildContext context) {
    final optimizedImage = ApiConstants.optimizedMedia(
      card.imageUrl,
      profile: CustomerImageProfile.banner,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: card.routePath == null
                ? null
                : () => context.push(card.routePath!),
            child: SizedBox.expand(
              child: card.imageUrl == null
                  ? const _FallbackHeroArt()
                  : AppImage(
                      imageUrl: optimizedImage.url ?? card.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: optimizedImage.memCacheWidth,
                      memCacheHeight: optimizedImage.memCacheHeight,
                      filterQuality: FilterQuality.low,
                      placeholder: const _FallbackHeroArt(),
                      errorWidget: const _FallbackHeroArt(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackHeroArt extends StatelessWidget {
  const _FallbackHeroArt();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3FBD7),
      child: Center(
        child: PhosphorIcon(
          PhosphorIcons.imageSquare(PhosphorIconsStyle.duotone),
          size: 40.sp,
          color: const Color(0xFF9BA56A),
        ),
      ),
    );
  }
}

double _displayRatingForProduct(ProductEntity product) {
  final value = 4.1 + ((product.totalSold % 8) / 10);
  return value.clamp(4.1, 4.9);
}

String? _firstRenderableProductImage(ProductEntity product) {
  final candidates = <String?>[
    product.thumbnailUrl,
    ...product.images,
  ];

  for (final candidate in candidates) {
    if (_hasRenderableMediaUrl(candidate)) {
      return candidate!.trim();
    }
  }

  return null;
}

bool _hasRenderableMediaUrl(String? rawUrl) {
  final value = ApiConstants.resolveMediaUrl(rawUrl)?.trim();
  if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
    return false;
  }
  if (value.startsWith('data:')) {
    return true;
  }

  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

class _RoundCategoryShowcase extends StatelessWidget {
  const _RoundCategoryShowcase({
    required this.categories,
  });

  final List<CategoryEntity> categories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        itemCount: categories.length,
        itemExtentBuilder: (index, _) => _horizontalRailExtent(
          index,
          categories.length,
          84.w,
          12.w,
        ),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Align(
            alignment: Alignment.centerLeft,
            child: _RoundCategoryCard(category: category),
          );
        },
      ),
    );
  }
}

class _RoundCategoryCard extends StatelessWidget {
  const _RoundCategoryCard({
    required this.category,
  });

  final CategoryEntity category;

  @override
  Widget build(BuildContext context) {
    final optimizedImage = ApiConstants.optimizedMedia(
      category.imageUrl,
      profile: CustomerImageProfile.categoryTile,
    );

    return InkWell(
      onTap: () => context.push('/categories/${category.id}/products'),
      borderRadius: BorderRadius.circular(20.r),
      child: SizedBox(
        width: 84.w,
        child: Column(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22.r),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x09000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Container(
                width: 64.w,
                height: 64.h,
                padding: EdgeInsets.all(2.5.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: const Color(0xFFF0F0F0),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19.r),
                  child: _hasRenderableMediaUrl(category.imageUrl)
                      ? AppImage(
                          imageUrl: optimizedImage.url ?? category.imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: optimizedImage.memCacheWidth,
                          memCacheHeight: optimizedImage.memCacheHeight,
                          filterQuality: FilterQuality.low,
                          placeholder: _CategoryCircleFallback(
                            label: category.name,
                          ),
                          errorWidget: _CategoryCircleFallback(
                            label: category.name,
                          ),
                        )
                      : _CategoryCircleFallback(label: category.name),
                ),
              ),
            ),
            Gap(8.h),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: const Color(0xFF131313),
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                height: 1.05,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

PhosphorIconData _categoryIconForLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'all') return PhosphorIcons.squaresFour();
  if (normalized.contains('fruit') || normalized.contains('vegetable')) {
    return PhosphorIcons.carrot();
  }
  if (normalized.contains('dairy') || normalized.contains('egg')) {
    return PhosphorIcons.egg();
  }
  if (normalized.contains('bakery') || normalized.contains('bread')) {
    return PhosphorIcons.bread();
  }
  if (normalized.contains('drink') || normalized.contains('juice')) {
    return PhosphorIcons.drop();
  }
  if (normalized.contains('electronics')) return PhosphorIcons.headphones();
  if (normalized.contains('beauty')) return PhosphorIcons.sparkle();
  if (normalized.contains('fresh')) return PhosphorIcons.appleLogo();
  return PhosphorIcons.squaresFour();
}

class _CategoryCircleFallback extends StatelessWidget {
  const _CategoryCircleFallback({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F6E7),
      child: Center(
        child: PhosphorIcon(
          _categoryIconForLabel(label),
          size: 24.sp,
          color: const Color(0xFF69705E),
        ),
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.title,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h2.copyWith(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionLabel != null && onTap != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warmOrangeDark,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: AppTextStyles.buttonMedium.copyWith(
                color: AppColors.warmOrangeDark,
              ),
            ),
          ),
      ],
    );
  }
}

class _SwipeRecommendationDeck extends StatefulWidget {
  const _SwipeRecommendationDeck({
    required this.products,
  });

  final List<ProductEntity> products;

  @override
  State<_SwipeRecommendationDeck> createState() =>
      _SwipeRecommendationDeckState();
}

class _SwipeRecommendationDeckState extends State<_SwipeRecommendationDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swipeController;
  late final Listenable _swipeMotion;
  final ValueNotifier<double> _dragDx = ValueNotifier<double>(0);
  final ValueNotifier<int> _frontIndex = ValueNotifier<int>(0);
  final ValueNotifier<Animation<double>?> _swipeAnimationNotifier =
      ValueNotifier<Animation<double>?>(null);
  double _deckWidth = 0;
  bool _advanceOnComplete = false;

  double get _currentDragDx =>
      _swipeAnimationNotifier.value?.value ?? _dragDx.value;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed) {
          return;
        }
        if (!mounted) {
          return;
        }
        final shouldAdvance = _advanceOnComplete && widget.products.isNotEmpty;
        _dragDx.value = 0;
        _swipeAnimationNotifier.value = null;
        if (shouldAdvance) {
          _frontIndex.value = (_frontIndex.value + 1) % widget.products.length;
        }
        _advanceOnComplete = false;
      });
    _swipeMotion = Listenable.merge(<Listenable>[
      _swipeController,
      _dragDx,
      _frontIndex,
      _swipeAnimationNotifier,
    ]);
  }

  @override
  void didUpdateWidget(covariant _SwipeRecommendationDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.products.isEmpty) {
      _swipeController.stop();
      _frontIndex.value = 0;
      _dragDx.value = 0;
      _swipeAnimationNotifier.value = null;
      _advanceOnComplete = false;
      return;
    }
    if (_frontIndex.value >= widget.products.length) {
      _frontIndex.value = 0;
    }
  }

  @override
  void dispose() {
    _dragDx.dispose();
    _frontIndex.dispose();
    _swipeAnimationNotifier.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  void _animateCardTo(double target, {required bool advance}) {
    _swipeController.stop();
    _advanceOnComplete = advance;
    _swipeAnimationNotifier.value = Tween<double>(
      begin: _currentDragDx,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _swipeController,
        curve: advance ? Curves.easeOutCubic : Curves.easeOutBack,
      ),
    );
    _swipeController
      ..reset()
      ..forward();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_swipeController.isAnimating || widget.products.length <= 1) {
      return;
    }
    _dragDx.value += details.delta.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_swipeController.isAnimating || _deckWidth <= 0) {
      return;
    }
    final threshold = _deckWidth * 0.18;
    final dragDx = _currentDragDx;
    if (dragDx.abs() > threshold) {
      final target = dragDx.isNegative ? -_deckWidth * 1.15 : _deckWidth * 1.15;
      _animateCardTo(target, advance: true);
      return;
    }
    _animateCardTo(0, advance: false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 356.h,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _deckWidth = constraints.maxWidth;
          final visibleCards =
              widget.products.length >= 3 ? 3 : widget.products.length;

          return AnimatedBuilder(
            animation: _frontIndex,
            builder: (context, _) {
              final frontIndex = _frontIndex.value;
              return Stack(
                clipBehavior: Clip.none,
                children: List<Widget>.generate(visibleCards, (depth) {
                  final reverseDepth = visibleCards - 1 - depth;
                  final productIndex =
                      (frontIndex + reverseDepth) % widget.products.length;
                  final product = widget.products[productIndex];
                  final isFront = reverseDepth == 0;
                  final baseTop = reverseDepth * 12.h;
                  final baseScale = 1 - (reverseDepth * 0.045);

                  return Positioned.fill(
                    top: baseTop,
                    child: IgnorePointer(
                      ignoring: !isFront,
                      child: GestureDetector(
                        onHorizontalDragUpdate:
                            isFront ? _onHorizontalDragUpdate : null,
                        onHorizontalDragEnd:
                            isFront ? _onHorizontalDragEnd : null,
                        behavior: HitTestBehavior.translucent,
                        child: AnimatedBuilder(
                          animation: _swipeMotion,
                          child: _SwipeRecommendationCard(
                            product: product,
                          ),
                          builder: (context, child) {
                            final dragDx = _currentDragDx;
                            final dragProgress = (dragDx.abs() /
                                    (_deckWidth == 0 ? 1 : _deckWidth))
                                .clamp(0.0, 1.0);
                            final extraLift =
                                !isFront ? dragProgress * 8.h : 0.0;

                            return Transform.translate(
                              offset: Offset(
                                isFront ? dragDx : 0,
                                baseTop - extraLift,
                              ),
                              child: Transform.rotate(
                                angle: isFront && _deckWidth > 0
                                    ? (dragDx / _deckWidth) * 0.12
                                    : 0,
                                child: Transform.scale(
                                  scale: isFront
                                      ? 1
                                      : (baseScale + dragProgress * 0.03),
                                  alignment: Alignment.topCenter,
                                  child: child,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }
}

class _SwipeRecommendationCard extends StatelessWidget {
  const _SwipeRecommendationCard({
    required this.product,
  });

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _firstRenderableProductImage(product);
    final optimizedImageUrl = ApiConstants.optimizeCloudinaryUrl(
      imageUrl,
      width: 420,
      height: 420,
      crop: 'fit',
    );
    final rating = _displayRatingForProduct(product);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        borderRadius: BorderRadius.circular(30.r),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(
              color: const Color(0xFFF8F8F8),
              width: 1.2,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24.r),
                  child: ColoredBox(
                    color: const Color(0xFFFAFAFA),
                    child: SizedBox(
                      width: double.infinity,
                      child: imageUrl == null
                          ? Center(
                              child: PhosphorIcon(
                                PhosphorIcons.imageSquare(
                                  PhosphorIconsStyle.duotone,
                                ),
                                size: 52.sp,
                                color: AppColors.warmMuted,
                              ),
                            )
                          : AppImage(
                              imageUrl: optimizedImageUrl ?? imageUrl,
                              fit: BoxFit.contain,
                              memCacheWidth: 420,
                              memCacheHeight: 420,
                              filterQuality: FilterQuality.low,
                              placeholder: const ColoredBox(
                                color: Color(0xFFFAFAFA),
                                child: SizedBox.expand(),
                              ),
                              errorWidget: Center(
                                child: PhosphorIcon(
                                  PhosphorIcons.imageSquare(
                                    PhosphorIconsStyle.duotone,
                                  ),
                                  size: 52.sp,
                                  color: AppColors.warmMuted,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              Gap(14.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              PhosphorIcon(
                                PhosphorIcons.star(PhosphorIconsStyle.fill),
                                size: 14.sp,
                                color: const Color(0xFFFFA300),
                              ),
                              Gap(6.w),
                              Text(
                                rating.toStringAsFixed(1),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: const Color(0xFF1E1E1E),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Gap(10.h),
                        Text(
                          product.effectivePrice.toInrCurrency,
                          style: AppTextStyles.priceMain.copyWith(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.isOnSale)
                          Text(
                            product.price.toInrCurrency,
                            style: AppTextStyles.priceMRP.copyWith(
                              fontSize: 12.sp,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _HomeCartControl(
                    product: product,
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCartControl extends ConsumerWidget {
  const _HomeCartControl({
    required this.product,
    required this.compact,
  });

  final ProductEntity product;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartItemQuantityProvider(product.id));
    final cartNotifier = ref.read(cartProvider.notifier);

    if (quantity <= 0) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final authGate = ref.read(authGateControllerProvider);
            final authed = await authGate.protectAddToCart(
              context,
              product,
            );
            if (!authed) {
              return;
            }
            await cartNotifier.addItem(product.id, 1, product: product);
          },
          borderRadius: BorderRadius.circular(compact ? 16.r : 18.r),
          child: Ink(
            width: compact ? 40.w : 50.w,
            height: compact ? 40.h : 50.h,
            decoration: BoxDecoration(
              color: AppColors.warmOrange,
              borderRadius: BorderRadius.circular(compact ? 16.r : 18.r),
              boxShadow: const <BoxShadow>[AppShadows.cardShadow],
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIcons.plus(),
                color: Colors.white,
                size: compact ? 18.sp : 20.sp,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8.w : 10.w),
      height: compact ? 40.h : 48.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 18.r : 20.r),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _QuantityButton(
            icon: PhosphorIcons.minus(),
            onTap: () {
              if (quantity == 1) {
                cartNotifier.removeItem(product.id);
              } else {
                cartNotifier.updateItem(product.id, quantity - 1);
              }
            },
          ),
          SizedBox(
            width: compact ? 24.w : 28.w,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.buttonMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _QuantityButton(
            icon: PhosphorIcons.plus(),
            onTap: () => cartNotifier.updateItem(product.id, quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: SizedBox(
        width: 24.w,
        height: 24.h,
        child: Center(
          child: PhosphorIcon(
            icon,
            size: 16.sp,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Fancy category name mapping ─────────────────────────

String _fancyCategoryName(String raw) {
  final n = raw.trim().toLowerCase();
  if (n.contains('dairy') || n.contains('egg')) {
    return '🥛 Dairy & Breakfast Essentials';
  }
  if (n.contains('fruit') || n.contains('vegetable')) {
    return '🥬 Fresh Fruits & Veggies';
  }
  if (n.contains('snack')) {
    return '🍿 Snacks & Munchies';
  }
  if (n.contains('drink') || n.contains('beverage') || n.contains('juice')) {
    return '🥤 Cold Drinks & Juices';
  }
  if (n.contains('bakery') || n.contains('bread')) {
    return '🍞 Bakery & Bread';
  }
  if (n.contains('oil') || n.contains('ghee') || n.contains('masala')) {
    return '🫗 Oils, Ghee & Masala';
  }
  if (n.contains('clean') || n.contains('household')) {
    return '🧹 Cleaning & Household';
  }
  if (n.contains('beauty') || n.contains('personal')) {
    return '✨ Beauty & Personal Care';
  }
  return '🛒 $raw';
}

// ── Fresh Category Section (Blinkit-style banner) ───────

class _FreshCategorySection extends StatelessWidget {
  const _FreshCategorySection({
    required this.category,
    required this.subCategories,
    required this.products,
  });

  final CategoryEntity category;
  final List<CategoryEntity> subCategories;
  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context) {
    final shortcutTiles = _buildFreshShortcutTiles(
      category: category,
      subCategories: subCategories,
      products: products,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4FAE8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Banner header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(2.w, 0, 10.w, 2.h),
            decoration: const BoxDecoration(
              color: Color(0xFFF6FFE2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Transform.translate(
                      offset: Offset(-4.w, 4.h),
                      child: Image.asset(
                        'assets/images/Fresh_text.png',
                        width: 198.w,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 172.w,
                  height: 120.h,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Transform.translate(
                      offset: Offset(0, -26.h),
                      child: Image.asset(
                        'assets/images/fresh_onion_offer.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.topRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Sub-category chips ──
          if (shortcutTiles.isNotEmpty) ...<Widget>[
            Gap(4.h),
            SizedBox(
              height: 84.h,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                itemCount: shortcutTiles.length,
                itemExtentBuilder: (index, _) => _horizontalRailExtent(
                  index,
                  shortcutTiles.length,
                  68.w,
                  8.w,
                ),
                itemBuilder: (context, index) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: _FreshSubCategoryTile(
                      tile: shortcutTiles[index],
                      isActive: index == 0,
                      onTap: () => context.push(shortcutTiles[index].route),
                    ),
                  );
                },
              ),
            ),
            Gap(4.h),
            Padding(
              padding: EdgeInsets.only(left: 18.w),
              child: Container(
                width: 82.w,
                height: 2.5.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ],
          // ── Products horizontal rail ──
          Gap(8.h),
          SizedBox(
            height: 222.h,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              itemCount: products.length,
              itemExtentBuilder: (index, _) => _horizontalRailExtent(
                index,
                products.length,
                118.w,
                8.w,
              ),
              itemBuilder: (context, index) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 118.w,
                    child: RepaintBoundary(
                      child: _FreshProductCard(
                        product: products[index],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // ── See all button ──
          Gap(8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push(
                  '/categories/${category.id}/products',
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  side: const BorderSide(color: Color(0xFFDCDCDC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  backgroundColor: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'See all',
                      style: TextStyle(
                        color: const Color(0xFF2B2B2B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Gap(4.w),
                    PhosphorIcon(
                      PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                      size: 14.sp,
                      color: const Color(0xFF2B2B2B),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Gap(4.h),
        ],
      ),
    );
  }
}

class _FreshBankOfferStrip extends StatelessWidget {
  const _FreshBankOfferStrip();

  static const List<String> _freshBankOfferBanners = <String>[
    'assets/images/ICICI_bank_offer_banner.png',
    'assets/images/Kotak_Mahindra_bank_offer_banner.png',
    'assets/images/HDFC_bank_offer_banner.png',
    'assets/images/Axis_bank_offer_banner.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 6.h, 0, 2.h),
      child: SizedBox(
        height: 74.h,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          itemCount: _freshBankOfferBanners.length,
          itemExtentBuilder: (index, _) => _horizontalRailExtent(
            index,
            _freshBankOfferBanners.length,
            336.w,
            14.w,
          ),
          itemBuilder: (context, index) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                _freshBankOfferBanners[index],
                width: 336.w,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FreshSubCategoryTile extends StatelessWidget {
  const _FreshSubCategoryTile({
    required this.tile,
    required this.isActive,
    required this.onTap,
  });

  final _FreshShortcutTileData tile;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final optimizedImage = ApiConstants.optimizedMedia(
      tile.imageUrl,
      profile: CustomerImageProfile.categoryTile,
    );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 60.r,
            height: 60.r,
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF222222)
                    : const Color(0xFFE6E6E6),
                width: isActive ? 1.0 : 0.9,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0E000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: tile.isPriceZone
                ? Center(
                    child: Container(
                      width: 30.r,
                      height: 30.r,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE70F72),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Center(
                        child: Text(
                          '₹1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: tile.imageUrl != null && tile.imageUrl!.isNotEmpty
                        ? AppImage(
                            imageUrl: optimizedImage.url ?? tile.imageUrl!,
                            fit: BoxFit.contain,
                            memCacheWidth: optimizedImage.memCacheWidth,
                            memCacheHeight: optimizedImage.memCacheHeight,
                            filterQuality: FilterQuality.low,
                            errorWidget: Center(
                              child: PhosphorIcon(
                                PhosphorIcons.package(
                                  PhosphorIconsStyle.duotone,
                                ),
                                size: 22.sp,
                                color: AppColors.warmMuted,
                              ),
                            ),
                          )
                        : Center(
                            child: PhosphorIcon(
                              PhosphorIcons.package(
                                PhosphorIconsStyle.duotone,
                              ),
                              size: 22.sp,
                              color: AppColors.warmMuted,
                            ),
                          ),
                  ),
          ),
          Gap(5.h),
          SizedBox(
            width: 68.w,
            child: Text(
              tile.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF242424),
                fontSize: 9.8.sp,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                height: 1.18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreshShortcutTileData {
  const _FreshShortcutTileData({
    required this.label,
    required this.route,
    this.imageUrl,
    this.isPriceZone = false,
  });

  final String label;
  final String route;
  final String? imageUrl;
  final bool isPriceZone;
}

List<_FreshShortcutTileData> _buildFreshShortcutTiles({
  required CategoryEntity category,
  required List<CategoryEntity> subCategories,
  required List<ProductEntity> products,
}) {
  if (subCategories.isNotEmpty) {
    return subCategories.take(5).map((subCategory) {
      return _FreshShortcutTileData(
        label: _freshShortcutLabel(subCategory.name),
        route: '/categories/${subCategory.id}/products',
        imageUrl: ApiConstants.resolveMediaUrl(subCategory.imageUrl),
      );
    }).toList(growable: false);
  }

  final usedProductIds = <String>{};
  ProductEntity? pickByKeywords(List<String> keywords) {
    for (final product in products) {
      if (usedProductIds.contains(product.id)) {
        continue;
      }
      final haystack = <String>[
        product.name,
        product.categoryName ?? '',
        ...product.tags,
      ].join(' ').toLowerCase();
      if (keywords.any(haystack.contains)) {
        usedProductIds.add(product.id);
        return product;
      }
    }
    for (final product in products) {
      if (usedProductIds.add(product.id)) {
        return product;
      }
    }
    return null;
  }

  final veggieProduct = pickByKeywords(
    const <String>[
      'spinach',
      'palak',
      'potato',
      'tomato',
      'onion',
      'vegetable',
    ],
  );
  final fruitProduct = pickByKeywords(
    const <String>['apple', 'banana', 'fruit', 'mango', 'orange'],
  );
  final launchProduct = pickByKeywords(
    const <String>['fresh', 'new', 'local', 'shimla'],
  );
  final pickProduct = pickByKeywords(const <String>['pack', 'kg', 'piece']);

  return <_FreshShortcutTileData>[
    _FreshShortcutTileData(
      label: '₹1 Zone',
      route: '/categories/${category.id}/products',
      isPriceZone: true,
    ),
    if (veggieProduct != null)
      _FreshShortcutTileData(
        label: 'Veggies',
        route: '/categories/${category.id}/products',
        imageUrl: _firstRenderableProductImage(veggieProduct),
      ),
    if (fruitProduct != null)
      _FreshShortcutTileData(
        label: 'Fruits',
        route: '/categories/${category.id}/products',
        imageUrl: _firstRenderableProductImage(fruitProduct),
      ),
    if (launchProduct != null)
      _FreshShortcutTileData(
        label: 'New Launches',
        route: '/categories/${category.id}/products',
        imageUrl: _firstRenderableProductImage(launchProduct),
      ),
    if (pickProduct != null)
      _FreshShortcutTileData(
        label: 'Fresh Picks',
        route: '/categories/${category.id}/products',
        imageUrl: _firstRenderableProductImage(pickProduct),
      ),
  ];
}

String _freshShortcutLabel(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.contains('veg')) {
    return 'Veggies';
  }
  if (normalized.contains('fruit')) {
    return 'Fruits';
  }
  if (normalized.contains('new')) {
    return 'New Launches';
  }
  if (normalized.contains('plant') || normalized.contains('bouquet')) {
    return 'Bouquet Plants';
  }
  return raw;
}

// ── Fresh Product Card (pink circle + button) ──────────

class _FreshProductCard extends StatelessWidget {
  const _FreshProductCard({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _firstRenderableProductImage(product);
    final imagePalette = productImagePalette(
      product,
      variant: PaletteVariant.fresh,
    );
    final optimizedImage = ApiConstants.optimizedMedia(
      imageUrl,
      profile: CustomerImageProfile.homeProduct,
    );
    final hasDiscount = product.isOnSale && product.discountPercent > 0;
    final discountAmount =
        hasDiscount ? (product.price - product.effectivePrice) : 0.0;

    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── Image box + pink circle button ──
          AspectRatio(
            aspectRatio: 0.76,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: imagePalette.gradient,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFFE7E7E7), width: 0.8),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9.r),
                      child: imageUrl == null
                          ? Center(
                              child: PhosphorIcon(
                                PhosphorIcons.imageSquare(
                                  PhosphorIconsStyle.duotone,
                                ),
                                size: 34.sp,
                                color: AppColors.warmMuted,
                              ),
                            )
                          : AppImage(
                                imageUrl: optimizedImage.url ?? imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                memCacheWidth: optimizedImage.memCacheWidth,
                                memCacheHeight: optimizedImage.memCacheHeight,
                                filterQuality: FilterQuality.low,
                                placeholder: ColoredBox(
                                  color: imagePalette.fallbackColor,
                                  child: const SizedBox.expand(),
                                ),
                                errorWidget: ColoredBox(
                                  color: imagePalette.fallbackColor,
                                  child: Center(
                                    child: PhosphorIcon(
                                      PhosphorIcons.imageSquare(
                                        PhosphorIconsStyle.duotone,
                                      ),
                                      size: 34.sp,
                                      color: AppColors.warmMuted,
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ),
                  // Pink add button at bottom-right
                  Positioned(
                    bottom: 4.h,
                    right: 4.w,
                    child: _FreshInlineCartButton(
                      product: product,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gap(2.h),
          // ── Price badge + MRP ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B8721),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: Colors.black,
                    width: 2.2,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  product.effectivePrice.toInrCurrency,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.8.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasDiscount) ...<Widget>[
                Gap(3.w),
                Flexible(
                  child: Text(
                    product.price.toInrCurrency,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF8F8F8F),
                      fontSize: 9.6.sp,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: const Color(0xFF999999),
                    ),
                  ),
                ),
              ],
            ],
          ),
          // ── Discount OFF ──
          if (hasDiscount) ...<Widget>[
            Gap(0.5.h),
            Row(
              children: <Widget>[
                Text(
                  '₹${discountAmount.toStringAsFixed(0)} OFF',
                  style: TextStyle(
                    color: const Color(0xFF1B8721),
                    fontSize: 8.8.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap(4.w),
                const Expanded(
                  child: SizedBox(
                    height: 1,
                    child: CustomPaint(
                      painter: DashedLinePainter(
                        color: Color(0xFF1B8721),
                        strokeWidth: 1,
                        dashWidth: 3,
                        dashSpace: 2,
                        style: null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          Gap(1.h),
          // ── Product name ──
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF2B2B2B),
              fontSize: 9.9.sp,
              fontWeight: FontWeight.w700,
              height: 1.12,
            ),
          ),
          Gap(0.5.h),
          // ── Unit ──
          Text(
            product.unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFAAAAAA),
              fontSize: 8.6.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreshInlineCartButton extends ConsumerWidget {
  const _FreshInlineCartButton({
    required this.product,
  });

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartItemQuantityProvider(product.id));
    final cartNotifier = ref.read(cartProvider.notifier);

    return GestureDetector(
      onTap: () async {
        if (quantity > 0) {
          cartNotifier.updateItem(product.id, quantity + 1);
          return;
        }

        final authGate = ref.read(authGateControllerProvider);
        final authed = await authGate.protectAddToCart(context, product);
        if (!authed) {
          return;
        }
        await cartNotifier.addItem(product.id, 1, product: product);
      },
      child: Container(
        width: 36.r,
        height: 32.r,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: const Color(0xFFD6006F),
            width: 1.5,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: quantity > 0
              ? Text(
                  '$quantity',
                  style: TextStyle(
                    color: const Color(0xFFD6006F),
                    fontSize: 11.2.sp,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : PhosphorIcon(
                  PhosphorIcons.plus(PhosphorIconsStyle.bold),
                  size: 16.sp,
                  color: const Color(0xFFD6006F),
                ),
        ),
      ),
    );
  }
}

// ── Trending Near You — 3×2 grid ────────────────────────

class _TrendingNearYouSection extends StatelessWidget {
  const _TrendingNearYouSection({required this.products});

  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.h2.copyWith(
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              children: <TextSpan>[
                const TextSpan(text: 'Trending Near '),
                TextSpan(
                  text: 'You',
                  style: TextStyle(
                    color: const Color(0xFF0D8320),
                    fontWeight: FontWeight.w900,
                    fontSize: 19.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
        Gap(10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: RepaintBoundary(
            child: _ThreeColumnProductGrid<ProductEntity>(
              items: products.take(6).toList(growable: false),
              itemBuilder: (product) => ProductCard(
                product: product,
                width: _threeColumnCardWidth(context),
                style: ProductCardStyle.grid,
                showWishlist: true,
                onTap: () => context.push('/products/${product.id}'),
                onOptionsTap: () => showProductOptionsSheet(context, product),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Category Product Section — 3×2 grid ─────────────────

class _CategoryProductSection extends StatelessWidget {
  const _CategoryProductSection({
    required this.title,
    required this.categoryId,
    required this.products,
  });

  final String title;
  final String categoryId;
  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: _HomeSectionHeader(
            title: title,
            actionLabel: 'see all',
            onTap: () => context.push('/categories/$categoryId/products'),
          ),
        ),
        Gap(10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: RepaintBoundary(
            child: _ThreeColumnProductGrid<ProductEntity>(
              items: products.take(6).toList(growable: false),
              itemBuilder: (product) => ProductCard(
                product: product,
                width: _threeColumnCardWidth(context),
                style: ProductCardStyle.grid,
                showWishlist: true,
                onTap: () => context.push('/products/${product.id}'),
                onOptionsTap: () => showProductOptionsSheet(context, product),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreeColumnProductGrid<T> extends StatelessWidget {
  const _ThreeColumnProductGrid({
    required this.items,
    required this.itemBuilder,
  });

  final List<T> items;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <List<T>>[];
    for (var index = 0; index < items.length; index += 3) {
      final nextIndex = index + 3 < items.length ? index + 3 : items.length;
      rows.add(items.sublist(index, nextIndex));
    }

    return Column(
      children: <Widget>[
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...<Widget>[
          if (rowIndex > 0) Gap(12.h),
          // IntrinsicHeight + stretch makes every card in a row share the
          // tallest card's height so product boxes align across the grid
          // regardless of name length / option label / rating presence.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var columnIndex = 0;
                    columnIndex < 3;
                    columnIndex++) ...<Widget>[
                  Expanded(
                    child: columnIndex < rows[rowIndex].length
                        ? RepaintBoundary(
                            child: itemBuilder(rows[rowIndex][columnIndex]),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (columnIndex < 2) Gap(10.w),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Dashed line painter ─────────────────────────────────

class _HomePromoData {
  const _HomePromoData({
    required this.eyebrow,
    required this.headline,
    required this.supporting,
    required this.cta,
    required this.imageUrl,
    required this.routePath,
  });

  final String eyebrow;
  final String headline;
  final String supporting;
  final String cta;
  final String? imageUrl;
  final String? routePath;
}

class _AddressBottomSheet extends ConsumerWidget {
  const _AddressBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeColor = ref.watch(
      selectedStoreProvider.select((store) => store.chipActiveColor),
    );
    final storeBgColor = ref.watch(
      selectedStoreProvider.select((store) => store.backgroundColor),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.go(RouteNames.addresses);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: storeBgColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Manage Addresses',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: storeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(22.w, 12.h, 22.w, 124.h),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonLoader(width: 190.w, height: 24.h, radius: 12),
                    Gap(8.h),
                    SkeletonLoader(width: 168.w, height: 24.h, radius: 12),
                    Gap(12.h),
                    SkeletonLoader(width: 220.w, height: 14.h, radius: 10),
                  ],
                ),
              ),
              Gap(14.w),
              const SkeletonLoader.circular(size: 56),
              Gap(10.w),
              const SkeletonLoader.circular(size: 56),
            ],
          ),
          Gap(24.h),
          SkeletonLoader(width: double.infinity, height: 192.h, radius: 30),
          Gap(12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SkeletonLoader(width: 24.w, height: 8.h, radius: 99),
              Gap(6.w),
              SkeletonLoader(width: 8.w, height: 8.h, radius: 99),
              Gap(6.w),
              SkeletonLoader(width: 8.w, height: 8.h, radius: 99),
            ],
          ),
          Gap(18.h),
          SizedBox(
            height: 56.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemExtentBuilder: (index, _) => _horizontalRailExtent(
                index,
                4,
                124.w,
                12.w,
              ),
              itemBuilder: (_, __) => SkeletonLoader(
                width: 124.w,
                height: 56.h,
                radius: 18,
              ),
            ),
          ),
          Gap(28.h),
          SkeletonLoader(width: 180.w, height: 18.h, radius: 12),
          Gap(14.h),
          SizedBox(
            height: 306.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 2,
              itemExtentBuilder: (index, _) => _horizontalRailExtent(
                index,
                2,
                248.w,
                16.w,
              ),
              itemBuilder: (_, __) => SkeletonLoader(
                width: 248.w,
                height: 306.h,
                radius: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: 'Home feed unavailable',
      message: 'We could not load the storefront right now. Try again.',
      onRetry: () => unawaited(onRetry()),
    );
  }
}
