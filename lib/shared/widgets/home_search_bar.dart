import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';

const List<String> _searchHints = <String>[
  'atta, dal, cold drinks',
  'Amul butter',
  'fresh vegetables',
  'snacks',
  'dishwash liquid',
  'Safai Abhiyaan products',
];
const String _promoBasketAsset = 'assets/images/search_bannder.png';
const String _searchIconAsset = 'assets/icon/bakaloo-search-icon.png';
const String _scanIconAsset = 'assets/icon/bakaloo-scan-icon.png';

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

  static const Color _purple = Color(0xFF6B3FA0);
  static const Color _borderColor = Color(0xFFEAE7F0);
  static const Color _hintColor = Color(0xFF6B6770);

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
    final BorderRadius borderRadius = BorderRadius.circular(12.r);
    final hintLabel = Align(
      alignment: Alignment.centerLeft,
      key: ValueKey<int>(_hintIndex),
      child: Text(
        "Search '${searchHints[_hintIndex]}'",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15.sp,
          color: _hintColor,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
    );

    // Full-width search bar — Everyday Essentials promo box removed.
    return Padding(
      padding: widget.outerPadding ?? EdgeInsets.fromLTRB(12.w, 7.h, 12.w, 0),
      child: SizedBox(
        height: 50.h,
        child: GestureDetector(
          onTap: widget.onSearchTap,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: borderRadius,
              border: Border.all(color: _borderColor),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF2A1A47).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Row(
              children: <Widget>[
                Image.asset(
                  _searchIconAsset,
                  width: 28.w,
                  height: 28.w,
                  cacheWidth: 224,
                  cacheHeight: 224,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                Gap(10.w),
                // Thin purple divider.
                Container(
                  width: 1.5,
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                Gap(10.w),
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
                Gap(8.w),
                // Scan icon.
                Image.asset(
                  _scanIconAsset,
                  width: 34.w,
                  height: 34.w,
                  cacheWidth: 272,
                  cacheHeight: 272,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoBox extends StatelessWidget {
  const _PromoBox();

  static const Color _textColor = Color(0xFF141217);
  static const Color _chevronColor = Color(0xFF6B6770);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(7.w, 6.h, 6.w, 6.h),
      child: Row(
        children: <Widget>[
          const _PromoBasketImage(),
          Gap(5.w),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Everyday\nEssentials',
                maxLines: 2,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  height: 1.12,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
            ),
          ),
          Gap(2.w),
          Icon(
            Icons.chevron_right_rounded,
            size: 16.sp,
            color: _chevronColor,
          ),
        ],
      ),
    );
  }
}

class _PromoBasketImage extends StatelessWidget {
  const _PromoBasketImage();

  @override
  Widget build(BuildContext context) {
    final double size = 38.w;
    return Image.asset(
      _promoBasketAsset,
      width: size,
      height: size,
      cacheWidth: 304,
      cacheHeight: 304,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
