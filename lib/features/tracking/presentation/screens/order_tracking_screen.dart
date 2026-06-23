import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as map;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/maps/maps_service.dart';
import 'package:bakaloo_flutter_app/core/maps/route_model.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/tracking/presentation/providers/rider_location_provider.dart';
import 'package:bakaloo_flutter_app/features/tracking/presentation/providers/tracking_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({
    required this.id,
    super.key,
  });

  final String id;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final MapController _mapController = MapController();
  final MapsService _mapsService = MapsService();

  GeoPoint? _riderPosition;
  GeoPoint? _destination;
  RouteModel? _route;
  String? _mapMessage;
  bool _isLoadingRoute = false;
  bool _mapReady = false;
  bool _userMovedMap = false;
  String? _boundFingerprint;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(startTrackingUseCaseProvider).call(widget.id);
    });
  }

  @override
  void dispose() {
    ref.read(stopTrackingUseCaseProvider).call(widget.id);
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.id));

    ref.listen(riderLocationEntityForOrderProvider(widget.id),
        (previous, next) {
      next.whenData((event) {
        final nextPoint = GeoPoint(lat: event.latitude, lng: event.longitude);
        if (_riderPosition == nextPoint) {
          return;
        }
        setState(() {
          _riderPosition = nextPoint;
        });
        unawaited(_refreshRoute(fitCamera: !_userMovedMap));
      });
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: orderAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          ),
          error: (error, _) => _TrackingErrorState(
            message: error.toString().replaceFirst('Bad state: ', ''),
            onRetry: () => ref.invalidate(orderDetailProvider(widget.id)),
          ),
          data: (order) {
            _bindOrder(order);

            final destination = _destination;
            final rider = _riderPosition;
            final orderTimeline = order.timeline.isEmpty
                ? const <OrderTimelineEntity>[]
                : order.timeline;
            final latestEvent =
                orderTimeline.isEmpty ? null : orderTimeline.last;

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double sheetMinChildSize = 0.28;
                const double sheetInitialChildSize = 0.34;
                const double sheetMaxChildSize = 0.74;
                final controlsBottomInset =
                    (constraints.maxHeight * sheetMinChildSize) + 20.h;

                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: destination == null
                          ? _MapUnavailableState(
                              message: _mapMessage ??
                                  'Unable to resolve the delivery location right now.',
                              onRetry: () => ref
                                  .invalidate(orderDetailProvider(widget.id)),
                            )
                          : FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter:
                                    _toMapPoint(rider ?? destination),
                                initialZoom: 14,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all &
                                      ~InteractiveFlag.rotate,
                                ),
                                onMapReady: () {
                                  _mapReady = true;
                                  _fitToVisiblePoints();
                                },
                                onPositionChanged:
                                    (MapCamera camera, bool hasGesture) {
                                  if (hasGesture && mounted && !_userMovedMap) {
                                    setState(() {
                                      _userMovedMap = true;
                                    });
                                  }
                                },
                              ),
                              children: <Widget>[
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.bakaloo.customer',
                                  maxNativeZoom: 19,
                                  maxZoom: 19,
                                ),
                                if (_route != null && _route!.points.isNotEmpty)
                                  PolylineLayer(
                                    polylines: <Polyline>[
                                      Polyline(
                                        points: _route!.points
                                            .map(_toMapPoint)
                                            .toList(growable: false),
                                        strokeWidth: 10,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                      Polyline(
                                        points: _route!.points
                                            .map(_toMapPoint)
                                            .toList(growable: false),
                                        strokeWidth: 6,
                                        color: AppColors.infoBlue,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: _buildMarkers(
                                    rider: rider,
                                    destination: destination,
                                  ),
                                ),
                                const RichAttributionWidget(
                                  attributions: <SourceAttribution>[
                                    TextSourceAttribution(
                                      'OpenStreetMap contributors',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Colors.black.withValues(alpha: 0.10),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.18),
                              ],
                              stops: const <double>[0, 0.3, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        children: <Widget>[
                          _TrackingTopBar(onBack: _handleBack),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: _TrackingStatusCard(
                              order: order,
                              latestEvent: latestEvent,
                              etaLabel: _etaLabel,
                              distanceLabel: _distanceLabel,
                              hasRiderLocation: rider != null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16.w,
                      bottom: controlsBottomInset,
                      child: _MapControls(
                        showRecenter: _userMovedMap,
                        onZoomIn: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        ),
                        onZoomOut: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        ),
                        onRecenter: () {
                          setState(() {
                            _userMovedMap = false;
                          });
                          _fitToVisiblePoints();
                        },
                      ),
                    ),
                    DraggableScrollableSheet(
                      minChildSize: sheetMinChildSize,
                      initialChildSize: sheetInitialChildSize,
                      maxChildSize: sheetMaxChildSize,
                      builder: (
                        BuildContext context,
                        ScrollController scrollController,
                      ) {
                        return _TrackingBottomSheet(
                          scrollController: scrollController,
                          order: order,
                          riderName: _readString(
                            _readMap(order.tracking, 'rider'),
                            'name',
                            fallback: 'Assigning rider',
                          ),
                          riderPhone: _readString(
                            _readMap(order.tracking, 'rider'),
                            'phone',
                          ),
                          latestEvent: latestEvent,
                          etaLabel: _etaLabel,
                          distanceLabel: _distanceLabel,
                          isLoadingRoute: _isLoadingRoute,
                          mapMessage: _mapMessage,
                          riderLocationAvailable: rider != null,
                          onRetryRoute: () => _refreshRoute(fitCamera: true),
                          onCallRider: _launchCaller,
                          onOpenMap: _openExternalMap,
                        );
                      },
                    ),
                    if (_isLoadingRoute)
                      Positioned(
                        top: 158.h,
                        right: 16.w,
                        child: const _RouteLoadingBadge(),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handleBack() {
    if (!mounted) {
      return;
    }

    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }

    context.go(RouteNames.home);
  }

  String get _distanceLabel {
    final route = _route;
    if (route == null) {
      return '--';
    }
    final kilometers = route.distanceMeters / 1000;
    if (kilometers < 1) {
      return '${route.distanceMeters} m';
    }
    return '${kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1)} km';
  }

  String get _etaLabel {
    final route = _route;
    if (route == null) {
      return '--';
    }
    final minutes = (route.durationSeconds / 60).ceil();
    if (minutes < 60) {
      return '~$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '~${hours}h';
    }
    return '~${hours}h ${remainingMinutes}m';
  }

  void _bindOrder(OrderEntity order) {
    final fingerprint = <String>[
      order.id,
      order.status.name,
      '${_readDouble(_readMap(order.tracking, 'destination'), 'lat') ?? 0}',
      '${_readDouble(_readMap(order.tracking, 'destination'), 'lng') ?? 0}',
      '${_readDouble(_readMap(order.tracking, 'riderLocation'), 'lat') ?? 0}',
      '${_readDouble(_readMap(order.tracking, 'riderLocation'), 'lng') ?? 0}',
    ].join(':');

    if (_boundFingerprint == fingerprint) {
      return;
    }
    _boundFingerprint = fingerprint;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final destination = await _resolveDestination(order);
      final rider = _resolveInitialRider(order);
      if (!mounted) {
        return;
      }

      setState(() {
        _destination = destination;
        _riderPosition ??= rider;
        _mapMessage = destination == null
            ? 'Unable to resolve the delivery location right now.'
            : null;
      });

      await _refreshRoute(fitCamera: true);
    });
  }

  Future<GeoPoint?> _resolveDestination(OrderEntity order) async {
    final trackingDestination = _readMap(order.tracking, 'destination');
    final trackingLat = _readDouble(trackingDestination, 'lat');
    final trackingLng = _readDouble(trackingDestination, 'lng');
    if (trackingLat != null && trackingLng != null) {
      return GeoPoint(lat: trackingLat, lng: trackingLng);
    }

    final deliveryLat = _readDouble(order.deliveryAddress, 'lat');
    final deliveryLng = _readDouble(order.deliveryAddress, 'lng');
    if (deliveryLat != null && deliveryLng != null) {
      return GeoPoint(lat: deliveryLat, lng: deliveryLng);
    }

    final address = _formatAddress(order);
    return _mapsService.geocodeAddress(address);
  }

  GeoPoint? _resolveInitialRider(OrderEntity order) {
    final riderLocation = _readMap(order.tracking, 'riderLocation');
    final riderLat = _readDouble(riderLocation, 'lat');
    final riderLng = _readDouble(riderLocation, 'lng');
    if (riderLat == null || riderLng == null) {
      return null;
    }
    return GeoPoint(lat: riderLat, lng: riderLng);
  }

  Future<void> _refreshRoute({required bool fitCamera}) async {
    final origin = _riderPosition;
    final destination = _destination;
    if (origin == null || destination == null) {
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _mapMessage = null;
    });

    final route = await _mapsService.getRoute(origin, destination);
    if (!mounted) {
      return;
    }

    setState(() {
      _route = route;
      _isLoadingRoute = false;
      if (route == null) {
        _mapMessage = 'Unable to calculate route right now.';
      }
    });

    if (fitCamera && !_userMovedMap) {
      _fitToVisiblePoints();
    }
  }

  void _fitToVisiblePoints() {
    if (!_mapReady) {
      return;
    }

    final points = <GeoPoint>[
      if (_riderPosition != null) _riderPosition!,
      if (_destination != null) _destination!,
      ...?_route?.points,
    ];
    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      _mapController.move(_toMapPoint(points.first), 16);
      return;
    }

    final bounds = LatLngBounds.fromPoints(
      points.map(_toMapPoint).toList(growable: false),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.fromLTRB(48.w, 120.h, 48.w, 280.h),
      ),
    );
  }

  List<Marker> _buildMarkers({
    required GeoPoint? rider,
    required GeoPoint destination,
  }) {
    return <Marker>[
      if (rider != null)
        Marker(
          point: _toMapPoint(rider),
          width: 80,
          height: 80,
          child: const _TrackingMarker(
            icon: Icons.two_wheeler_rounded,
            label: 'Rider',
            accent: AppColors.infoBlue,
            tint: Color(0xFFE3F2FD),
          ),
        ),
      Marker(
        point: _toMapPoint(destination),
        width: 110,
        height: 88,
        child: const _TrackingMarker(
          icon: Icons.home_rounded,
          label: 'You',
          accent: AppColors.primaryGreen,
          tint: Color(0xFFE8F5E9),
        ),
      ),
    ];
  }

  Future<void> _launchCaller() async {
    final order = ref.read(orderDetailProvider(widget.id)).asData?.value;
    if (order == null) {
      return;
    }
    final riderPhone = _readString(_readMap(order.tracking, 'rider'), 'phone');
    if (riderPhone.isEmpty) {
      return;
    }

    final uri = Uri(scheme: 'tel', path: riderPhone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openExternalMap() async {
    final rider = _riderPosition;
    final destination = _destination;
    if (rider == null || destination == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car'
      '&route=${rider.lat},${rider.lng};${destination.lat},${destination.lng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatAddress(OrderEntity order) {
    final address = order.deliveryAddress;
    return <String>[
      _readString(address, 'addressLine1'),
      _readString(address, 'address_line1'),
      _readString(address, 'addressLine2'),
      _readString(address, 'address_line2'),
      _readString(address, 'landmark'),
      _readString(address, 'city'),
      _readString(address, 'state'),
      _readString(address, 'pincode'),
    ].where((part) => part.trim().isNotEmpty).join(', ');
  }

  map.LatLng _toMapPoint(GeoPoint point) => map.LatLng(point.lat, point.lng);

  Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  String _readString(
    Map<String, dynamic> json,
    String key, {
    String fallback = '',
  }) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  double? _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}

class _TrackingTopBar extends StatelessWidget {
  const _TrackingTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              boxShadow: const <BoxShadow>[AppShadows.cardShadow],
            ),
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              boxShadow: const <BoxShadow>[AppShadows.cardShadow],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIcons.mapTrifold(),
                    size: 16.sp,
                    color: AppColors.infoBlue,
                  ),
                  Gap(6.w),
                  Text(
                    'Live tracking',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingStatusCard extends StatelessWidget {
  const _TrackingStatusCard({
    required this.order,
    required this.latestEvent,
    required this.etaLabel,
    required this.distanceLabel,
    required this.hasRiderLocation,
  });

  final OrderEntity order;
  final OrderTimelineEntity? latestEvent;
  final String etaLabel;
  final String distanceLabel;
  final bool hasRiderLocation;

  @override
  Widget build(BuildContext context) {
    final stageLabel = latestEvent?.type.label ?? order.status.label;
    final stageMessage = hasRiderLocation
        ? (latestEvent?.message ?? 'Rider is moving towards you.')
        : 'Rider location will appear once delivery starts.';

    return Container(
      margin: EdgeInsets.only(top: 14.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  stageLabel,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Gap(4.h),
                Text(
                  stageMessage,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Gap(12.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: <Widget>[
                    _StatusPill(
                      icon: PhosphorIcons.navigationArrow(),
                      label: etaLabel,
                    ),
                    _StatusPill(
                      icon: PhosphorIcons.path(),
                      label: distanceLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              color: AppColors.primaryGreen,
              size: 28.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
  });

  final PhosphorIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(icon, size: 14.sp, color: AppColors.infoBlue),
          Gap(6.w),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.showRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  final bool showRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _MapControlButton(icon: Icons.add_rounded, onTap: onZoomIn),
        Gap(12.h),
        _MapControlButton(icon: Icons.remove_rounded, onTap: onZoomOut),
        if (showRecenter) ...<Widget>[
          Gap(12.h),
          _MapControlButton(
            icon: Icons.my_location_rounded,
            onTap: onRecenter,
          ),
        ],
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.textPrimary),
      ),
    );
  }
}

class _TrackingBottomSheet extends StatelessWidget {
  const _TrackingBottomSheet({
    required this.scrollController,
    required this.order,
    required this.riderName,
    required this.riderPhone,
    required this.latestEvent,
    required this.etaLabel,
    required this.distanceLabel,
    required this.isLoadingRoute,
    required this.mapMessage,
    required this.riderLocationAvailable,
    required this.onRetryRoute,
    required this.onCallRider,
    required this.onOpenMap,
  });

  final ScrollController scrollController;
  final OrderEntity order;
  final String riderName;
  final String riderPhone;
  final OrderTimelineEntity? latestEvent;
  final String etaLabel;
  final String distanceLabel;
  final bool isLoadingRoute;
  final String? mapMessage;
  final bool riderLocationAvailable;
  final VoidCallback onRetryRoute;
  final Future<void> Function() onCallRider;
  final Future<void> Function() onOpenMap;

  @override
  Widget build(BuildContext context) {
    final address = order.deliveryAddress;
    final addressLine = <String>[
      '${address['addressLine1'] ?? address['address_line1'] ?? ''}',
      '${address['addressLine2'] ?? address['address_line2'] ?? ''}',
      '${address['landmark'] ?? ''}',
      '${address['city'] ?? ''}',
      '${address['pincode'] ?? ''}',
    ].where((part) => part.trim().isNotEmpty).join(', ');

    final timeline = order.timeline.reversed.take(5).toList(growable: false);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            18.w,
            18.h,
            18.w,
            20.h + MediaQuery.of(context).padding.bottom,
          ),
          children: <Widget>[
            Center(
              child: Container(
                width: 44.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
            Gap(18.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.orderNumber,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Gap(4.h),
                      Text('Delivering to you', style: AppTextStyles.h2),
                    ],
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenLight,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    order.status.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryGreenDark,
                    ),
                  ),
                ),
              ],
            ),
            Gap(16.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(22.r),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _KeyValue(label: 'ETA', value: etaLabel),
                  ),
                  Container(
                    width: 1,
                    height: 28.h,
                    color: AppColors.borderLight,
                  ),
                  Expanded(
                    child: _KeyValue(label: 'Distance', value: distanceLabel),
                  ),
                ],
              ),
            ),
            Gap(14.h),
            if (!riderLocationAvailable)
              _InlineMessage(
                message:
                    'Rider location will appear here once delivery movement starts.',
                actionLabel: 'Refresh',
                onTap: onRetryRoute,
              ),
            if (!riderLocationAvailable) Gap(12.h),
            if (mapMessage != null)
              _InlineMessage(
                message: mapMessage!,
                actionLabel: 'Retry',
                onTap: onRetryRoute,
              ),
            if (mapMessage != null) Gap(12.h),
            if (order.deliveryOtp != null &&
                order.deliveryOtp!.trim().isNotEmpty) ...<Widget>[
              _DeliveryOtpCard(otp: order.deliveryOtp!.trim()),
              Gap(14.h),
            ],
            Text('Rider', style: AppTextStyles.labelLarge),
            Gap(6.h),
            Text(
              riderName,
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
            ),
            if (riderPhone.trim().isNotEmpty) ...<Widget>[
              Gap(2.h),
              Text(
                riderPhone,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            Gap(14.h),
            Text('Delivery address', style: AppTextStyles.labelLarge),
            Gap(6.h),
            Text(
              addressLine.isEmpty ? 'Address unavailable' : addressLine,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Gap(16.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        riderPhone.trim().isEmpty ? null : () => onCallRider(),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call rider'),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isLoadingRoute ? null : () => onOpenMap(),
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Open route'),
                  ),
                ),
              ],
            ),
            Gap(18.h),
            Text('Live timeline', style: AppTextStyles.h3),
            Gap(10.h),
            ...timeline.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _TimelineRow(item: item),
              ),
            ),
            if (timeline.isEmpty)
              Text(
                latestEvent?.message ?? 'Waiting for the next delivery update.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown while the rider's delivery assignment is ACCEPTED/IN_TRANSIT.
/// The customer reads these digits out to the rider to confirm delivery.
class _DeliveryOtpCard extends StatelessWidget {
  const _DeliveryOtpCard({required this.otp});

  final String otp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primaryGreenLight,
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.lock_clock_rounded,
                color: AppColors.primaryGreenDark,
                size: 28.sp,
              ),
              Gap(12.w),
              Expanded(
                child: Text(
                  'Delivery OTP',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primaryGreenDark,
                  ),
                ),
              ),
              Gap(10.w),
              Text(
                otp,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.primaryGreenDark,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Gap(10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: 16.sp,
                color: AppColors.primaryGreenDark,
              ),
              Gap(6.w),
              Expanded(
                child: Text(
                  "Don't share this code yet. Only tell it to your delivery "
                  'partner when they arrive at your door to confirm '
                  'delivery.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryGreenDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(4.h),
          Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.accentYellowLight,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final OrderTimelineEntity item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 12.w,
          height: 12.w,
          margin: EdgeInsets.only(top: 4.h),
          decoration: const BoxDecoration(
            color: AppColors.primaryGreen,
            shape: BoxShape.circle,
          ),
        ),
        Gap(10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(item.type.label, style: AppTextStyles.labelLarge),
              Gap(2.h),
              Text(
                item.message ?? item.status.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Gap(12.w),
        Text(
          DateFormat('hh:mm a').format(item.timestamp.toLocal()),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _TrackingMarker extends StatelessWidget {
  const _TrackingMarker({
    required this.icon,
    required this.label,
    required this.accent,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: const <BoxShadow>[AppShadows.cardShadow],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: accent, size: 18.sp),
              ),
              Gap(8.w),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.location_on_rounded, color: accent, size: 22.sp),
      ],
    );
  }
}

class _RouteLoadingBadge extends StatelessWidget {
  const _RouteLoadingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Refreshing route',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapUnavailableState extends StatelessWidget {
  const _MapUnavailableState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgPrimary,
      alignment: Alignment.center,
      padding: EdgeInsets.all(24.w),
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.map_outlined,
              size: 42.sp,
              color: AppColors.infoBlue,
            ),
            Gap(12.h),
            Text('Map unavailable', style: AppTextStyles.h3),
            Gap(8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Gap(16.h),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingErrorState extends StatelessWidget {
  const _TrackingErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 42.sp,
              color: AppColors.errorRed,
            ),
            Gap(12.h),
            Text('Unable to load tracking', style: AppTextStyles.h3),
            Gap(8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Gap(16.h),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
