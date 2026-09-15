import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';

/// Admin-configured banner strip at the very top of the Profile screen —
/// above the avatar/name header, a distinct placement from the home
/// screen's own banners (see profileBannerProvider). Audience (B2C/B2B)
/// and optional customer-segment targeting are both resolved server-side;
/// this widget only renders whatever comes back.
///
/// Renders nothing at all while loading, on error, or when nothing is
/// configured for this account — same convention as B2BModeCard and
/// BirthdayBanner elsewhere on this screen, so a customer with no
/// applicable banner never sees an empty gap or a placeholder.
class ProfileBannerSection extends ConsumerStatefulWidget {
  const ProfileBannerSection({super.key});

  @override
  ConsumerState<ProfileBannerSection> createState() =>
      _ProfileBannerSectionState();
}

class _ProfileBannerSectionState extends ConsumerState<ProfileBannerSection> {
  final PageController _controller = PageController();
  int _page = 0;
  Timer? _autoScrollTimer;
  int _autoScrollBannerCount = 0;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _ensureAutoScroll(int bannerCount) {
    if (bannerCount == _autoScrollBannerCount) return;
    _autoScrollBannerCount = bannerCount;
    _autoScrollTimer?.cancel();
    if (bannerCount <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % bannerCount;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(profileBannerProvider);
    final banners = bannersAsync.asData?.value ?? const <BannerEntity>[];

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    _ensureAutoScroll(banners.length);

    // A fixed slot height (matching the dashboard's declared PROFILE
    // placement guide of a 3:1 wide strip) rather than deriving it from
    // whatever the admin actually uploaded — this is the one screen
    // location, so one consistent height keeps the layout stable even if
    // a mis-sized image is briefly published before being corrected.
    final height = (100.w / 3).h;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: SizedBox(
          height: height,
          child: Stack(
            children: <Widget>[
              PageView.builder(
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  return _ProfileBannerTile(banner: banner);
                },
              ),
              if (banners.length > 1)
                Positioned(
                  bottom: 8.h,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(
                      banners.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.symmetric(horizontal: 2.w),
                        width: index == _page ? 14.w : 5.w,
                        height: 5.w,
                        decoration: BoxDecoration(
                          color: index == _page
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
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

class _ProfileBannerTile extends StatelessWidget {
  const _ProfileBannerTile({required this.banner});

  final BannerEntity banner;

  /// Mirrors section_registry.dart's private _resolveBannerTarget — a
  /// second small copy rather than exporting a private helper from the
  /// home module, so this widget stays independent of the home
  /// section-builder the way a genuinely reusable placement should be.
  String? _resolveTarget() {
    final rawValue = banner.linkValue?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    switch (banner.linkType.trim().toLowerCase()) {
      case 'product':
        return '/product/$rawValue';
      case 'category':
        return '/categories/$rawValue/products';
      default:
        return rawValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _resolveTarget();
    return GestureDetector(
      onTap: target == null ? null : () => context.push(target),
      child: CachedNetworkImage(
        imageUrl: banner.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => Container(color: const Color(0xFFF4F4F4)),
        errorWidget: (context, url, error) =>
            const SizedBox.shrink(),
      ),
    );
  }
}
