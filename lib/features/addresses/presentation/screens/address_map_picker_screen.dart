import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as map;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/maps/maps_service.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/debouncer.dart';

class AddressMapPickerScreen extends StatefulWidget {
  const AddressMapPickerScreen({
    super.key,
    this.initialPoint,
  });

  final GeoPoint? initialPoint;

  @override
  State<AddressMapPickerScreen> createState() => _AddressMapPickerScreenState();
}

class _AddressMapPickerScreenState extends State<AddressMapPickerScreen>
    with TickerProviderStateMixin {
  static const GeoPoint _fallbackPoint = GeoPoint(lat: 22.5726, lng: 88.3639);
  static const String _mapUserAgent = 'BakalooCustomerAddressPicker/1.0';

  final MapController _mapController = MapController();
  final MapsService _mapsService = MapsService();
  final Dio _searchDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const <String, String>{
        HttpHeaders.userAgentHeader: _mapUserAgent,
        HttpHeaders.acceptHeader: 'application/json',
      },
    ),
  );
  final Debouncer _mapIdleDebouncer = Debouncer(
    delay: const Duration(milliseconds: 500),
  );
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final AnimationController _mapAnimationController;
  late GeoPoint _selectedPoint;

  Tween<double>? _latTween;
  Tween<double>? _lngTween;
  Tween<double>? _zoomTween;
  GeoPoint? _animationTargetPoint;
  double? _animationTargetZoom;

  GeoPoint? _currentLocationPoint;
  _ResolvedLocationDetails? _resolvedLocation;
  List<_SearchSuggestion> _searchSuggestions = const <_SearchSuggestion>[];

  bool _mapReady = false;
  bool _isLocating = false;
  bool _isConfirming = false;
  bool _isResolvingLocation = true;
  bool _isSearching = false;
  bool _isAnimatingMap = false;
  String? _searchError;

  int _searchRequestId = 0;
  int _resolveRequestId = 0;
  double _currentZoom = 16;

  bool get _showSearchOverlay {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return hasQuery &&
        (_searchFocusNode.hasFocus ||
            _isSearching ||
            _searchError != null ||
            _searchSuggestions.isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint?.isValid == true
        ? widget.initialPoint!
        : _fallbackPoint;
    _currentZoom = widget.initialPoint?.isValid == true ? 16 : 14;

    _mapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )
      ..addListener(_handleMapAnimationTick)
      ..addStatusListener(_handleMapAnimationStatus);

    _searchController.addListener(_handleSearchChanged);
    _searchFocusNode.addListener(_handleSearchFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resolvePointDetails(_selectedPoint, showLoader: true));
      unawaited(_captureCurrentLocationSilently());
    });
  }

  @override
  void dispose() {
    _mapIdleDebouncer.dispose();
    _searchDebouncer.dispose();
    _searchDio.close(force: true);
    _mapAnimationController.dispose();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _searchFocusNode
      ..removeListener(_handleSearchFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _buildMap()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopOverlay(),
          ),
          Positioned(
            top: 152.h,
            right: 16.w,
            child: IgnorePointer(
              ignoring: _showSearchOverlay,
              child: AnimatedOpacity(
                opacity: _showSearchOverlay ? 0 : 1,
                duration: const Duration(milliseconds: 180),
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
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: _CenterPinOverlay(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomLocationSheet(
              details: _resolvedLocation,
              isResolving: _isResolvingLocation,
              isConfirming: _isConfirming,
              distanceLabel: _distanceLabel,
              onConfirm: _confirmSelection,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _toLatLng(_selectedPoint),
        initialZoom: _currentZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _mapReady = true;
          _mapController.move(_toLatLng(_selectedPoint), _currentZoom);
        },
        onTap: (_, __) => _dismissSearchOverlay(),
        onPositionChanged: (MapCamera camera, bool hasGesture) {
          _currentZoom = camera.zoom;
          final nextPoint = GeoPoint(
            lat: camera.center.latitude,
            lng: camera.center.longitude,
          );

          if (!_samePoint(nextPoint, _selectedPoint) && mounted) {
            setState(() {
              _selectedPoint = nextPoint;
            });
          }

          if (!_isAnimatingMap) {
            _mapIdleDebouncer.run(() {
              unawaited(_resolvePointDetails(nextPoint));
            });
          }

          if (hasGesture && _searchFocusNode.hasFocus) {
            _dismissSearchOverlay();
          }
        },
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.bakaloo.india',
          maxNativeZoom: 19,
          maxZoom: 19,
        ),
        const RichAttributionWidget(
          attributions: <SourceAttribution>[
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TopBar(
              onBack: () {
                if (_showSearchOverlay) {
                  _dismissSearchOverlay();
                  return;
                }
                Navigator.of(context).maybePop();
              },
            ),
            Gap(12.h),
            _SearchCard(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hasText: _searchController.text.trim().isNotEmpty,
              onClear: _clearSearch,
              onSubmitted: _handleSearchSubmitted,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _showSearchOverlay
                  ? Padding(
                      key: const ValueKey<String>('search-results'),
                      padding: EdgeInsets.only(top: 10.h),
                      child: _SearchResultsCard(
                        isLoading: _isSearching,
                        errorText: _searchError,
                        suggestions: _searchSuggestions,
                        onSuggestionTap: _selectSearchSuggestion,
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey<String>('search-results-hidden'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      _searchRequestId++;
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchError = null;
          _searchSuggestions = const <_SearchSuggestion>[];
        });
      }
      return;
    }

    _searchDebouncer.run(() {
      unawaited(_searchLocations(query));
    });
  }

  void _handleSearchFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSearchSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return;
    }

    if (_searchSuggestions.isNotEmpty) {
      _selectSearchSuggestion(_searchSuggestions.first);
      return;
    }

    unawaited(_searchLocations(trimmed));
  }

  Future<void> _searchLocations(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return;
    }

    final requestId = ++_searchRequestId;
    if (mounted) {
      setState(() {
        _isSearching = true;
        _searchError = null;
      });
    }

    try {
      final response = await _searchDio.get<dynamic>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: <String, dynamic>{
          'q': trimmed,
          'format': 'jsonv2',
          'limit': 6,
          'addressdetails': 1,
          'countrycodes': 'in',
        },
        options: Options(
          headers: const <String, String>{
            HttpHeaders.userAgentHeader: _mapUserAgent,
            'Accept-Language': 'en-IN,en;q=0.9',
          },
        ),
      );

      final suggestions = _parseSearchSuggestions(response.data);
      final fallbackSuggestions =
          suggestions.isEmpty ? await _fallbackSearch(trimmed) : suggestions;

      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        _isSearching = false;
        _searchSuggestions = fallbackSuggestions;
        _searchError = fallbackSuggestions.isEmpty ? 'No places found.' : null;
      });
    } catch (_) {
      final fallbackSuggestions = await _fallbackSearch(trimmed);
      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        _isSearching = false;
        _searchSuggestions = fallbackSuggestions;
        _searchError =
            fallbackSuggestions.isEmpty ? 'Unable to search right now.' : null;
      });
    }
  }

  Future<List<_SearchSuggestion>> _fallbackSearch(String query) async {
    try {
      final locations = await locationFromAddress(query);
      return locations
          .take(3)
          .map(
            (location) => _SearchSuggestion(
              title: query,
              subtitle: 'Detected from geocoder',
              point: GeoPoint(
                lat: location.latitude,
                lng: location.longitude,
              ),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <_SearchSuggestion>[];
    }
  }

  List<_SearchSuggestion> _parseSearchSuggestions(dynamic data) {
    final results = switch (data) {
      final List<dynamic> list => list,
      _ => const <dynamic>[],
    };

    return results
        .map((dynamic item) => _SearchSuggestion.fromJson(item))
        .whereType<_SearchSuggestion>()
        .toList(growable: false);
  }

  Future<void> _selectSearchSuggestion(_SearchSuggestion suggestion) async {
    _dismissSearchOverlay(clearQuery: true);
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPoint = suggestion.point;
    });

    await _animateMapTo(suggestion.point, zoom: 17);
  }

  Future<void> _captureCurrentLocationSilently() async {
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      final currentPoint = GeoPoint(lat: position.latitude, lng: position.longitude);

      setState(() {
        _currentLocationPoint = currentPoint;
      });
    } catch (_) {
      // Silent path intentionally swallows errors.
    }
  }

  Future<void> _moveToCurrentLocation() async {
    if (_isLocating) {
      return;
    }

    setState(() {
      _isLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are turned off.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentPoint = GeoPoint(
        lat: position.latitude,
        lng: position.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocationPoint = currentPoint;
        _selectedPoint = currentPoint;
      });

      await _animateMapTo(currentPoint, zoom: 17);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is Exception
                  ? error.toString().replaceFirst('Exception: ', '')
                  : 'Unable to fetch current location.',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _animateMapTo(GeoPoint point, {double? zoom}) async {
    final nextZoom = zoom ?? _currentZoom;
    if (!_mapReady) {
      setState(() {
        _selectedPoint = point;
        _currentZoom = nextZoom;
      });
      unawaited(_resolvePointDetails(point, showLoader: true));
      return;
    }

    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    _latTween = Tween<double>(begin: startCenter.latitude, end: point.lat);
    _lngTween = Tween<double>(begin: startCenter.longitude, end: point.lng);
    _zoomTween = Tween<double>(begin: startZoom, end: nextZoom);
    _animationTargetPoint = point;
    _animationTargetZoom = nextZoom;
    _isAnimatingMap = true;

    await _mapAnimationController.forward(from: 0);
  }

  void _handleMapAnimationTick() {
    if (!_mapReady ||
        _latTween == null ||
        _lngTween == null ||
        _zoomTween == null) {
      return;
    }

    final t = Curves.easeInOutCubic.transform(_mapAnimationController.value);
    _mapController.move(
      map.LatLng(_latTween!.transform(t), _lngTween!.transform(t)),
      _zoomTween!.transform(t),
    );
  }

  void _handleMapAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }

    _isAnimatingMap = false;
    final targetPoint = _animationTargetPoint;
    final targetZoom = _animationTargetZoom;
    if (targetPoint == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _selectedPoint = targetPoint;
        _currentZoom = targetZoom ?? _currentZoom;
      });
    }

    unawaited(_resolvePointDetails(targetPoint));
  }

  Future<void> _resolvePointDetails(
    GeoPoint point, {
    bool showLoader = true,
  }) async {
    final requestId = ++_resolveRequestId;
    if (showLoader && mounted) {
      setState(() {
        _isResolvingLocation = true;
      });
    }

    try {
      final reverse = await _mapsService.reverseGeocode(point);
      Placemark? fallbackPlacemark;

      if (reverse == null || !_hasUsefulReverseDetails(reverse)) {
        final placemarks = await placemarkFromCoordinates(point.lat, point.lng);
        fallbackPlacemark = placemarks.isEmpty ? null : placemarks.first;
      }

      if (!mounted || requestId != _resolveRequestId) {
        return;
      }

      setState(() {
        _resolvedLocation = _ResolvedLocationDetails.fromSources(
          point: point,
          reverse: reverse,
          placemark: fallbackPlacemark,
        );
        _isResolvingLocation = false;
      });
    } catch (_) {
      if (!mounted || requestId != _resolveRequestId) {
        return;
      }

      setState(() {
        _resolvedLocation = _ResolvedLocationDetails.fallback(point);
        _isResolvingLocation = false;
      });
    }
  }

  bool _hasUsefulReverseDetails(ReverseGeocodeResult reverse) {
    // Nominatim (OSM) reliably covers broad fields — city/state/pincode —
    // almost everywhere in India, even where its fine-grained coverage of
    // small residential colonies is sparse. Checking "any field" here meant
    // the richer on-device geocoder fallback below almost never ran, since
    // state/pincode alone were enough to satisfy it — leaving the specific
    // road/colony name blank in exactly the areas it matters most. Only
    // treat Nominatim's answer as sufficient when it actually names the
    // place (addressLine1/addressLine2); otherwise fetch the native
    // placemark too so _ResolvedLocationDetails.fromSources can merge in
    // whichever source has the better road/locality name.
    return <String?>[
      reverse.addressLine1,
      reverse.addressLine2,
    ].any((value) => (value ?? '').trim().isNotEmpty);
  }

  Future<void> _confirmSelection() async {
    if (_isConfirming) {
      return;
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      var details = _resolvedLocation;
      if (details == null) {
        await _resolvePointDetails(_selectedPoint, showLoader: false);
        details = _resolvedLocation;
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        AddressMapPickerResult(
          point: _selectedPoint,
          displayName: details?.displayName,
          addressLine1: details?.addressLine1,
          addressLine2: details?.addressLine2,
          city: details?.city,
          state: details?.state,
          pincode: details?.pincode,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  void _dismissSearchOverlay({bool clearQuery = false}) {
    _searchFocusNode.unfocus();
    _searchDebouncer.cancel();

    if (clearQuery) {
      _searchController.clear();
    }

    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchError = null;
        _searchSuggestions = const <_SearchSuggestion>[];
      });
    }
  }

  void _clearSearch() {
    _dismissSearchOverlay(clearQuery: true);
  }

  String get _distanceLabel {
    final current = _currentLocationPoint;
    if (current == null) {
      return 'Use current location to calculate distance';
    }

    final distanceMeters = Geolocator.distanceBetween(
      current.lat,
      current.lng,
      _selectedPoint.lat,
      _selectedPoint.lng,
    );
    final kms = distanceMeters / 1000;
    return 'Pin location is ${kms.toStringAsFixed(1)} kms away from current location';
  }

  bool _samePoint(GeoPoint a, GeoPoint b) {
    return (a.lat - b.lat).abs() < 0.000001 && (a.lng - b.lng).abs() < 0.000001;
  }

  map.LatLng _toLatLng(GeoPoint point) => map.LatLng(point.lat, point.lng);
}

