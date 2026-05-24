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
            Color(0xFFFFF4D7),
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
                  height: 72.r,
                  width: 72.r,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.bgCard,
                  ),
                  child: _isUploadingAvatar
                      ? Center(
                          child: SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        )
                      : _AvatarImage(avatarUrl: widget.avatarUrl),
                ),
                Positioned(
                  right: -2.w,
                  bottom: -2.h,
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Container(
                      height: 24.r,
                      width: 24.r,
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIcons.camera(),
                          size: 14.sp,
                          color: AppColors.textPrimary,
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
                  fontWeight: FontWeight.w600,
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
              Gap(4.h),
              TextButton(
                onPressed: widget.onAccountTap,
                child: Text(
                  'Edit profile',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
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

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({
    required this.avatarUrl,
  });

  final String? avatarUrl;

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
        color: AppColors.bgInput,
      ),
      errorWidget: (context, url, error) => _fallback(),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: AppColors.primaryGreenLight,
      child: Center(
        child: PhosphorIcon(
          PhosphorIcons.user(PhosphorIconsStyle.fill),
          size: 28.sp,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }
}
