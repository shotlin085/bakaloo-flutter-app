import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/maps/ola/ola_maps_service.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/resilient_location.dart';

/// Standalone test screen for the Ola Maps module — kept separate from
/// [AddressMapPickerScreen] (the OSM/flutter_map picker used at checkout)
/// so accuracy can be visually compared before deciding whether to switch.
/// Not wired into the checkout/address-save flow. The map style URL (with
/// the provider API key already embedded) is fetched from the backend on
/// each open rather than bundled locally — see OlaMapsService — so key
/// rotation never requires an app release.
class OlaMapTestScreen extends ConsumerStatefulWidget {
  const OlaMapTestScreen({super.key});

  @override
  ConsumerState<OlaMapTestScreen> createState() => _OlaMapTestScreenState();
}

class _OlaMapTestScreenState extends ConsumerState<OlaMapTestScreen> {
  static const GeoPoint _fallbackPoint = GeoPoint(lat: 22.5726, lng: 88.3639);

  MapLibreMapController? _controller;
  GeoPoint _selectedPoint = _fallbackPoint;
  ReverseGeocodeResult? _resolvedLocation;
  OlaMapsStyle? _style;
  bool _isLoadingStyle = true;
  bool _isResolvingLocation = true;
  bool _isLocating = false;
  int _resolveRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadStyle());
    });
  }

  Future<void> _loadStyle() async {
    final style = await ref.read(olaMapsServiceProvider).getStyle();
    if (!mounted) {
      return;
    }
    setState(() {
      _style = style;
      _isLoadingStyle = false;
    });
    if (style.configured && style.styleUrl != null) {
      unawaited(_resolvePointDetails(_selectedPoint));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Ola Maps Test (Beta)', style: AppTextStyles.h2),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingStyle) {
      return const Center(child: CircularProgressIndicator());
    }
    final styleUrl = _style?.styleUrl;
    if (_style?.configured != true || styleUrl == null) {
      return _buildSetupPrompt();
    }
    return _buildMapBody(styleUrl);
  }

  Widget _buildSetupPrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.mapTrifoldLight,
              size: 48.sp,
              color: AppColors.textTertiary,
            ),
            Gap(16.h),
            Text(
              'Ola Maps API key not set',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap(8.h),
            Text(
              'Add OLA_MAPS_API_KEY on the backend, then reopen this screen '
              'to test it against the OSM address picker.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBody(String styleUrl) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _buildMap(styleUrl)),
        const Positioned.fill(
          child: IgnorePointer(
            child: Center(child: _CenterPinOverlay()),
          ),
        ),
        Positioned(
          right: 16.w,
          bottom: 200.h,
          child: _MapFab(
            isLoading: _isLocating,
            onTap: _moveToCurrentLocation,
            child: PhosphorIcon(
              PhosphorIcons.crosshairSimpleBold,
              size: 20.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ResolvedLocationCard(
            isResolving: _isResolvingLocation,
            point: _selectedPoint,
            resolved: _resolvedLocation,
          ),
        ),
      ],
    );
  }

  Widget _buildMap(String styleUrl) {
    return MapLibreMap(
      styleString: styleUrl,
      initialCameraPosition: CameraPosition(
        target: LatLng(_selectedPoint.lat, _selectedPoint.lng),
        zoom: 16,
      ),
      trackCameraPosition: true,
      compassEnabled: false,
      onMapCreated: (MapLibreMapController controller) {
        _controller = controller;
      },
      onCameraIdle: () {
        final target = _controller?.cameraPosition?.target;
        if (target == null) {
          return;
        }
        final nextPoint = GeoPoint(lat: target.latitude, lng: target.longitude);
        if (_samePoint(nextPoint, _selectedPoint)) {
          return;
        }
        setState(() {
          _selectedPoint = nextPoint;
        });
        unawaited(_resolvePointDetails(nextPoint));
      },
    );
  }

  Future<void> _resolvePointDetails(GeoPoint point) async {
    final requestId = ++_resolveRequestId;
    if (mounted) {
      setState(() {
        _isResolvingLocation = true;
      });
    }

    final resolved =
        await ref.read(olaMapsServiceProvider).reverseGeocode(point);
    if (!mounted || requestId != _resolveRequestId) {
      return;
    }

    setState(() {
      _resolvedLocation = resolved;
      _isResolvingLocation = false;
    });
  }

  Future<void> _moveToCurrentLocation() async {
    if (_isLocating) {
      return;
    }
    setState(() {
      _isLocating = true;
    });

    try {
      final position = await getResilientCurrentPosition();
      final currentPoint = GeoPoint(lat: position.latitude, lng: position.longitude);
      if (!mounted) {
        return;
      }

      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(currentPoint.lat, currentPoint.lng),
          17,
        ),
      );

      setState(() {
        _selectedPoint = currentPoint;
      });
      unawaited(_resolvePointDetails(currentPoint));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to fetch current location.')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  bool _samePoint(GeoPoint a, GeoPoint b) {
    return (a.lat - b.lat).abs() < 0.000001 && (a.lng - b.lng).abs() < 0.000001;
  }
}

class _CenterPinOverlay extends StatelessWidget {
  const _CenterPinOverlay();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -21.h),
      child: PhosphorIcon(
        PhosphorIcons.mapPinFill,
        size: 42.sp,
        color: AppColors.cartPink,
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.child,
    required this.onTap,
    required this.isLoading,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        child: Ink(
          width: 40.w,
          height: 40.w,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[AppShadows.actionBtnShadow],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

class _ResolvedLocationCard extends StatelessWidget {
  const _ResolvedLocationCard({
    required this.isResolving,
    required this.point,
    required this.resolved,
  });

  final bool isResolving;
  final GeoPoint point;
  final ReverseGeocodeResult? resolved;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: <BoxShadow>[AppShadows.floatingShadow],
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              Gap(6.h),
              if (isResolving)
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                    Gap(8.w),
                    Text('Resolving address…', style: AppTextStyles.bodyMedium),
                  ],
                )
              else
                Text(
                  resolved?.displayName ?? 'No address found for this point.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
