import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/location_prompt_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// Shows the one-time location permission bottom sheet.
/// Call this from the home screen after the first frame.
Future<void> showLocationPromptSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    isDismissible: true,
    enableDrag: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => const _LocationPromptSheet(),
  );
}

class _LocationPromptSheet extends ConsumerStatefulWidget {
  const _LocationPromptSheet();

  @override
  ConsumerState<_LocationPromptSheet> createState() =>
      _LocationPromptSheetState();
}

class _LocationPromptSheetState extends ConsumerState<_LocationPromptSheet> {
  _SheetState _state = _SheetState.idle;
  String? _statusMessage;

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
        await Future<void>.delayed(const Duration(milliseconds: 1200));
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

  Future<void> _onAddManually() async {
    final changed = await context.push<bool>(RouteNames.addAddress);
    if (changed == true && mounted) Navigator.of(context).pop();
  }

  void _onSeeAllAddresses() {
    Navigator.of(context).pop();
    context.push(RouteNames.addresses);
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressProvider);
    final AddressEntity? savedAddress = addressesAsync.maybeWhen(
      data: (addresses) => addresses.isEmpty ? null : addresses.first,
      orElse: () => null,
    );

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Handle bar + close button
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E2E2),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: _onDismiss,
                      child: Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: const BoxDecoration(
                          color: AppColors.bgSection,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 36.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 52.w,
                        height: 52.w,
                        decoration: const BoxDecoration(
                          color: AppColors.orderVioletSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIcons.mapPinLine(
                              PhosphorIconsStyle.fill,
                            ),
                            size: 26.sp,
                            color: AppColors.orderViolet,
                          ),
                        ),
                      ),
                      Gap(14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Your location is off',
                              style: AppTextStyles.h2.copyWith(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            Gap(3.h),
                            Text(
                              'Turn it on for faster, more accurate delivery',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 12.5.sp,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Gap(20.h),

                  // Primary action row — use current location
                  _ActionRow(
                    onTap: _state == _SheetState.loading ? null : _onEnable,
                    leading: _state == _SheetState.loading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.orderViolet,
                            ),
                          )
                        : PhosphorIcon(
                            PhosphorIcons.navigationArrow(
                              PhosphorIconsStyle.fill,
                            ),
                            size: 20.sp,
                            color: AppColors.orderViolet,
                          ),
                    title: 'Use my current location',
                    subtitle: 'Auto-detect and save as default address',
                    trailing: _PillButton(
                      label: _state == _SheetState.loading
                          ? 'Detecting…'
                          : 'Enable',
                      onTap: _state == _SheetState.loading ? null : _onEnable,
                    ),
                  ),

                  if (_statusMessage != null) ...<Widget>[
                    Gap(10.h),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      padding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: _state == _SheetState.success
                            ? AppColors.orderVioletSurface
                            : const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            _state == _SheetState.success
                                ? Icons.check_circle_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 16.sp,
                            color: _state == _SheetState.success
                                ? AppColors.orderViolet
                                : const Color(0xFF856404),
                          ),
                          Gap(8.w),
                          Flexible(
                            child: Text(
                              _statusMessage!,
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w500,
                                color: _state == _SheetState.success
                                    ? AppColors.orderVioletDark
                                    : const Color(0xFF856404),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Gap(20.h),
                  Row(
                    children: <Widget>[
                      Text(
                        savedAddress != null
                            ? 'Your saved address'
                            : 'Add an address',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      if (savedAddress != null)
                        GestureDetector(
                          onTap: _onSeeAllAddresses,
                          child: Text(
                            'See all',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.orderViolet,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Gap(10.h),

                  if (savedAddress != null)
                    _ActionRow(
                      onTap: _onSeeAllAddresses,
                      leading: PhosphorIcon(
                        PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                        size: 20.sp,
                        color: AppColors.textSecondary,
                      ),
                      title: savedAddress.label,
                      subtitle: <String?>[
                        savedAddress.addressLine1,
                        savedAddress.city,
                      ].whereType<String>().join(', '),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 20.sp,
                        color: AppColors.textTertiary,
                      ),
                    )
                  else
                    _ActionRow(
                      onTap: _onAddManually,
                      leading: PhosphorIcon(
                        PhosphorIcons.plusCircle(PhosphorIconsStyle.fill),
                        size: 20.sp,
                        color: AppColors.textSecondary,
                      ),
                      title: 'Add address manually',
                      subtitle: 'Search or enter your delivery address',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 20.sp,
                        color: AppColors.textTertiary,
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
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.bgSection.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.orderVioletBorder, width: 1),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(width: 22.w, child: Center(child: leading)),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Gap(8.w),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.orderViolet
              : AppColors.orderViolet.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonMedium.copyWith(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

enum _SheetState { idle, loading, success }
