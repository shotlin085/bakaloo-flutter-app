import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class ProfileHeader extends ConsumerStatefulWidget {
  const ProfileHeader({
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.onAccountTap,
    super.key,
  });

  final String? name;
  final String phone;
  final String? avatarUrl;
  final VoidCallback? onAccountTap;

  @override
  ConsumerState<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<ProfileHeader> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.orderVioletSurface,
            AppColors.bgPrimary,
          ],
        ),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 36.h,
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      context.pop();
                      return;
                    }
                    context.go(RouteNames.home);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: PhosphorIcon(
                    PhosphorIcons.caretLeft(),
                    size: 22.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Gap(10.h),
          GestureDetector(
            onTap: _pickAndUploadAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
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
                  child: _isUploadingAvatar
                      ? Center(
                          child: SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.orderViolet,
                            ),
                          ),
                        )
                      : _AvatarImage(
                          avatarUrl: widget.avatarUrl,
                          name: widget.name,
                        ),
                ),
                Positioned(
                  right: -2.w,
                  bottom: -2.h,
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Container(
                      height: 26.r,
                      width: 26.r,
                      decoration: BoxDecoration(
                        color: AppColors.orderViolet,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIcons.camera(PhosphorIconsStyle.fill),
                          size: 12.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Gap(12.h),
          Column(
            children: <Widget>[
              Text(
                'Good morning, $_displayName! 👋',
                style: AppTextStyles.h2.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              Gap(4.h),
              Text(
                widget.phone,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              Gap(10.h),
              _EditProfileButton(onTap: widget.onAccountTap),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) {
      return;
    }

    final source = await _pickImageSource();
    if (source == null) {
      return;
    }

    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 92,
    );

    if (pickedFile == null) {
      return;
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 90,
      uiSettings: <PlatformUiSettings>[
        AndroidUiSettings(
          toolbarTitle: 'Crop Avatar',
          lockAspectRatio: true,
          hideBottomControls: true,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'Crop Avatar',
          aspectRatioLockEnabled: true,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    if (cropped == null) {
      return;
    }

    final compressed = await FlutterImageCompress.compressAndGetFile(
      cropped.path,
      '${cropped.path}_compressed.jpg',
      quality: 85,
      minWidth: 1080,
      minHeight: 1080,
      format: CompressFormat.jpeg,
    );

    final fileForUpload = File(compressed?.path ?? cropped.path);

    setState(() => _isUploadingAvatar = true);
    final result =
        await ref.read(profileProvider.notifier).uploadAvatar(fileForUpload);
    if (!mounted) {
      return;
    }
    setState(() => _isUploadingAvatar = false);

    if (!result.isSuccess && result.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar updated successfully.')),
    );
  }

  String get _displayName {
    final trimmed = widget.name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'there';
    }
    return trimmed;
  }

  Future<ImageSource?> _pickImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.bgCard,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: PhosphorIcon(
                    PhosphorIcons.camera(),
                    color: AppColors.textPrimary,
                    size: 20.sp,
                  ),
                  title: Text('Camera', style: AppTextStyles.bodyLarge),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: PhosphorIcon(
                    PhosphorIcons.images(),
                    color: AppColors.textPrimary,
                    size: 20.sp,
                  ),
                  title: Text('Gallery', style: AppTextStyles.bodyLarge),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
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
                PhosphorIcons.pencilSimple(),
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
