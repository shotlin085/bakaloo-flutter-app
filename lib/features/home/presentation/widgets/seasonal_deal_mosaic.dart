import 'dart:math' as math;

import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

class SeasonalDealMosaic extends StatelessWidget {
  const SeasonalDealMosaic({
    required this.products,
    this.heroCandidates,
    this.mosaicTheme,
    this.layoutVariant = 'hero_plus_four',
    super.key,
  });

  final List<ProductEntity> products;
  final List<ProductEntity>? heroCandidates;
  final SeasonalMosaicTheme? mosaicTheme;
  final String layoutVariant;

  @override
  Widget build(BuildContext context) {
    final tiles = _buildTiles(products, mosaicTheme);
    final heroProducts = _buildHeroProducts(heroCandidates ?? products);
    final miniTiles = _buildMiniAssetTiles(products, mosaicTheme);
    if (tiles.isEmpty || miniTiles.isEmpty) {
      return const SizedBox.shrink();
    }

    late final Widget content;
    switch (layoutVariant) {
      case 'two_by_three':
        content = _buildMiniTileGrid(
          miniTiles,
          crossAxisCount: 3,
          tileCount: 6,
          childAspectRatio: 0.78,
        );
        break;
      case 'single_hero':
        content = Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: AspectRatio(
            aspectRatio: 1.95,
            child: _HeroSeasonalDealTile(
              product: heroProducts.first,
              title: tiles[0].title,
              gradient: tiles[0].gradient,
              heroTileTheme: mosaicTheme?.heroTile,
            ),
          ),
        );
        break;
      case 'two_by_two':
        content = _buildMiniTileGrid(
          miniTiles,
          crossAxisCount: 2,
          tileCount: 4,
          childAspectRatio: 1.05,
        );
        break;
      case 'stacked_banners':
        content = Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: Column(
            children: List<Widget>.generate(3, (int index) {
              final tile = miniTiles[index % miniTiles.length];
              return Padding(
                padding: EdgeInsets.only(bottom: index == 2 ? 0 : 8.h),
                child: AspectRatio(
                  aspectRatio: 2.35,
                  child: _AssetMiniDealTile(
                    product: tile.product,
                    assetPath: tile.assetPath,
                    imageUrl: tile.imageUrl,
                    title: tile.title,
                    gradient: tile.gradient,
                  ),
                ),
              );
            }),
          ),
        );
        break;
      case 'hero_plus_four':
      default:
        if (miniTiles.length < 4) {
          return const SizedBox.shrink();
        }
        content = Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: AspectRatio(
            aspectRatio: 1.48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gap = 8.w;
                final smallGap = 8.w;
                final leftWidth = constraints.maxWidth * 0.36;
                final rightWidth = constraints.maxWidth - leftWidth - gap;
                final tileHeight = (constraints.maxHeight - smallGap) / 2;
                final tileWidth = (rightWidth - smallGap) / 2;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: leftWidth,
                      child: _HeroSeasonalDealTile(
                        product: heroProducts.first,
                        title: tiles[0].title,
                        gradient: tiles[0].gradient,
                        heroTileTheme: mosaicTheme?.heroTile,
                      ),
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: rightWidth,
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            height: tileHeight,
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: tileWidth,
                                  child: _AssetMiniDealTile(
                                    product: miniTiles[0].product,
                                    assetPath: miniTiles[0].assetPath,
                                    imageUrl: miniTiles[0].imageUrl,
                                    title: miniTiles[0].title,
                                    gradient: miniTiles[0].gradient,
                                  ),
                                ),
                                SizedBox(width: smallGap),
                                SizedBox(
                                  width: tileWidth,
                                  child: _AssetMiniDealTile(
                                    product: miniTiles[1].product,
                                    assetPath: miniTiles[1].assetPath,
                                    imageUrl: miniTiles[1].imageUrl,
                                    title: miniTiles[1].title,
                                    gradient: miniTiles[1].gradient,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: smallGap),
                          SizedBox(
                            height: tileHeight,
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: tileWidth,
                                  child: _AssetMiniDealTile(
                                    product: miniTiles[2].product,
                                    assetPath: miniTiles[2].assetPath,
                                    imageUrl: miniTiles[2].imageUrl,
                                    title: miniTiles[2].title,
                                    gradient: miniTiles[2].gradient,
                                  ),
                                ),
                                SizedBox(width: smallGap),
                                SizedBox(
                                  width: tileWidth,
                                  child: _AssetMiniDealTile(
                                    product: miniTiles[3].product,
                                    assetPath: miniTiles[3].assetPath,
                                    imageUrl: miniTiles[3].imageUrl,
                                    title: miniTiles[3].title,
                                    gradient: miniTiles[3].gradient,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        break;
    }

    final surfaceColor = mosaicTheme?.containerColor ??
        SeasonalMosaicTheme.defaults().containerColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28.r),
          bottomRight: Radius.circular(28.r),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 4.h, 0, 4.h),
        child: content,
      ),
    );
  }

  Widget _buildMiniTileGrid(
    List<_MiniAssetTileSpec> miniTiles, {
    required int crossAxisCount,
    required int tileCount,
    required double childAspectRatio,
  }) {
    final spacing = 8.w;
    final runSpacing = 8.h;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalSpacing = spacing * (crossAxisCount - 1);
          final itemWidth =
              (constraints.maxWidth - totalSpacing) / crossAxisCount;
          final itemHeight = itemWidth / childAspectRatio;

          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: List<Widget>.generate(tileCount, (int index) {
              final tile = miniTiles[index % miniTiles.length];
              return SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _AssetMiniDealTile(
                  product: tile.product,
                  assetPath: tile.assetPath,
                  imageUrl: tile.imageUrl,
                  title: tile.title,
                  gradient: tile.gradient,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _HeroSeasonalDealTile extends StatelessWidget {
  const _HeroSeasonalDealTile({
    required this.product,
    required this.title,
    required this.gradient,
    this.heroTileTheme,
  });

  final ProductEntity product;
  final String title;
  final List<Color> gradient;
  final HeroTileTheme? heroTileTheme;

  @override
  Widget build(BuildContext context) {
    final defaultHeroTileTheme = HeroTileTheme.defaults();
    final resolvedHeroTileTheme = heroTileTheme ?? defaultHeroTileTheme;
    final borderRadius = BorderRadius.circular(28.r);
    final optimizedImage = ApiConstants.optimizedMedia(
      _firstRenderableImage(product),
      profile: CustomerImageProfile.seasonalHeroArtwork,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradient,
            ),
            borderRadius: borderRadius,
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final burstSize = constraints.maxWidth * 0.54;
              final leftBottleWidth = constraints.maxWidth * 1.18;
              final leftBottleHeight = constraints.maxHeight * 0.70;
              final centerBottleWidth = constraints.maxWidth * 0.89;
              final centerBottleHeight = constraints.maxHeight * 0.67;
              final rightBottleWidth = constraints.maxWidth * 1.18;
              final rightBottleHeight = constraints.maxHeight * 0.70;
              final plusTop = constraints.maxHeight * 0.365;
              final plusLeft = constraints.maxWidth * 0.53;

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  Positioned(
                    left: constraints.maxWidth * 0.13,
                    bottom: constraints.maxHeight * 0.17,
                    child: Transform.rotate(
                      angle: 0.18,
                      child: SizedBox(
                        width: leftBottleWidth,
                        height: leftBottleHeight,
                        child: _ProductArtwork(
                          imageUrl: optimizedImage.url,
                          fallbackSize: 54.sp,
                          fit: BoxFit.contain,
                          memCacheWidth: optimizedImage.memCacheWidth,
                          memCacheHeight: optimizedImage.memCacheHeight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: plusTop,
                    left: plusLeft,
                    child: Text(
                      '+',
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        shadows: const <Shadow>[
                          Shadow(
                            color: Color(0x1C000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: constraints.maxWidth * 0.11,
                    bottom: constraints.maxHeight * 0.17,
                    child: Transform.rotate(
                      angle: -0.18,
                      child: SizedBox(
                        width: rightBottleWidth,
                        height: rightBottleHeight,
                        child: _ProductArtwork(
                          imageUrl: optimizedImage.url,
                          fallbackSize: 54.sp,
                          fit: BoxFit.contain,
                          memCacheWidth: optimizedImage.memCacheWidth,
                          memCacheHeight: optimizedImage.memCacheHeight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: constraints.maxHeight * 0.12,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: centerBottleWidth,
                        height: centerBottleHeight,
                        child: _ProductArtwork(
                          imageUrl: optimizedImage.url,
                          fallbackSize: 54.sp,
                          fit: BoxFit.cover,
                          memCacheWidth: optimizedImage.memCacheWidth,
                          memCacheHeight: optimizedImage.memCacheHeight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: constraints.maxHeight * 0.055,
                    left: constraints.maxWidth * 0.07,
                    right: constraints.maxWidth * 0.07,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                        letterSpacing: -0.65,
                        shadows: const <Shadow>[
                          Shadow(
                            color: Color(0x18000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: constraints.maxWidth * 0.09,
                    bottom: constraints.maxHeight * 0.07,
                    child: Transform.rotate(
                      angle: -0.04,
                      child: _DealBurstBadge(
                        size: burstSize,
                        text: resolvedHeroTileTheme.badgeText,
                        gradient: resolvedHeroTileTheme.badgeGradient,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AssetMiniDealTile extends StatelessWidget {
  const _AssetMiniDealTile({
    required this.product,
    required this.assetPath,
    required this.title,
    required this.gradient,
    this.imageUrl,
  });

  final ProductEntity product;
  final String assetPath;
  final String? imageUrl;
  final String title;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(24.r);

    final image = imageUrl != null
        ? AppImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            memCacheWidth: 280,
            memCacheHeight: 280,
            filterQuality: FilterQuality.low,
            errorWidget: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.low,
            ),
          )
        : Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.low,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        borderRadius: borderRadius,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradient,
              ),
              borderRadius: borderRadius,
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                image,
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  right: 18.w,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'NexaTrial',
                      color: Colors.white,
                      fontSize: 13.8.sp,
                      height: 0.95,
                      letterSpacing: -0.2,
                      fontWeight: FontWeight.w600,
                      shadows: const <Shadow>[
                        Shadow(
                          color: Color(0x22000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DealBurstBadge extends StatelessWidget {
  const _DealBurstBadge({
    required this.size,
    required this.text,
    this.gradient,
  });

  final double size;
  final String text;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    final defaultHeroTileTheme = HeroTileTheme.defaults();
    final badgeGradient = gradient ?? defaultHeroTileTheme.badgeGradient;
    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: const _BurstClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: badgeGradient,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 2,
            ),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BurstClipper extends CustomClipper<Path> {
  const _BurstClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.86;
    const pointCount = 18;

    for (var index = 0; index < pointCount * 2; index++) {
      final isOuter = index.isEven;
      final radius = isOuter ? outerRadius : innerRadius;
      final angle = (math.pi / pointCount) * index - (math.pi / 2);
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ProductArtwork extends StatelessWidget {
  const _ProductArtwork({
    required this.imageUrl,
    required this.fallbackSize,
    this.fit = BoxFit.contain,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? imageUrl;
  final double fallbackSize;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Center(
        child: PhosphorIcon(
          PhosphorIcons.imageSquare(PhosphorIconsStyle.duotone),
          size: fallbackSize,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      );
    }

    return AppImage(
      imageUrl: imageUrl!,
      fit: fit,
      memCacheWidth: memCacheWidth ?? 132,
      memCacheHeight: memCacheHeight ?? 132,
      filterQuality: FilterQuality.low,
      errorWidget: Center(
        child: PhosphorIcon(
          PhosphorIcons.imageSquare(PhosphorIconsStyle.duotone),
          size: fallbackSize,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _SeasonalTileSpec {
  const _SeasonalTileSpec({
    required this.product,
    required this.title,
    required this.gradient,
  });

  final ProductEntity product;
  final String title;
  final List<Color> gradient;
}

class _MiniAssetTileSpec {
  const _MiniAssetTileSpec({
    required this.product,
    required this.assetPath,
    required this.imageUrl,
    required this.title,
    required this.gradient,
  });

  final ProductEntity product;
  final String assetPath;
  final String? imageUrl;
  final String title;
  final List<Color> gradient;
}

List<ProductEntity> _buildHeroProducts(List<ProductEntity> products) {
  final renderable = products
      .where((product) => _firstRenderableImage(product) != null)
      .toList(growable: false);
  final source = renderable.isNotEmpty ? renderable : products;
  if (source.isEmpty) {
    return const <ProductEntity>[];
  }

  final exactRealMango = source.where((product) {
    final name = product.name.toLowerCase();
    return name.contains('real mango juice');
  }).toList(growable: false);
  if (exactRealMango.isNotEmpty) {
    return <ProductEntity>[exactRealMango.first];
  }

  final ranked = source.toList(growable: false)
    ..sort(
      (left, right) =>
          _heroProductScore(right).compareTo(_heroProductScore(left)),
    );
  final lead = ranked.first;

  return <ProductEntity>[lead];
}

List<_SeasonalTileSpec> _buildTiles(
  List<ProductEntity> products,
  SeasonalMosaicTheme? mosaicTheme,
) {
  final defaultMosaicTheme = SeasonalMosaicTheme.defaults();
  final heroTileTheme = mosaicTheme?.heroTile ?? defaultMosaicTheme.heroTile;
  final renderable = products
      .where((product) => _firstRenderableImage(product) != null)
      .toList(growable: false);
  final source = renderable.isNotEmpty ? renderable : products;
  if (source.isEmpty) {
    return const <_SeasonalTileSpec>[];
  }

  final selected = List<ProductEntity>.generate(
    5,
    (index) => source[index % source.length],
    growable: false,
  );

  return <_SeasonalTileSpec>[
    _SeasonalTileSpec(
      product: selected[0],
      title: heroTileTheme.title,
      gradient: heroTileTheme.gradient,
    ),
  ];
}

List<_MiniAssetTileSpec> _buildMiniAssetTiles(
  List<ProductEntity> products,
  SeasonalMosaicTheme? mosaicTheme,
) {
  final defaultMosaicTheme = SeasonalMosaicTheme.defaults();
  final renderable = products
      .where((product) => _firstRenderableImage(product) != null)
      .toList(growable: false);
  final source = renderable.isNotEmpty ? renderable : products;
  if (source.isEmpty) {
    return const <_MiniAssetTileSpec>[];
  }

  final usedIds = <String>{};

  return <_MiniAssetTileSpec>[
    _MiniAssetTileSpec(
      product: _pickMiniTileProduct(
        source,
        usedIds,
        const <List<String>>[
          <String>['coca-cola', 'cola', 'soft drink'],
          <String>['real mango juice', 'mango juice', 'juice'],
          <String>['amul vanilla magic', 'ice cream', 'vanilla magic'],
        ],
      ),
      assetPath: 'assets/images/1ST_MINIBOX.png',
      imageUrl: _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 0)?.imageUrl,
      title: _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 0)?.title ??
          defaultMosaicTheme.miniTiles[0].title,
      gradient:
          _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 0)?.gradient ??
              defaultMosaicTheme.miniTiles[0].gradient,
    ),
    _MiniAssetTileSpec(
      product: _pickMiniTileProduct(
        source,
        usedIds,
        const <List<String>>[
          <String>['amul vanilla magic', 'ice cream', 'vanilla magic'],
          <String>['amul', 'frozen'],
        ],
      ),
      assetPath: 'assets/images/2ND_MINIBOX.png',
      imageUrl: _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 1)?.imageUrl,
      title: _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 1)?.title ??
          defaultMosaicTheme.miniTiles[1].title,
      gradient:
          _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 1)?.gradient ??
              defaultMosaicTheme.miniTiles[1].gradient,
    ),
    _MiniAssetTileSpec(
      product: _pickMiniTileProduct(
        source,
        usedIds,
        const <List<String>>[
          <String>['lays classic', 'lays', 'chips', 'salted'],
          <String>['real mango juice', 'mango juice', 'juice'],
        ],
      ),
      assetPath: 'assets/images/3RD_MINIBOX.png',
      imageUrl: _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 2)?.imageUrl,
      title: _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 2)?.title ??
          defaultMosaicTheme.miniTiles[2].title,
      gradient:
          _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 2)?.gradient ??
              defaultMosaicTheme.miniTiles[2].gradient,
    ),
    _MiniAssetTileSpec(
      product: _pickMiniTileProduct(
        source,
        usedIds,
        const <List<String>>[
          <String>['milky mist paneer', 'paneer'],
          <String>['amul taaza', 'taaza milk', 'milk'],
          <String>['egg', 'eggs'],
        ],
      ),
      assetPath: 'assets/images/4TH_MINIBOX.png',
      imageUrl: _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 3)?.imageUrl,
      title: _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 3)?.title ??
          defaultMosaicTheme.miniTiles[3].title,
      gradient:
          _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, 3)?.gradient ??
              defaultMosaicTheme.miniTiles[3].gradient,
    ),
  ];
}

MiniTileTheme? _miniTileThemeAt(
  SeasonalMosaicTheme? mosaicTheme,
  SeasonalMosaicTheme defaultMosaicTheme,
  int index,
) {
  final themedTiles = mosaicTheme?.miniTiles;
  if (themedTiles != null && themedTiles.length > index) {
    return themedTiles[index];
  }
  if (defaultMosaicTheme.miniTiles.length > index) {
    return defaultMosaicTheme.miniTiles[index];
  }
  return null;
}

ProductEntity _pickMiniTileProduct(
  List<ProductEntity> source,
  Set<String> usedIds,
  List<List<String>> keywordGroups,
) {
  for (final group in keywordGroups) {
    for (final product in source) {
      if (usedIds.contains(product.id)) {
        continue;
      }
      if (_matchesKeywordGroup(product, group)) {
        usedIds.add(product.id);
        return product;
      }
    }
  }

  for (final group in keywordGroups) {
    for (final product in source) {
      if (_matchesKeywordGroup(product, group)) {
        return product;
      }
    }
  }

  for (final product in source) {
    if (!usedIds.contains(product.id)) {
      usedIds.add(product.id);
      return product;
    }
  }

  return source.first;
}

bool _matchesKeywordGroup(ProductEntity product, List<String> keywords) {
  final haystack = <String?>[
    product.name,
    product.categoryName,
    product.description,
    if (product.tags.isNotEmpty) product.tags.join(' '),
  ].whereType<String>().join(' ').toLowerCase();

  return keywords.any(haystack.contains);
}

int _heroProductScore(ProductEntity product) {
  final haystack = <String?>[
    product.name,
    product.categoryName,
    if (product.tags.isNotEmpty) product.tags.join(' '),
  ].whereType<String>().join(' ').toLowerCase();

  const primaryKeywords = <String, int>{
    'nescafe': 18,
    'coffee': 14,
    'latte': 12,
    'chocolate': 11,
    'amul': 10,
    'milk': 8,
    'tea': 7,
    'butter': 6,
  };
  const secondaryKeywords = <String, int>{
    'biscuit': 4,
    'ice': 4,
    'snack': 3,
    'juice': 3,
    'mango': 3,
  };
  const avoidKeywords = <String>[
    'baby',
    'pampers',
    'diaper',
    'cerelac',
    'stage',
    'care',
    'beverage',
    'cola',
    'water',
    'tonic',
    'apple',
    'banana',
    'potato',
    'tomato',
    'spinach',
    'onion',
    'vegetable',
    'atta',
    'dal',
    'rice',
  ];

  var score = 0;
  primaryKeywords.forEach((keyword, weight) {
    if (haystack.contains(keyword)) {
      score += weight;
    }
  });
  secondaryKeywords.forEach((keyword, weight) {
    if (haystack.contains(keyword)) {
      score += weight;
    }
  });
  for (final keyword in avoidKeywords) {
    if (haystack.contains(keyword)) {
      score -= 6;
    }
  }

  if (product.isFeatured) {
    score += 2;
  }
  if (product.isOnSale) {
    score += 3;
  }
  if (product.thumbnailUrl != null && product.thumbnailUrl!.isNotEmpty) {
    score += 2;
  }

  return score;
}

String? _firstRenderableImage(ProductEntity product) {
  final candidates = <String?>[
    product.thumbnailUrl,
    ...product.images,
  ];

  for (final candidate in candidates) {
    final value = ApiConstants.resolveMediaUrl(candidate)?.trim();
    if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }

  return null;
}