class AddressMapPickerResult {
  const AddressMapPickerResult({
    required this.point,
    this.displayName,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
  });

  final GeoPoint point;
  final String? displayName;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;

  String get previewLabel {
    final parts = <String>[
      if (displayName != null && displayName!.trim().isNotEmpty) displayName!,
      if (city != null && city!.trim().isNotEmpty) city!,
      if (pincode != null && pincode!.trim().isNotEmpty) pincode!,
    ];
    if (parts.isNotEmpty) {
      return parts.join(' • ');
    }
    return '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58.h,
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: const <BoxShadow>[AppShadows.floatingShadow],
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: PhosphorIcon(
              PhosphorIcons.caretLeftBold,
              size: 20.sp,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              'Select Your Location',
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: const <BoxShadow>[AppShadows.floatingShadow],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search for apartment, street name...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: PhosphorIcon(
              PhosphorIcons.magnifyingGlass,
              size: 18.sp,
              color: AppColors.textSecondary,
            ),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: 48.w,
            minHeight: 48.h,
          ),
          suffixIcon: hasText
              ? IconButton(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18.sp,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 15.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(
              color: Color(0x22000000),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({
    required this.isLoading,
    required this.errorText,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  final bool isLoading;
  final String? errorText;
  final List<_SearchSuggestion> suggestions;
  final ValueChanged<_SearchSuggestion> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (isLoading) {
      child = Padding(
        padding: EdgeInsets.all(18.w),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 18.w,
              height: 18.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            Gap(12.w),
            Expanded(
              child: Text(
                'Searching places...',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      );
    } else if (errorText != null) {
      child = Padding(
        padding: EdgeInsets.all(18.w),
        child: Text(
          errorText!,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    } else {
      child = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 260.h),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 6.h),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 18.w,
            endIndent: 18.w,
            color: AppColors.divider,
          ),
          itemBuilder: (BuildContext context, int index) {
            final suggestion = suggestions[index];
            return _SearchSuggestionTile(
              suggestion: suggestion,
              onTap: () => onSuggestionTap(suggestion),
            );
          },
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: const <BoxShadow>[AppShadows.floatingShadow],
      ),
      child: child,
    );
  }
}

class _SearchSuggestionTile extends StatelessWidget {
  const _SearchSuggestionTile({
    required this.suggestion,
    required this.onTap,
  });

  final _SearchSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.location_on_outlined,
                size: 18.sp,
                color: AppColors.textSecondary,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    suggestion.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (suggestion.subtitle.isNotEmpty) ...<Widget>[
                    Gap(3.h),
                    Text(
                      suggestion.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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

class _CenterPinOverlay extends StatelessWidget {
  const _CenterPinOverlay();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -56.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _TooltipBubble(),
          Gap(8.h),
          PhosphorIcon(
            PhosphorIcons.mapPinFill,
            size: 42.sp,
            color: AppColors.cartPink,
          ),
        ],
      ),
    );
  }
}

class _TooltipBubble extends StatelessWidget {
  const _TooltipBubble();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          constraints: BoxConstraints(maxWidth: 260.w),
          padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: const <BoxShadow>[AppShadows.floatingShadow],
          ),
          child: Column(
            children: <Widget>[
              Text(
                'Order will be delivered here',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap(2.h),
              Text(
                'Place the pin to your exact location',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: Size(18.w, 10.h),
          painter: const _TrianglePainter(color: Color(0xFF333333)),
        ),
      ],
    );
  }
}

class _BottomLocationSheet extends StatelessWidget {
  const _BottomLocationSheet({
    required this.details,
    required this.isResolving,
    required this.isConfirming,
    required this.distanceLabel,
    required this.onConfirm,
  });

  final _ResolvedLocationDetails? details;
  final bool isResolving;
  final bool isConfirming;
  final String distanceLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final areaName = details?.areaName ?? 'Fetching address...';
    final fullAddress = details?.fullAddress ?? 'Pin the map to update address';

    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: <BoxShadow>[AppShadows.floatingShadow],
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24.r),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Align(
                child: Container(
                  width: 52.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
              Gap(16.h),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Column(
                  key: ValueKey<String>('${areaName}_$fullAddress'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      areaName,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap(6.h),
                    Text(
                      fullAddress,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(10.h),
              Row(
                children: <Widget>[
                  if (isResolving)
                    SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (isResolving) Gap(8.w),
                  Expanded(
                    child: Text(
                      distanceLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Gap(18.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: FilledButton(
                  onPressed: isConfirming ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.cartPink,
                    disabledBackgroundColor:
                        AppColors.cartPink.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                  ),
                  child: isConfirming
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Confirm Location',
                          style: AppTextStyles.buttonLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
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

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ResolvedLocationDetails {
  const _ResolvedLocationDetails({
    required this.areaName,
    required this.fullAddress,
    this.displayName,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
  });

  final String areaName;
  final String fullAddress;
  final String? displayName;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;

  factory _ResolvedLocationDetails.fromSources({
    required GeoPoint point,
    ReverseGeocodeResult? reverse,
    Placemark? placemark,
  }) {
    final addressLine1 = _pickFirstNonEmpty(<String?>[
      reverse?.addressLine1,
      _joinParts(<String?>[
        placemark?.subThoroughfare,
        placemark?.thoroughfare,
      ]),
      placemark?.street,
    ]);
    final addressLine2 = _pickFirstNonEmpty(<String?>[
      reverse?.addressLine2,
      _joinParts(<String?>[
        placemark?.subLocality,
        placemark?.locality,
      ]),
      placemark?.subAdministrativeArea,
    ]);
    final city = _pickFirstNonEmpty(<String?>[
      reverse?.city,
      placemark?.locality,
      placemark?.subAdministrativeArea,
      placemark?.administrativeArea,
    ]);
    final state = _pickFirstNonEmpty(<String?>[
      reverse?.state,
      placemark?.administrativeArea,
    ]);
    final pincode = _pickFirstNonEmpty(<String?>[
      reverse?.pincode,
      placemark?.postalCode,
    ]);
    final displayName = _pickFirstNonEmpty(<String?>[
      reverse?.displayName,
      _joinParts(<String?>[
        addressLine1,
        addressLine2,
        city,
        state,
        pincode,
      ]),
    ]);

    final areaName = _pickFirstNonEmpty(<String?>[
      city,
      addressLine2,
      addressLine1,
      displayName.split(',').first.trim(),
    ]);
    final fullAddress = _joinParts(<String?>[
      addressLine1,
      addressLine2,
      city,
      state,
      pincode,
    ]);

    return _ResolvedLocationDetails(
      areaName: areaName.isEmpty ? 'Selected location' : areaName,
      fullAddress: fullAddress.isEmpty
          ? '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}'
          : fullAddress,
      displayName: displayName.isEmpty ? null : displayName,
      addressLine1: addressLine1.isEmpty ? null : addressLine1,
      addressLine2: addressLine2.isEmpty ? null : addressLine2,
      city: city.isEmpty ? null : city,
      state: state.isEmpty ? null : state,
      pincode: pincode.isEmpty ? null : pincode,
    );
  }

  factory _ResolvedLocationDetails.fallback(GeoPoint point) {
    final label =
        '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}';
    return _ResolvedLocationDetails(
      areaName: 'Pinned location',
      fullAddress: label,
      displayName: label,
    );
  }

  static String _pickFirstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  static String _joinParts(List<String?> values) {
    final seen = <String>{};
    final parts = <String>[];
    for (final value in values) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final normalized = trimmed.toLowerCase();
      if (seen.add(normalized)) {
        parts.add(trimmed);
      }
    }
    return parts.join(', ');
  }
}

class _SearchSuggestion {
  const _SearchSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
  });

  final String title;
  final String subtitle;
  final GeoPoint point;

  factory _SearchSuggestion.fromJson(dynamic json) {
    if (json is! Map) {
      throw const FormatException('Invalid search result');
    }

    final mapJson = Map<String, dynamic>.from(json);
    final lat = double.tryParse('${mapJson['lat'] ?? ''}');
    final lng = double.tryParse('${mapJson['lon'] ?? ''}');
    if (lat == null || lng == null) {
      throw const FormatException('Missing coordinates');
    }

    final address = switch (mapJson['address']) {
      final Map value => Map<String, dynamic>.from(value),
      _ => const <String, dynamic>{},
    };

    final title = _ResolvedLocationDetails._pickFirstNonEmpty(<String?>[
      address['name'] as String?,
      address['road'] as String?,
      address['suburb'] as String?,
      address['city'] as String?,
      address['town'] as String?,
      address['village'] as String?,
      (mapJson['display_name'] as String?)?.split(',').first,
    ]);

    final subtitle = _ResolvedLocationDetails._joinParts(<String?>[
      address['suburb'] as String?,
      address['city'] as String? ?? address['town'] as String?,
      address['state'] as String?,
      address['postcode'] as String?,
    ]);

    return _SearchSuggestion(
      title: title.isEmpty ? 'Selected place' : title,
      subtitle: subtitle.isEmpty
          ? ((mapJson['display_name'] as String?) ?? '').trim()
          : subtitle,
      point: GeoPoint(lat: lat, lng: lng),
    );
  }
}
