import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';

import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({
    required this.addressText,
    required this.onAddressTap,
    required this.onProfileTap,
    this.topBarTheme,
    super.key,
  });

  final String addressText;
  final VoidCallback onAddressTap;
  final VoidCallback onProfileTap;
  final TopBarTheme? topBarTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultTopBarTheme = TopBarTheme.defaults();
    final primaryTextColor =
        topBarTheme?.textColor ?? defaultTopBarTheme.textColor;
    final secondaryTextColor = Color.lerp(
          primaryTextColor,
          Colors.white,
          0.13,
        ) ??
        primaryTextColor;
    final mutedIconColor = Color.lerp(
          primaryTextColor,
          Colors.white,
          0.28,
        ) ??
        primaryTextColor;
    final store = ref.watch(selectedStoreProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(16.w, topInset + 8.h, 16.w, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SvgPicture.asset(
                      'assets/icon/thunder.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        primaryTextColor,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      store.subtitle,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                Gap(0.h),
                GestureDetector(
                  onTap: onAddressTap,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxTextWidth = constraints.maxWidth > 24.w
                          ? constraints.maxWidth - 24.w
                          : constraints.maxWidth;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxTextWidth),
                            child: Text(
                              addressText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                          Gap(2.w),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: mutedIconColor,
                            size: 18,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Gap(8.w),
          GestureDetector(
            onTap: onProfileTap,
            child: DotLottieLoader.fromAsset(
              'assets/lottie/profile_loop.lottie',
              frameBuilder: (BuildContext ctx, DotLottie? dotlottie) {
                if (dotlottie != null) {
                  final shouldAnimate = TickerMode.valuesOf(ctx).enabled;
                  return Lottie.memory(
                    dotlottie.animations.values.single,
                    repeat: shouldAnimate,
                    animate: shouldAnimate,
                    width: 52.w,
                    height: 52.w,
                    frameRate: FrameRate.composition,
                    renderCache: RenderCache.raster,
                    backgroundLoading: true,
                    addRepaintBoundary: true,
                    filterQuality: FilterQuality.low,
                  );
                }
                return Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: mutedIconColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 28,
                    color: primaryTextColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
