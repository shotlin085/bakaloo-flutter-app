import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_highlights_overlay.dart';
import 'package:bakaloo_flutter_app/shared/widgets/rating_badge.dart';

class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    required this.images,
    required this.productName,
    required this.price,
    required this.avgRating,
    required this.ratingCount,
    required this.isCollapsed,
    required this.scrollOffset,
    this.thumbnailUrl,
    this.salePrice,
    this.highlights,
    this.onSearch,
    this.onShare,
    this.onBack,
    this.onImageChanged,
    this.onHighlightsToggle,
    super.key,
  });

  final List<String> images;
  final String? thumbnailUrl;
  final String productName;
  final double price;
  final double? salePrice;
  final double avgRating;
  final int ratingCount;
  final Map<String, dynamic>? highlights;
  final bool isCollapsed;
  final VoidCallback? onSearch;
  final VoidCallback? onShare;
  final VoidCallback? onBack;
  final ValueChanged<int>? onImageChanged;
  final VoidCallback? onHighlightsToggle;
  final double scrollOffset;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _showHighlights = false;

  List<String> get _galleryImages {
    final filtered = widget.images.where((image) => image.isNotEmpty).toList();
    if (filtered.isNotEmpty) {
      return filtered;
    }
    if ((widget.thumbnailUrl ?? '').isNotEmpty) {
      return <String>[widget.thumbnailUrl!];
    }
    return const <String>[];
  }

  bool get _isOnSale =>
      widget.salePrice != null &&
      widget.salePrice! > 0 &&
      widget.salePrice! < widget.price;

  double get _displayPrice => _isOnSale ? widget.salePrice! : widget.price;

  String? get _thumbnailImage {
    if ((widget.thumbnailUrl ?? '').isNotEmpty) {
      return widget.thumbnailUrl;
    }
    if (_galleryImages.isNotEmpty) {
      return _galleryImages.first;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleHighlights() {
    final willShow = !_showHighlights;
    setState(() {
      _showHighlights = willShow;
    });
    if (willShow) {
      widget.onHighlightsToggle?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 420.h,
      automaticallyImplyLeading: false,
      backgroundColor:
          widget.isCollapsed ? const Color(0xFFFFFFFF) : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      toolbarHeight: 56.h,
      title: widget.isCollapsed ? _buildCollapsedBar() : null,
      flexibleSpace: widget.isCollapsed
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.06),
                    blurRadius: 4.r,
                  ),
                ],
              ),
            )
          : FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Transform.translate(
                    // Vertical parallax: 0.18x — tuned for subtle depth vs promo's 0.3x horizontal
                    offset: Offset(0, widget.scrollOffset * 0.18),
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount:
                          _galleryImages.isEmpty ? 1 : _galleryImages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                        widget.onImageChanged?.call(index);
                      },
                      itemBuilder: (context, index) {
                        final imageUrl = _galleryImages.isEmpty
                            ? null
                            : _galleryImages[index];
                        return Container(
                          color: const Color(0xFFF2F2F2),
                          child: imageUrl == null
                              ? Center(
                                  child: PhosphorIcon(
                                    PhosphorIcons.image(),
                                    size: 42.sp,
                                    color: const Color(0xFFBBBBBB),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.contain,
                                  memCacheWidth: 520,
                                  memCacheHeight: 520,
                                  fadeInDuration: Duration.zero,
                                  filterQuality: FilterQuality.high,
                                  placeholder: (context, url) =>
                                      const ColoredBox(
                                    color: Color(0xFFF2F2F2),
                                    child: SizedBox.expand(),
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: PhosphorIcon(
                                      PhosphorIcons.imageBroken(),
                                      size: 36.sp,
                                      color: const Color(0xFFBBBBBB),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
                        child: Row(
                          children: <Widget>[
                            _CircleActionButton(
                              icon: PhosphorIcons.caretLeft(
                                PhosphorIconsStyle.bold,
                              ),
                              onTap: widget.onBack,
                            ),
                            const Spacer(),
                            _CircleActionButton(
                              icon: PhosphorIcons.magnifyingGlass(
                                PhosphorIconsStyle.bold,
                              ),
                              onTap: widget.onSearch,
                            ),
                            SizedBox(width: 8.w),
                            _CircleActionButton(
                              icon: PhosphorIcons.shareNetwork(
                                PhosphorIconsStyle.bold,
                              ),
                              onTap: widget.onShare,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16.w,
                    right: 16.w,
                    bottom: 20.h,
                    child: Row(
                      children: <Widget>[
                        if ((widget.highlights ?? const <String, dynamic>{})
                            .isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleHighlights,
                            child: Container(
                              width: 38.w,
                              height: 38.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF333333)
                                    .withValues(alpha: 0.85),
                              ),
                              child: Center(
                                child: PhosphorIcon(
                                  PhosphorIcons.sparkle(),
                                  size: 18.sp,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(width: 38.w, height: 38.w),
                        Expanded(
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List<Widget>.generate(
                                _galleryImages.isEmpty
                                    ? 1
                                    : _galleryImages.length,
                                (index) {
                                  final isActive = index == _currentPage;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    margin:
                                        EdgeInsets.symmetric(horizontal: 3.w),
                                    width: isActive ? 8.w : 6.w,
                                    height: isActive ? 8.w : 6.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white
                                              .withValues(alpha: 0.40),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 38.w),
                        Align(
                          alignment: Alignment.centerRight,
                          child: RatingBadge(
                            rating: widget.avgRating,
                            count: widget.ratingCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ProductHighlightsOverlay(
                    highlights: widget.highlights ?? const <String, dynamic>{},
                    isVisible: _showHighlights,
                    onClose: _toggleHighlights,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCollapsedBar() {
    final thumbnail = _thumbnailImage;

    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      alignment: Alignment.center,
      child: Row(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onBack,
            child: SizedBox(
              width: 36.w,
              height: 36.w,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                  size: 20.sp,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          if (thumbnail != null) ...<Widget>[
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: thumbnail,
                width: 32.w,
                height: 32.w,
                fit: BoxFit.cover,
                memCacheWidth: 96,
                memCacheHeight: 96,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => Container(
                  width: 32.w,
                  height: 32.w,
                  color: const Color(0xFFF2F2F2),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 32.w,
                  height: 32.w,
                  color: const Color(0xFFF2F2F2),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIcons.image(),
                      size: 14.sp,
                      color: const Color(0xFFBBBBBB),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2.h),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '₹${_displayPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                      ),
                      if (_isOnSale) ...<InlineSpan>[
                        WidgetSpan(child: SizedBox(width: 6.w)),
                        TextSpan(
                          text: '₹${widget.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF999999),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFF999999),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSearch,
            child: SizedBox(
              width: 28.w,
              height: 28.w,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
                  size: 18.sp,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onShare,
            child: SizedBox(
              width: 28.w,
              height: 28.w,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.shareNetwork(PhosphorIconsStyle.bold),
                  size: 18.sp,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    this.onTap,
  });

  final PhosphorIconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0x14000000),
              blurRadius: 8.r,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Center(
          child: PhosphorIcon(
            icon,
            size: 20.sp,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}
