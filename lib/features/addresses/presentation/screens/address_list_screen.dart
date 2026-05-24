import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/haversine.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

final _addressListCurrentPositionProvider = FutureProvider<Position?>((
  Ref ref,
) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return await Geolocator.getLastKnownPosition();
    }

    return await Geolocator.getCurrentPosition();
  } catch (_) {
    return null;
  }
});

class AddressListScreen extends ConsumerWidget {
  const AddressListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressAsync = ref.watch(addressProvider);
    final currentPositionAsync = ref.watch(_addressListCurrentPositionProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: PhosphorIcon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
            size: 20.sp,
            color: AppColors.textPrimary,
          ),
        ),
        title: Text('Addresses', style: AppTextStyles.h2),
      ),
      body: addressAsync.when(
        loading: () => const _AddressLoadingState(),
        error: (Object error, StackTrace stackTrace) => _AddressErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: () => _refreshAddresses(ref),
        ),
        data: (List<AddressEntity> addresses) {
          AddressEntity? defaultAddress;
          for (final AddressEntity item in addresses) {
            if (item.isDefault) {
              defaultAddress = item;
              break;
            }
          }
          final currentPosition = currentPositionAsync.asData?.value;

          return RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: () => _refreshAddresses(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
              children: <Widget>[
                _AddNewAddressCard(
                  onTap: () => _openAddAddress(context, ref),
                ),
                Gap(20.h),
                Padding(
                  padding: EdgeInsets.only(left: 2.w, bottom: 10.h),
                  child: Text(
                    'Saved Addresses',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (addresses.isEmpty)
                  const _AddressEmptyState()
                else
                  ...addresses.map(
                    (AddressEntity address) => Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: _SavedAddressCard(
                        address: address,
                        distanceLabel: _buildDistanceLabel(
                          address: address,
                          currentPosition: currentPosition,
                          defaultAddress: defaultAddress,
                        ),
                        onShare: () => _shareAddress(address),
                        onEdit: () => _openEditAddress(context, ref, address),
                        onDelete: () => _deleteAddress(context, ref, address),
                        onSetDefault: address.isDefault
                            ? null
                            : () => _setDefaultAddress(context, ref, address),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshAddresses(WidgetRef ref) async {
    ref.read(addressProvider.notifier).refresh();
    await ref.read(addressProvider.future);
  }

  Future<void> _openAddAddress(BuildContext context, WidgetRef ref) async {
    final bool? changed = await context.push<bool>(RouteNames.addAddress);
    if (!context.mounted || changed != true) {
      return;
    }
    ref.read(addressProvider.notifier).refresh();
  }

  Future<void> _openEditAddress(
    BuildContext context,
    WidgetRef ref,
    AddressEntity address,
  ) async {
    final bool? changed = await context.push<bool>(
      RouteNames.addAddress,
      extra: address,
    );
    if (!context.mounted || changed != true) {
      return;
    }
    ref.read(addressProvider.notifier).refresh();
  }

  Future<void> _deleteAddress(
    BuildContext context,
    WidgetRef ref,
    AddressEntity address,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(addressProvider.notifier)
        .deleteAddress(context, address.id);

    if (!context.mounted || result.cancelled) {
      return;
    }

    if (!result.isSuccess) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.failure?.message ?? 'Unable to delete address.',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Address deleted.')),
      );
  }

  Future<void> _setDefaultAddress(
    BuildContext context,
    WidgetRef ref,
    AddressEntity address,
  ) async {
    final result = await ref.read(addressProvider.notifier).setDefault(
          address.id,
        );
    if (!context.mounted || result.isSuccess) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.failure?.message ?? 'Unable to update address.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
  }

  void _shareAddress(AddressEntity address) {
    Share.share(_shareText(address));
  }
}

class _AddNewAddressCard extends StatelessWidget {
  const _AddNewAddressCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: const <BoxShadow>[AppShadows.cardShadow],
            border: Border.all(color: const Color(0xFFE8F1EA)),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF8F0),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusLg.r),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 18.h),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreenLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 22.sp,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    Gap(14.w),
                    Expanded(
                      child: Text(
                        'Add New Address',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryGreen,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22.sp,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  const _SavedAddressCard({
    required this.address,
    required this.distanceLabel,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
    this.onSetDefault,
  });

  final AddressEntity address;
  final String? distanceLabel;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    final label = address.label.trim().isEmpty ? 'Other' : address.label.trim();

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38.w,
            height: 38.w,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F5),
              shape: BoxShape.circle,
            ),
            child: PhosphorIcon(
              PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
              size: 18.sp,
              color: AppColors.textSecondary,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: <Widget>[
                    Text(
                      label,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontFamily: 'Poppins',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((distanceLabel ?? '').isNotEmpty) ...<Widget>[
                      Text(
                        '•',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        distanceLabel!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                    if (address.isDefault)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primaryGreen),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          'Selected',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                Gap(8.h),
                Text(
                  _fullAddress(address),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
          Gap(10.w),
          Column(
            children: <Widget>[
              _CardIconButton(
                icon: PhosphorIcons.shareNetwork(),
                onTap: onShare,
              ),
              Gap(4.h),
              PopupMenuButton<_AddressCardMenuAction>(
                tooltip: 'More actions',
                color: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                onSelected: (_AddressCardMenuAction value) {
                  switch (value) {
                    case _AddressCardMenuAction.edit:
                      onEdit();
                      break;
                    case _AddressCardMenuAction.delete:
                      onDelete();
                      break;
                    case _AddressCardMenuAction.setDefault:
                      onSetDefault?.call();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) {
                  return <PopupMenuEntry<_AddressCardMenuAction>>[
                    PopupMenuItem<_AddressCardMenuAction>(
                      value: _AddressCardMenuAction.edit,
                      child: Text(
                        'Edit',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    PopupMenuItem<_AddressCardMenuAction>(
                      value: _AddressCardMenuAction.delete,
                      child: Text(
                        'Delete',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.errorRed,
                        ),
                      ),
                    ),
                    if (!address.isDefault)
                      PopupMenuItem<_AddressCardMenuAction>(
                        value: _AddressCardMenuAction.setDefault,
                        child: Text(
                          'Set as Default',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                  ];
                },
                child: const _CardIconButton(
                  icon: null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.icon,
    this.onTap,
  });

  final PhosphorIconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 34.w,
      height: 34.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: icon == null
          ? PhosphorIcon(
              PhosphorIcons.dotsThreeVertical(),
              size: 18.sp,
              color: AppColors.textSecondary,
            )
          : PhosphorIcon(
              icon!,
              size: 18.sp,
              color: AppColors.textSecondary,
            ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: child,
      ),
    );
  }
}

class _AddressLoadingState extends StatefulWidget {
  const _AddressLoadingState();

  @override
  State<_AddressLoadingState> createState() => _AddressLoadingStateState();
}

class _AddressLoadingStateState extends State<_AddressLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
          itemCount: 3,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _ShimmerAddressCard(progress: _controller.value),
            );
          },
        );
      },
    );
  }
}

class _ShimmerAddressCard extends StatelessWidget {
  const _ShimmerAddressCard({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      begin: Alignment(-1.2 + (progress * 2), -0.3),
      end: Alignment(1.2 + (progress * 2), 0.3),
      colors: const <Color>[
        Color(0xFFF2F3F5),
        Color(0xFFE7E9ED),
        Color(0xFFF2F3F5),
      ],
      stops: const <double>[0.1, 0.45, 0.9],
    );

    return Container(
      height: 180.h,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: ShaderMask(
        shaderCallback: (Rect bounds) => gradient.createShader(bounds),
        blendMode: BlendMode.srcATop,
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFECEFF3),
                    shape: BoxShape.circle,
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 150.w,
                        height: 14.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEFF3),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      Gap(12.h),
                      Container(
                        width: double.infinity,
                        height: 12.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEFF3),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      Gap(8.h),
                      Container(
                        width: 210.w,
                        height: 12.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEFF3),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(10.w),
                Column(
                  children: <Widget>[
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEFF3),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    Gap(6.h),
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEFF3),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              height: 44.h,
              decoration: BoxDecoration(
                color: const Color(0xFFECEFF3),
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressEmptyState extends StatelessWidget {
  const _AddressEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 44.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 72.w,
            height: 72.w,
            decoration: const BoxDecoration(
              color: AppColors.primaryGreenLight,
              shape: BoxShape.circle,
            ),
            child: PhosphorIcon(
              PhosphorIcons.mapPinLine(),
              size: 28.sp,
              color: AppColors.primaryGreen,
            ),
          ),
          Gap(16.h),
          Text(
            'No saved addresses yet',
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          Gap(6.h),
          Text(
            'Add your first delivery address',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AddressErrorState extends StatelessWidget {
  const _AddressErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 68.w,
              height: 68.w,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF4F4),
                shape: BoxShape.circle,
              ),
              child: PhosphorIcon(
                PhosphorIcons.warningCircle(),
                size: 28.sp,
                color: AppColors.errorRed,
              ),
            ),
            Gap(16.h),
            Text(
              'Unable to load addresses',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(8.h),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(18.h),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
              child: Text(
                'Retry',
                style: AppTextStyles.buttonMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AddressCardMenuAction {
  edit,
  delete,
  setDefault,
}

String _fullAddress(AddressEntity address) {
  return <String>[
    address.addressLine1,
    if ((address.addressLine2 ?? '').trim().isNotEmpty)
      address.addressLine2!.trim(),
    address.city,
    address.state,
    address.pincode,
  ].join(', ');
}

String _shareText(AddressEntity address) {
  return '${address.label}: ${address.addressLine1}, ${address.city}, '
      '${address.state} ${address.pincode}';
}

String? _buildDistanceLabel({
  required AddressEntity address,
  required Position? currentPosition,
  required AddressEntity? defaultAddress,
}) {
  if (!_hasCoordinates(address)) {
    return null;
  }

  final distanceKm = switch ((currentPosition, defaultAddress)) {
    (final Position position?, _) => Haversine.distanceInKm(
        startLatitude: position.latitude,
        startLongitude: position.longitude,
        endLatitude: address.latitude,
        endLongitude: address.longitude,
      ),
    (_, final AddressEntity reference?) when _hasCoordinates(reference) =>
      Haversine.distanceInKm(
        startLatitude: reference.latitude,
        startLongitude: reference.longitude,
        endLatitude: address.latitude,
        endLongitude: address.longitude,
      ),
    _ => null,
  };

  if (distanceKm == null) {
    return null;
  }

  return '${distanceKm.toStringAsFixed(1)} km';
}

bool _hasCoordinates(AddressEntity address) {
  return address.latitude.isFinite &&
      address.longitude.isFinite &&
      !(address.latitude == 0 && address.longitude == 0);
}
