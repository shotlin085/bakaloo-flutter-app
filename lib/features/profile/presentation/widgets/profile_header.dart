import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// Profile screen header — avatar, name, phone, edit button, over either
/// the default purple gradient or an admin-configured banner image (see
/// profileBannerProvider) as its own background. Falls back to the
/// gradient the instant no image is configured/active — this is a
/// same-widget background swap, not a separate section stacked above the
/// header, so there's exactly one visual block here, not two.
class ProfileHeader extends ConsumerStatefulWidget {
  const ProfileHeader({
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.backgroundImageUrl,
    this.onAccountTap,
    super.key,
  });

  final String? name;
  final String phone;
  final String? avatarUrl;
  /// The resolved profile-placement banner image, or null for the
  /// default purple gradient.
  final String? backgroundImageUrl;
  final VoidCallback? onAccountTap;

  @override
  ConsumerState<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<ProfileHeader> {
  @override
  Widget build(BuildContext context) {
    final String? bgUrl = widget.backgroundImageUrl?.trim();
    final bool hasImage = bgUrl != null && bgUrl.isNotEmpty;
    // Reaching the true top of the screen (behind the status bar) and both
    // side edges is the whole point of a background image/gradient here —
    // only the CONTENT below needs a safe-area-aware top inset so the back
    // button doesn't sit under the clock/battery icons. Reported: the
    // background was confined inside this widget's own content padding,
    // leaving a visible strip of the plain page background around it.
    final double topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: hasImage
              ? ClipRect(
                  child: CachedNetworkImage(
                    imageUrl: bgUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ColoredBox(
                      color: AppColors.orderVioletSurface,
                    ),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: AppColors.orderVioletSurface,
                    ),
                  ),
                )
              : const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppColors.orderVioletSurface,
                        AppColors.bgPrimary,
                      ],
                    ),
                  ),
                ),
        ),
        if (hasImage)
          // Name/phone sit in the lower half — a bottom-weighted scrim
          // keeps them legible against any photo without hiding the
          // image's own top portion.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Color(0x99000000),
                  ],
                  stops: <double>[0.35, 1],
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, topInset + 8.h, 16.w, 18.h),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 36.h,
                child: Row(
                  children: <Widget>[
                    _BackButton(onImage: hasImage),
                  ],
                ),
              ),
              Gap(70.h),
              Container(
                height: 76.r,
                width: 76.r,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orderVioletSurface,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.orderVioletGlow,
                      blurRadius: 14.r,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: _AvatarImage(
                  avatarUrl: widget.avatarUrl,
                  name: widget.name,
                ),
              ),
              Gap(12.h),
              Column(
                children: <Widget>[
                  Text(
                    _displayName,
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: hasImage ? Colors.white : null,
                      shadows: hasImage
                          ? const <Shadow>[
                              Shadow(color: Colors.black38, blurRadius: 6),
                            ]
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Gap(4.h),
                  Text(
                    widget.phone,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 14.sp,
                      color: hasImage
                          ? Colors.white.withValues(alpha: 0.9)
                          : AppColors.textSecondary,
                      shadows: hasImage
                          ? const <Shadow>[
                              Shadow(color: Colors.black38, blurRadius: 6),
                            ]
                          : null,
                    ),
                  ),
                  Gap(10.h),
                  _EditProfileButton(onTap: widget.onAccountTap),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _displayName {
    final trimmed = widget.name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Bakaloo Customer';
    }
    return trimmed;
  }

}

/// A real circular button — a frosted dark disc with a white caret —
/// instead of a bare icon floating with no visible touch target. Reads
/// clearly whether the header behind it is the plain gradient or a photo.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onImage});

  final bool onImage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onImage ? Colors.black.withValues(alpha: 0.32) : Colors.white,
      shape: const CircleBorder(),
      elevation: onImage ? 0 : 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (Navigator.of(context).canPop()) {
            context.pop();
            return;
          }
          context.go(RouteNames.home);
        },
        child: SizedBox(
          width: 34.r,
          height: 34.r,
          child: Center(
            child: PhosphorIcon(
              PhosphorIcons.caretLeft,
              size: 18.sp,
              color: onImage ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(100.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100.r),
            border: Border.all(color: AppColors.orderVioletBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PhosphorIcon(
                PhosphorIcons.pencilSimple,
                size: 14.sp,
                color: AppColors.orderViolet,
              ),
              Gap(6.w),
              Text(
                'Edit profile',
                style: AppTextStyles.buttonSmall.copyWith(
                  color: AppColors.orderViolet,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({
    required this.avatarUrl,
    required this.name,
  });

  final String? avatarUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.trim().isEmpty) {
      return _fallback();
    }

    return CachedNetworkImage(
      imageUrl: avatarUrl!,
      memCacheWidth: 300,
      fit: BoxFit.cover,
      placeholder: (context, url) => const ColoredBox(
        color: AppColors.orderVioletSurface,
      ),
      errorWidget: (context, url, error) => _fallback(),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: AppColors.orderVioletSurface,
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.orderViolet,
          ),
        ),
      ),
    );
  }

  String get _initials {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '🙂';
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}
