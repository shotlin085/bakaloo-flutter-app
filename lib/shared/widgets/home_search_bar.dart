import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';

const List<String> _searchHints = <String>[
  'Safai Abhiyaan products',
  'Amul butter',
  'cold drinks',
  'fresh vegetables',
  'dishwash liquid',
  'snacks',
];
const String _promoBoxAsset = 'assets/images/everyday_essentials.png';

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({
    required this.onSearchTap,
    this.animateHints = true,
    this.searchTheme,
    this.outerPadding,
    super.key,
  });

  final VoidCallback onSearchTap;
  final bool animateHints;
  final SearchZoneTheme? searchTheme;
  final EdgeInsetsGeometry? outerPadding;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  int _hintIndex = 0;
  Timer? _hintTimer;

  List<String> get _resolvedSearchHints {
    final themeHints = widget.searchTheme?.searchHints;
    if (themeHints != null && themeHints.isNotEmpty) {
      return themeHints;
    }
    return _searchHints;
  }

  @override
  void initState() {
    super.initState();
    _syncHintRotation();
  }

  @override
  void didUpdateWidget(covariant HomeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateHints != widget.animateHints ||
        !listEquals(
          oldWidget.searchTheme?.searchHints,
          widget.searchTheme?.searchHints,
        )) {
      _syncHintRotation();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _syncHintRotation() {
    _hintTimer?.cancel();
    final searchHints = _resolvedSearchHints;
    if (_hintIndex >= searchHints.length) {
      _hintIndex = 0;
    }
    if (!widget.animateHints) {
      _hintTimer = null;
      return;
    }
    if (searchHints.length <= 1) {
      return;
    }

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) {
        return;
      }
      final hints = _resolvedSearchHints;
      if (hints.isEmpty) {
        return;
      }
      setState(() {
        _hintIndex = (_hintIndex + 1) % hints.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchHints = _resolvedSearchHints;
    final BorderRadius borderRadius = BorderRadius.circular(16.r);
    final BorderRadius rightBoxBorderRadius = BorderRadius.only(
      topLeft: Radius.circular(16.r),
      bottomLeft: Radius.circular(16.r),
    );
    final hintLabel = Align(
      alignment: Alignment.centerLeft,
      key: ValueKey<int>(_hintIndex),
      child: Text(
        'Search for "${searchHints[_hintIndex]}"',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15.sp,
          color: const Color(0xFF2F2F2F),
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
    );

    return Padding(
      padding: widget.outerPadding ?? EdgeInsets.fromLTRB(12.w, 7.h, 0, 0),
      child: SizedBox(
        height: 56.h,
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 7,
              child: GestureDetector(
                onTap: widget.onSearchTap,
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: const Color(0xFFD8D8D8),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF222222),
                        size: 24,
                      ),
                      Gap(14.w),
                      Expanded(
                        child: widget.animateHints
                            ? AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                                layoutBuilder: (
                                  Widget? currentChild,
                                  List<Widget> previousChildren,
                                ) {
                                  return SizedBox.expand(
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: <Widget>[
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    ),
                                  );
                                },
                                child: hintLabel,
                              )
                            : hintLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Gap(8.w),
            Expanded(
              flex: 3,
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: rightBoxBorderRadius,
                  border: Border.all(
                    color: const Color(0xFFD8D8D8),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: rightBoxBorderRadius,
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
                    child: _PromoBoxImage(
                      imageUrl: widget.searchTheme?.promoBoxImageUrl,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBoxImage extends StatelessWidget {
  const _PromoBoxImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => const SizedBox.expand(),
        errorWidget: (_, __, ___) => Image.asset(
          _promoBoxAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
        ),
      );
    }

    return Image.asset(
      _promoBoxAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
    );
  }
}
