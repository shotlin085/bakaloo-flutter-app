import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as map;
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/utils/debouncer.dart';
import 'package:bakaloo_flutter_app/core/utils/validators.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/screens/address_map_picker_screen.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';

class AddEditAddressScreen extends ConsumerStatefulWidget {
  const AddEditAddressScreen({
    this.initialAddress,
    super.key,
  });

  final AddressEntity? initialAddress;

  @override
  ConsumerState<AddEditAddressScreen> createState() =>
      _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends ConsumerState<AddEditAddressScreen> {
  static const GeoPoint _fallbackPoint = GeoPoint(
    lat: 22.5726,
    lng: 88.3639,
  );
  static const List<String> _labels = <String>['Home', 'Work', 'Other'];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverPhoneController =
      TextEditingController();
  final Debouncer _pincodeDebouncer = Debouncer(
    delay: const Duration(milliseconds: 350),
  );

  String _selectedLabel = 'Home';
  double? _latitude;
  double? _longitude;
  String? _areaName;
  String? _displayAddress;
  String? _city;
  String? _state;
  String? _pincode;
  bool _isSaving = false;
  bool _isLocating = false;
  _PincodeValidationStatus _pincodeStatus = _PincodeValidationStatus.idle;
  String? _pincodeMessage;
  int _pincodeRequestId = 0;

  bool get _isEditing => widget.initialAddress != null;

  bool get _hasPinnedLocation =>
      _latitude != null &&
      _longitude != null &&
      GeoPoint(lat: _latitude!, lng: _longitude!).isValid;

  GeoPoint get _previewPoint => _hasPinnedLocation
      ? GeoPoint(lat: _latitude!, lng: _longitude!)
      : _fallbackPoint;

  bool get _canSave =>
      !_isSaving &&
      _hasPinnedLocation &&
      _addressLine1Controller.text.trim().isNotEmpty &&
      _pincodeStatus == _PincodeValidationStatus.valid;

  @override
  void initState() {
    super.initState();
    _seedFromInitialAddress();
    _addressLine1Controller.addListener(_handleFormStateChanged);
    if ((_pincode ?? '').trim().isNotEmpty) {
      _schedulePincodeValidation(_pincode);
    }
  }

  @override
  void dispose() {
    _addressLine1Controller
      ..removeListener(_handleFormStateChanged)
      ..dispose();
    _buildingController.dispose();
    _landmarkController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _pincodeDebouncer.dispose();
    super.dispose();
  }

  void _seedFromInitialAddress() {
    final address = widget.initialAddress;
    if (address == null) {
      return;
    }
    final authState = ref.read(authStateProvider);
    final accountName = switch (authState) {
      AuthAuthenticated(:final user) => user.name?.trim(),
      _ => null,
    };
    final accountPhone = switch (authState) {
      AuthAuthenticated(:final user) => user.phone.trim(),
      _ => null,
    };

    final secondaryParts = _splitSecondaryAddress(address.addressLine2);
    _selectedLabel = _normalizeLabel(address.label);
    _addressLine1Controller.text = address.addressLine1;
    _buildingController.text = secondaryParts.$1;
    _landmarkController.text = secondaryParts.$2;
    _receiverNameController.text = (_firstNonEmpty(<String?>[
          address.receiverName,
          accountName,
          address.name,
        ]) ??
        '');
    _receiverPhoneController.text = _sanitizePhone(
      _firstNonEmpty(<String?>[
            address.receiverPhone,
            accountPhone,
            address.phone,
          ]) ??
          '',
    );
    _city = address.city.trim();
    _state = address.state.trim();
    _pincode = address.pincode.trim();
    _latitude = address.latitude;
    _longitude = address.longitude;
    _areaName = _deriveAreaName(
      displayName: null,
      addressLine1: address.addressLine1,
      addressLine2: address.addressLine2,
      city: address.city,
    );
    _displayAddress = _composeDisplayAddress(
      displayName: null,
      addressLine1: address.addressLine1,
      addressLine2: address.addressLine2,
      city: address.city,
      state: address.state,
      pincode: address.pincode,
    );
  }

  void _handleFormStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openMapPicker({
    GeoPoint? initialPoint,
  }) async {
    final result = await Navigator.of(context).push<AddressMapPickerResult>(
      MaterialPageRoute<AddressMapPickerResult>(
        builder: (_) => AddressMapPickerScreen(
          initialPoint:
              initialPoint ?? (_hasPinnedLocation ? _previewPoint : null),
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    await _applyMapResult(result);
  }

  Future<void> _openMapPickerFromCurrentLocation() async {
    if (_isLocating) {
      return;
    }

    setState(() {
      _isLocating = true;
    });

    try {
      final permission = await Permission.locationWhenInUse.request();
      if (!mounted) {
        return;
      }

      if (!permission.isGranted) {
        AppToast.show(context, '📍 Location permission is required to detect your location.', type: ToastType.warning);
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) {
        return;
      }
      if (!serviceEnabled) {
        AppToast.show(context, '📍 Turn on location services and try again.', type: ToastType.warning);
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

      await _openMapPicker(
        initialPoint: GeoPoint(
          lat: position.latitude,
          lng: position.longitude,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.show(
        context,
        error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Unable to fetch your location right now.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _applyMapResult(AddressMapPickerResult result) async {
    _ResolvedLocationData? fallback;
    if (_needsFallbackReverseGeocode(result)) {
      fallback = await _reverseGeocodePoint(result.point);
    }

    if (!mounted) {
      return;
    }

    final resolvedCity = _firstNonEmpty(<String?>[
      result.city,
      fallback?.city,
      _city,
    ]);
    final resolvedState = _firstNonEmpty(<String?>[
      result.state,
      fallback?.state,
      _state,
    ]);
    final resolvedPincode = _firstNonEmpty(<String?>[
      result.pincode,
      fallback?.pincode,
      _pincode,
    ]);
    final resolvedDisplayName = _firstNonEmpty(<String?>[
      result.displayName,
      fallback?.displayName,
    ]);
    final resolvedLine1 = _firstNonEmpty(<String?>[
      result.addressLine1,
      fallback?.addressLine1,
    ]);
    final resolvedLine2 = _firstNonEmpty(<String?>[
      result.addressLine2,
      fallback?.addressLine2,
    ]);

    setState(() {
      _latitude = result.point.lat;
      _longitude = result.point.lng;
      _city = resolvedCity;
      _state = resolvedState;
      _pincode = resolvedPincode;
      _areaName = _deriveAreaName(
        displayName: resolvedDisplayName,
        addressLine1: resolvedLine1,
        addressLine2: resolvedLine2,
        city: resolvedCity,
      );
      _displayAddress = _composeDisplayAddress(
        displayName: resolvedDisplayName,
        addressLine1: resolvedLine1,
        addressLine2: resolvedLine2,
        city: resolvedCity,
        state: resolvedState,
        pincode: resolvedPincode,
      );
    });

    _schedulePincodeValidation(resolvedPincode);
  }

  bool _needsFallbackReverseGeocode(AddressMapPickerResult result) {
    return <String?>[
      result.displayName,
      result.addressLine1,
      result.addressLine2,
      result.city,
      result.state,
      result.pincode,
    ].every((value) => (value ?? '').trim().isEmpty);
  }

  Future<_ResolvedLocationData?> _reverseGeocodePoint(GeoPoint point) async {
    try {
      final placemarks = await placemarkFromCoordinates(point.lat, point.lng);
      if (placemarks.isEmpty) {
        return null;
      }
      final place = placemarks.first;
      return _ResolvedLocationData(
        displayName: <String>[
          if ((place.subLocality ?? '').trim().isNotEmpty)
            place.subLocality!.trim(),
          if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
          if ((place.administrativeArea ?? '').trim().isNotEmpty)
            place.administrativeArea!.trim(),
        ].join(', '),
        addressLine1: _firstNonEmpty(<String?>[
          place.name,
          place.street,
        ]),
        addressLine2: _firstNonEmpty(<String?>[
          place.subLocality,
          place.thoroughfare,
        ]),
        city: _firstNonEmpty(<String?>[
          place.locality,
          place.subAdministrativeArea,
        ]),
        state: place.administrativeArea?.trim(),
        pincode: place.postalCode?.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  void _schedulePincodeValidation(String? pincode) {
    final normalized = (pincode ?? '').trim();
    _pincodeDebouncer.cancel();

    if (normalized.isEmpty) {
      setState(() {
        _pincodeStatus = _PincodeValidationStatus.idle;
        _pincodeMessage = 'Pick a precise pin to detect city and pincode.';
      });
      return;
    }

    final formatError = Validators.validatePincode(normalized);
    if (formatError != null) {
      setState(() {
        _pincodeStatus = _PincodeValidationStatus.invalid;
        _pincodeMessage = formatError;
      });
      return;
    }

    final requestId = ++_pincodeRequestId;
    setState(() {
      _pincodeStatus = _PincodeValidationStatus.loading;
      _pincodeMessage = 'Checking delivery availability...';
    });

    _pincodeDebouncer.run(() {
      unawaited(_validatePincode(normalized, requestId));
    });
  }

  Future<void> _validatePincode(String pincode, int requestId) async {
    final result = await ref.read(validatePincodeUseCaseProvider).call(pincode);
    if (!mounted || requestId != _pincodeRequestId || pincode != _pincode) {
      return;
    }

    result.fold(
      (failure) {
        setState(() {
          _pincodeStatus = _PincodeValidationStatus.invalid;
          _pincodeMessage = failure.message;
        });
      },
      (validation) {
        setState(() {
          if (validation.available) {
            _pincodeStatus = _PincodeValidationStatus.valid;
            _pincodeMessage =
                'Delivery available in ${validation.estimatedMin} mins';
          } else {
            _pincodeStatus = _PincodeValidationStatus.invalid;
            _pincodeMessage = 'Delivery is not available at this pin yet.';
          }
        });
      },
    );
  }

  Future<void> _prefillReceiverFromAccount() async {
    final authState = ref.read(authStateProvider);
    if (authState case AuthAuthenticated(:final user)) {
      var changed = false;
      if (_receiverNameController.text.trim().isEmpty &&
          (user.name ?? '').trim().isNotEmpty) {
        _receiverNameController.text = user.name!.trim();
        changed = true;
      }
      if (_receiverPhoneController.text.trim().isEmpty &&
          user.phone.trim().isNotEmpty) {
        _receiverPhoneController.text = _sanitizePhone(user.phone);
        changed = true;
      }
      if (changed) {
        setState(() {});
        return;
      }
      AppToast.show(context, '✅ Receiver details are already filled.', type: ToastType.info);
      return;
    }

    AppToast.show(context, 'ℹ️ Add receiver details manually.', type: ToastType.info);
  }

  Future<void> _saveAddress() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasPinnedLocation) {
      AppToast.show(context, '📍 Pick the delivery pin before saving this address.', type: ToastType.warning);
      return;
    }

    if (_pincodeStatus != _PincodeValidationStatus.valid ||
        (_city ?? '').trim().isEmpty ||
        (_state ?? '').trim().isEmpty ||
        (_pincode ?? '').trim().isEmpty) {
      AppToast.show(context, '📍 Choose a valid delivery pin to continue.', type: ToastType.warning);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final params = AddressUpsertParams(
      label: _selectedLabel,
      addressLine1: _addressLine1Controller.text.trim(),
      addressLine2: _composeSecondaryAddress(),
      receiverName: _emptyToNull(_receiverNameController.text),
      receiverPhone: _receiverPhoneValue,
      city: _city!.trim(),
      state: _state!.trim(),
      pincode: _pincode!.trim(),
      latitude: _latitude,
      longitude: _longitude,
      isDefault: widget.initialAddress?.isDefault ?? false,
    );

    final result = _isEditing
        ? await ref
            .read(addressProvider.notifier)
            .updateAddress(widget.initialAddress!.id, params)
        : await ref.read(addressProvider.notifier).createAddress(params);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (!result.isSuccess) {
      AppToast.show(
        context,
        result.failure?.message ?? 'Unable to save this address right now.',
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  String? get _receiverPhoneValue {
    final digits = _sanitizePhone(_receiverPhoneController.text);
    return digits.isEmpty ? null : digits;
  }

  String? _composeSecondaryAddress() {
    final parts = <String>[
      _buildingController.text.trim(),
      _landmarkController.text.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);

    if (parts.isEmpty) {
      return null;
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = _areaName ?? 'Choose your delivery pin';
    final headerSubtitle = _displayAddress ??
        'Pick your exact building or gate on the map to auto-fill city, state and pincode.';

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
            PhosphorIcons.caretLeftBold,
            size: 20.sp,
            color: AppColors.textPrimary,
          ),
        ),
        title: Text('Add Address Details', style: AppTextStyles.h2),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[AppShadows.floatingShadow],
          ),
          child: SizedBox(
            height: 52.h,
            child: FilledButton(
              onPressed: _canSave ? _saveAddress : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                disabledBackgroundColor: const Color(0xFFE8E8E8),
                disabledForegroundColor: AppColors.textTertiary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'SAVE ADDRESS',
                      style: AppTextStyles.buttonLarge.copyWith(
                        color:
                            _canSave ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 120.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  color: Colors.white,
                  child: Column(
                    children: <Widget>[
                      _CompactMapPreview(
                        point: _previewPoint,
                        hasPinnedLocation: _hasPinnedLocation,
                        isLocating: _isLocating,
                        onCurrentLocationTap: _openMapPickerFromCurrentLocation,
                      ),
                      _AddressHeader(
                        areaName: headerTitle,
                        address: headerSubtitle,
                        buttonLabel: _hasPinnedLocation ? 'Change' : 'Pick',
                        statusMessage: _pincodeMessage,
                        statusColor: switch (_pincodeStatus) {
                          _PincodeValidationStatus.valid =>
                            AppColors.primaryGreen,
                          _PincodeValidationStatus.invalid =>
                            AppColors.errorRed,
                          _PincodeValidationStatus.loading =>
                            AppColors.textSecondary,
                          _PincodeValidationStatus.idle =>
                            AppColors.textSecondary,
                        },
                        onChangeTap: _openMapPicker,
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 0),
                  child: Text(
                    'Add Address',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontFamily: 'Poppins',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _FormField(
                        controller: _addressLine1Controller,
                        label: 'House No. & Floor *',
                        textInputAction: TextInputAction.next,
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'House no. and floor are required.';
                          }
                          return null;
                        },
                      ),
                      Gap(12.h),
                      _FormField(
                        controller: _buildingController,
                        label: 'Building & Block No. (Optional)',
                        textInputAction: TextInputAction.next,
                      ),
                      Gap(12.h),
                      _FormField(
                        controller: _landmarkController,
                        label: 'Landmark & Area Name (Optional)',
                        textInputAction: TextInputAction.next,
                      ),
                      Gap(20.h),
                      Text(
                        'Add Address Label',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontFamily: 'Poppins',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Gap(12.h),
                      _LabelChipSelector(
                        labels: _labels,
                        selectedLabel: _selectedLabel,
                        onSelected: (String label) {
                          setState(() {
                            _selectedLabel = label;
                          });
                        },
                      ),
                      Gap(22.h),
                      _ReceiverSection(
                        nameController: _receiverNameController,
                        phoneController: _receiverPhoneController,
                        onContactTap: _prefillReceiverFromAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactMapPreview extends StatelessWidget {
  const _CompactMapPreview({
    required this.point,
    required this.hasPinnedLocation,
    required this.isLocating,
    required this.onCurrentLocationTap,
  });

  final GeoPoint point;
  final bool hasPinnedLocation;
  final bool isLocating;
  final VoidCallback onCurrentLocationTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180.h,
      child: Stack(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppDimensions.radiusXl.r),
            ),
            child: FlutterMap(
              key: ValueKey<String>('map-${point.lat}-${point.lng}'),
              options: MapOptions(
                initialCenter: map.LatLng(point.lat, point.lng),
                initialZoom: hasPinnedLocation ? 16 : 13.6,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bakaloo.india',
                  maxNativeZoom: 19,
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: map.LatLng(point.lat, point.lng),
                      width: 42.w,
                      height: 42.w,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          PhosphorIcon(
                            PhosphorIcons.mapPinFill,
                            size: 32.sp,
                            color: AppColors.cartPink,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 12.h,
            right: 12.w,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onCurrentLocationTap,
                child: SizedBox(
                  width: 36.w,
                  height: 36.w,
                  child: Center(
                    child: isLocating
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textSecondary,
                              ),
                            ),
                          )
                        : PhosphorIcon(
                            PhosphorIcons.crosshairSimpleBold,
                            size: 18.sp,
                            color: AppColors.textSecondary,
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (!hasPinnedLocation)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 16.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  boxShadow: const <BoxShadow>[AppShadows.cardShadow],
                ),
                child: Text(
                  'Map preview is centered on Kolkata until you pick your exact delivery spot.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddressHeader extends StatelessWidget {
  const _AddressHeader({
    required this.areaName,
    required this.address,
    required this.buttonLabel,
    required this.onChangeTap,
    this.statusMessage,
    this.statusColor,
  });

  final String areaName;
  final String address;
  final String buttonLabel;
  final VoidCallback onChangeTap;
  final String? statusMessage;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
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
                  address,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
                if ((statusMessage ?? '').trim().isNotEmpty) ...<Widget>[
                  Gap(8.h),
                  Text(
                    statusMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: statusColor ?? AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Gap(12.w),
          OutlinedButton(
            onPressed: onChangeTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderLight),
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
            child: Text(
              buttonLabel,
              style: AppTextStyles.buttonSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.prefix,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLength: maxLength,
      style: AppTextStyles.bodyLarge.copyWith(
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF0F4F8),
        prefixIcon: prefix,
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(
            color: AppColors.borderFocus,
            width: 1.2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(
            color: AppColors.errorRed,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

class _LabelChipSelector extends StatelessWidget {
  const _LabelChipSelector({
    required this.labels,
    required this.selectedLabel,
    required this.onSelected,
  });

  final List<String> labels;
  final String selectedLabel;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: labels.map((String label) {
        final isSelected = label == selectedLabel;
        return GestureDetector(
          onTap: () => onSelected(label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              border: Border.all(
                color:
                    isSelected ? AppColors.textPrimary : AppColors.borderLight,
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.buttonSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _ReceiverSection extends StatelessWidget {
  const _ReceiverSection({
    required this.nameController,
    required this.phoneController,
    required this.onContactTap,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onContactTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Receiver Details',
          style: AppTextStyles.labelLarge.copyWith(
            fontFamily: 'Poppins',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        Gap(12.h),
        _FormField(
          controller: nameController,
          label: "Receiver's Name",
          textInputAction: TextInputAction.next,
          suffixIcon: IconButton(
            onPressed: onContactTap,
            icon: Icon(
              Icons.contact_page_outlined,
              size: 20.sp,
              color: const Color(0xFF6B7B8C),
            ),
          ),
        ),
        Gap(12.h),
        _FormField(
          controller: phoneController,
          label: "Receiver's Phone Number",
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          validator: (String? value) {
            final digits = _sanitizePhone(value ?? '');
            if (digits.isEmpty) {
              return null;
            }
            if (digits.length != 10) {
              return 'Enter a valid 10-digit phone number.';
            }
            return null;
          },
          prefix: Padding(
            padding: EdgeInsets.only(left: 16.w, right: 8.w),
            child: Center(
              widthFactor: 1,
              child: Text(
                '+91',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _PincodeValidationStatus {
  idle,
  loading,
  valid,
  invalid,
}

class _ResolvedLocationData {
  const _ResolvedLocationData({
    this.displayName,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
  });

  final String? displayName;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
}

(String, String) _splitSecondaryAddress(String? rawValue) {
  final value = (rawValue ?? '').trim();
  if (value.isEmpty) {
    return ('', '');
  }

  final parts = value
      .split(',')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);

  if (parts.length <= 1) {
    return (value, '');
  }

  return (parts.first, parts.sublist(1).join(', '));
}

String _normalizeLabel(String rawLabel) {
  final normalized = rawLabel.trim().toLowerCase();
  if (normalized.contains('work') || normalized.contains('office')) {
    return 'Work';
  }
  if (normalized.contains('other')) {
    return 'Other';
  }
  return 'Home';
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

String _deriveAreaName({
  required String? displayName,
  required String? addressLine1,
  required String? addressLine2,
  required String? city,
}) {
  final display = (displayName ?? '').trim();
  if (display.isNotEmpty) {
    return display.split(',').first.trim();
  }
  return _firstNonEmpty(<String?>[
        addressLine2,
        city,
        addressLine1,
      ]) ??
      'Selected location';
}

String _composeDisplayAddress({
  required String? displayName,
  required String? addressLine1,
  required String? addressLine2,
  required String? city,
  required String? state,
  required String? pincode,
}) {
  final display = (displayName ?? '').trim();
  if (display.isNotEmpty) {
    return display;
  }
  return <String>[
    if ((addressLine2 ?? '').trim().isNotEmpty) addressLine2!.trim(),
    if ((addressLine1 ?? '').trim().isNotEmpty) addressLine1!.trim(),
    if ((city ?? '').trim().isNotEmpty) city!.trim(),
    if ((state ?? '').trim().isNotEmpty) state!.trim(),
    if ((pincode ?? '').trim().isNotEmpty) pincode!.trim(),
  ].join(', ');
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _sanitizePhone(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}
