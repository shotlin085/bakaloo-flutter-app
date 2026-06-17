import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/location_prompt_provider.dart';

/// Shows the one-time location permission bottom sheet.
/// Call this from the home screen after the first frame.
Future<void> showLocationPromptSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => const _LocationPromptSheet(),
  );
}

class _LocationPromptSheet extends ConsumerStatefulWidget {
  const _LocationPromptSheet();

  @override
  ConsumerState<_LocationPromptSheet> createState() =>
      _LocationPromptSheetState();
}

class _LocationPromptSheetState extends ConsumerState<_LocationPromptSheet>
    with SingleTickerProviderStateMixin {
  _SheetState _state = _SheetState.idle;
  String? _statusMessage;

  late final AnimationController _pinController;
  late final Animation<double> _pinBounce;

  @override
  void initState() {
    super.initState();
    _pinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pinBounce = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _pinController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _onEnable() async {
    if (_state == _SheetState.loading) return;
    setState(() {
      _state = _SheetState.loading;
      _statusMessage = 'Detecting your location…';
    });

    final result = await detectAndSaveCurrentLocation(ref);

    if (!mounted) return;

    switch (result) {
      case LocationAutoDetectResult.success:
        setState(() {
          _state = _SheetState.success;
          _statusMessage = 'Location saved as your default address!';
        });
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.of(context).pop();

      case LocationAutoDetectResult.permissionDenied:
        setState(() {
          _state = _SheetState.idle;
          _statusMessage = 'Permission denied. You can enable it later.';
        });

      case LocationAutoDetectResult.permissionPermanentlyDenied:
        setState(() {
          _state = _SheetState.idle;
          _statusMessage =
              'Location permission is blocked. Enable it in Settings.';
        });

      case LocationAutoDetectResult.locationServiceDisabled:
        setState(() {
          _state = _SheetState.idle;
          _statusMessage = 'Please turn on device location and try again.';
        });

      case LocationAutoDetectResult.geocodingFailed:
      case LocationAutoDetectResult.saveFailed:
      case LocationAutoDetectResult.unknown:
        setState(() {
          _state = _SheetState.idle;
          _statusMessage = 'Could not detect location. Try again later.';
        });
    }
  }

  void _onDismiss() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Handle bar
            Padding(
              padding: EdgeInsets.only(top: 10.h, bottom: 4.h),
              child: Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 28.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Animated pin icon
                  _buildPinAnimation(),
                  Gap(20.h),

                  // Title
                  Text(
                    'Enable location for faster delivery',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  Gap(8.h),

                  // Subtitle
                  Text(
                    'We\'ll auto-detect your address so you can start\nshopping without typing a thing.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  Gap(24.h),

                  // Status message
                  if (_statusMessage != null) ...<Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: _state == _SheetState.success
                            ? AppColors.primaryGreen.withValues(alpha: 0.1)
                            : const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            _state == _SheetState.success
                                ? Icons.check_circle_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 16.sp,
                            color: _state == _SheetState.success
                                ? AppColors.primaryGreen
                                : const Color(0xFF856404),
                          ),
                          Gap(8.w),
                          Flexible(
                            child: Text(
                              _statusMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w500,
                                color: _state == _SheetState.success
                                    ? AppColors.primaryGreen
                                    : const Color(0xFF856404),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap(14.h),
                  ],

                  // Enable button
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: FilledButton(
                      onPressed:
                          _state == _SheetState.loading ? null : _onEnable,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        disabledBackgroundColor:
                            AppColors.primaryGreen.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: _state == _SheetState.loading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                                Gap(10.w),
                                Text(
                                  'Detecting…',
                                  style: AppTextStyles.buttonMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                PhosphorIcon(
                                  PhosphorIcons.navigationArrow(
                                    PhosphorIconsStyle.fill,
                                  ),
                                  size: 18.sp,
                                  color: Colors.white,
                                ),
                                Gap(8.w),
                                Text(
                                  'Use My Current Location',
                                  style: AppTextStyles.buttonMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  Gap(10.h),

                  // Not now button
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: TextButton(
                      onPressed: _onDismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'Not now',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinAnimation() {
    return SizedBox(
      height: 80.h,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Shadow ellipse below pin
          Positioned(
            bottom: 4.h,
            child: AnimatedBuilder(
              animation: _pinBounce,
              builder: (_, __) {
                final scale =
                    1.0 - ((_pinBounce.value.abs() / 10) * 0.3);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 32.w,
                    height: 8.h,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                );
              },
            ),
          ),
          // Pin icon
          AnimatedBuilder(
            animation: _pinBounce,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _pinBounce.value),
              child: child,
            ),
            child: Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                  size: 34.sp,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SheetState { idle, loading, success }
