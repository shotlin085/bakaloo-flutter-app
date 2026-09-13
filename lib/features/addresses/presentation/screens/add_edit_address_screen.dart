import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/maps/ola/ola_maps_service.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/utils/debouncer.dart';
import 'package:bakaloo_flutter_app/core/utils/location_service_resolver.dart';
import 'package:bakaloo_flutter_app/core/utils/resilient_location.dart';
import 'package:bakaloo_flutter_app/core/utils/validators.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/screens/address_map_picker_screen.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/widgets/location_permission_denied_dialog.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/providers/profile_provider.dart';

class AddEditAddressScreen extends ConsumerStatefulWidget {
  const AddEditAddressScreen({
    this.initialAddress,
    this.forceCompletion = false,
    super.key,
  });

  final AddressEntity? initialAddress;

  /// True when this screen is the required next step right after location
  /// auto-detect silently saved an address from reverse geocoding alone —
  /// that only ever knows the street/area, never a house or building
  /// number, so this step isn't optional the way editing an
  /// already-complete address normally would be. Hides the back button and
  /// blocks the Android back gesture; "SAVE ADDRESS" (already disabled
  /// until House No. is filled) is the only way out.
  final bool forceCompletion;

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
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _houseNoController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _receiverPhoneController =
      TextEditingController();
  final Debouncer _pincodeDebouncer = Debouncer(
    delay: const Duration(milliseconds: 350),
  );

  String _selectedLabel = 'Home';
  double? _latitude;
  double? _longitude;
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
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty &&
      _houseNoController.text.trim().isNotEmpty &&
      _cityController.text.trim().isNotEmpty &&
      _stateController.text.trim().isNotEmpty &&
      _pincodeStatus == _PincodeValidationStatus.valid;

  @override
  void initState() {
    super.initState();
    // The global Smart Bottom Bar (cart/milestone pill) sits in a Stack
    // above every routed page regardless of which screen is showing, and
    // this is the one existing flag it already checks to hide itself (see
    // app_bottom_nav.dart) — previously only address_bottom_sheet.dart set
    // it, so this full-page address flow never engaged it and the pill
    // rendered on top of this screen's own bottom-docked Save/Confirm
    // button, sometimes covering it entirely. AddressMapPickerScreen is
    // only ever pushed from this screen and never disposes it while doing
    // so, so this one flag correctly covers that child screen too — no
    // separate on/off pair needed there.
    addressSheetVisible.value = true;
    _seedFromInitialAddress();
    _addressController.addListener(_handleFormStateChanged);
    _houseNoController.addListener(_handleFormStateChanged);
    _firstNameController.addListener(_handleFormStateChanged);
    _lastNameController.addListener(_handleFormStateChanged);
    _cityController.addListener(_handleCityTextChanged);
    _stateController.addListener(_handleStateTextChanged);
    _pincodeController.addListener(_handlePincodeTextChanged);
    if ((_pincode ?? '').trim().isNotEmpty) {
      _schedulePincodeValidation(_pincode);
    }

    // A brand-new address has no pin yet — most first-time customers don't
    // know they need to tap the crosshair button on the map, so auto-fire
    // the exact same current-location flow that button triggers as soon as
    // this screen opens. Geolocator only shows the system prompt when
    // permission is still undetermined; if it's already granted this
    // resolves silently with no dialog. The user still lands on the map
    // picker to confirm/adjust the pin before anything is saved.
    if (!_isEditing && !_hasPinnedLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_openMapPickerFromCurrentLocation());
        }
      });
    }

    // The completion screen's pin is already dropped (from the silent
    // auto-detect that got the customer here), so this doesn't need the map
    // picker at all — just one more Ola reverse-geocode call for Landmark,
    // the one field that flow never persists (see _seedFromInitialAddress
    // above). Also backfills Address if it's still blank — covers an
    // address record saved before this fix existed, when the old OS-geocoder
    // path could leave addressLine1 empty too.
    if (widget.forceCompletion && _hasPinnedLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_refreshDetailsForCompletion());
        }
      });
    }
  }

  Future<void> _refreshDetailsForCompletion() async {
    final reverse = await ref.read(olaMapsServiceProvider).reverseGeocode(
          GeoPoint(lat: _latitude!, lng: _longitude!),
        );
    if (!mounted) {
      return;
    }

    final landmark = reverse?.landmark?.trim() ?? '';
    // Prefer a proper road/street name; a bare city name is not a usable
    // address (Ola simply had no road for this pin) — the full formatted
    // address is still specific to this exact point, just without a named
    // road, so it's the better fallback of the two.
    final address = _firstNonEmpty(<String?>[
      reverse?.addressLine1,
      reverse?.displayName,
    ]) ??
        '';

    // Runs once, right as the screen opens, before the customer has had a
    // chance to type anything — so it's safe to unconditionally replace
    // whatever was seeded from the persisted address record, including a
    // stale/bad value from before this fix existed (e.g. a bare city name
    // that got saved as the address itself).
    setState(() {
      if (landmark.isNotEmpty) {
        _landmarkController.text = landmark;
      }
      if (address.isNotEmpty) {
        _addressController.text = address;
      }
    });
  }

  @override
  void dispose() {
    _addressController
      ..removeListener(_handleFormStateChanged)
      ..dispose();
    _houseNoController
      ..removeListener(_handleFormStateChanged)
      ..dispose();
    _firstNameController
      ..removeListener(_handleFormStateChanged)
      ..dispose();
    _lastNameController
      ..removeListener(_handleFormStateChanged)
      ..dispose();
    _cityController
      ..removeListener(_handleCityTextChanged)
      ..dispose();
    _stateController
      ..removeListener(_handleStateTextChanged)
      ..dispose();
    _pincodeController
      ..removeListener(_handlePincodeTextChanged)
      ..dispose();
    _buildingController.dispose();
    _landmarkController.dispose();
    _receiverPhoneController.dispose();
    _pincodeDebouncer.dispose();
    addressSheetVisible.value = false;
    super.dispose();
  }

  void _seedFromInitialAddress() {
    final authState = ref.read(authStateProvider);
    final accountName = switch (authState) {
      AuthAuthenticated(:final user) => user.name?.trim(),
      _ => null,
    };
    final accountPhone = switch (authState) {
      AuthAuthenticated(:final user) => user.phone.trim(),
      _ => null,
    };

    final address = widget.initialAddress;
    if (address == null) {
      // A brand-new address for a returning customer who already has a
      // name on file — pre-fill First/Last Name from the account so they
      // only have to fill in the fields that are actually new for this
      // location (house/block, landmark, etc.), not retype their name
      // every time. Left blank for a genuinely new user; the fields are
      // required, so they can't save without filling them in at least
      // once — see _saveAddress, which then saves that as the account's
      // default name.
      final nameParts = _splitFullName(accountName);
      _firstNameController.text = nameParts.$1;
      _lastNameController.text = nameParts.$2;
      if ((accountPhone ?? '').isNotEmpty) {
        _receiverPhoneController.text = _sanitizePhone(accountPhone!);
      }
      return;
    }

    _selectedLabel = _normalizeLabel(address.label);
    if (widget.forceCompletion) {
      // Auto-detected via the "Use my current location" flow (see
      // location_prompt_provider.dart), which now reverse-geocodes through
      // Ola Maps: Address is trustworthy enough to pre-fill here too.
      // addressLine2 is deliberately never persisted for this kind of
      // address (see location_prompt_provider.dart's _geocodeAndSave) — a
      // non-empty addressLine2 is how the rest of the app knows House No.
      // was actually filled in — so Landmark is fetched live instead, see
      // _fetchLandmarkForCompletion below. House No. and Building are the
      // only things genuinely unknown at this point — no reverse geocode
      // ever names those — so they stay blank; that's exactly what makes
      // this screen mandatory.
      _addressController.text = address.addressLine1;
    } else {
      final secondaryParts = _splitSecondaryAddress(address.addressLine2);
      _addressController.text = address.addressLine1;
      _houseNoController.text = secondaryParts.$1;
      _buildingController.text = secondaryParts.$2;
      _landmarkController.text = secondaryParts.$3;
    }
    final nameParts = _splitFullName(_firstNonEmpty(<String?>[
      address.receiverName,
      accountName,
      address.name,
    ]));
    _firstNameController.text = nameParts.$1;
    _lastNameController.text = nameParts.$2;
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
    _cityController.text = _city!;
    _stateController.text = _state!;
    _pincodeController.text = _pincode!;
    _latitude = address.latitude;
    _longitude = address.longitude;
  }

  void _handleFormStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // City/State/Pincode are pre-filled from the map pick but stay fully
  // editable — these listeners keep the underlying _city/_state/_pincode
  // state (used by save + the existing pincode-availability check) in sync
  // with whatever the user actually typed, so a manual correction is what
  // actually gets validated and saved, not the original geocoded guess.
  void _handleCityTextChanged() {
    final value = _cityController.text;
    if (value == _city) return;
    setState(() {
      _city = value;
    });
  }

  void _handleStateTextChanged() {
    final value = _stateController.text;
    if (value == _state) return;
    setState(() {
      _state = value;
    });
  }

  void _handlePincodeTextChanged() {
    final value = _pincodeController.text;
    if (value == _pincode) return;
    setState(() {
      _pincode = value;
    });
    _schedulePincodeValidation(value);
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
      // Deliberately geolocator end-to-end, matching every other location
      // call-site in this app (address_map_picker_screen.dart,
      // location_prompt_provider.dart, etc). This used to go through
      // permission_handler instead — the only call to it anywhere in
      // lib/ — and mixing it with geolocator was the root cause of a real
      // iOS-only bug: permission_handler and geolocator each stand up their
      // own separate native CLLocationManager/delegate, and two of those
      // racing for the same one-shot iOS authorization prompt could leave
      // the request never resolving and the system dialog never appearing
      // at all — while Android has no equivalent failure mode, since
      // permission results there broadcast through
      // Activity.onRequestPermissionsResult, which multiple plugins can
      // listen to independently. Reported: "iOS not working... Android
      // perfectly working."
      //
      // resolveLocationPermission also handles the deniedForever case —
      // iOS makes a single denial permanent, so its system prompt above
      // will never appear again for this install — by offering a Settings
      // dialog and, if taken, waiting for the customer to actually come
      // back before re-checking, so granting it there is picked up
      // immediately instead of requiring a second tap of this same
      // button. Reported: "next time not... coming... enable automatic...
      // location pop-up... that also pop-up not coming."
      final permission = await resolveLocationPermission(context);
      if (!mounted) {
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        // Customer either dismissed the Settings dialog or came back still
        // denied — resolveLocationPermission already gave them the one
        // chance to fix it; nothing left to do without looping a second
        // dialog on them right away.
        return;
      }

      if (permission == LocationPermission.denied) {
        AppToast.show(context,
            '📍 Location permission is required to detect your location.',
            type: ToastType.warning);
        return;
      }

      var serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) {
        return;
      }
      if (!serviceEnabled) {
        // Show the native "Turn on Location Accuracy" resolution dialog
        // in-app (Android) instead of just telling the customer to go turn
        // it on themselves — same Blinkit/Zomato-style fix already applied
        // to location_prompt_sheet.dart, which this "use current location"
        // button on the address form never got.
        serviceEnabled = await requestEnableLocationService();
        if (!mounted) {
          return;
        }
        if (!serviceEnabled) {
          AppToast.show(
              context, '📍 Turn on location services and try again.',
              type: ToastType.warning);
          return;
        }
      }

      final position = await getResilientCurrentPosition();

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
    if (!mounted) {
      return;
    }

    final resolvedAddress = _firstNonEmpty(<String?>[
      result.addressLine1,
      result.displayName,
    ]);
    final resolvedCity = _firstNonEmpty(<String?>[result.city, _city]);
    final resolvedState = _firstNonEmpty(<String?>[result.state, _state]);
    final resolvedPincode = _firstNonEmpty(<String?>[result.pincode, _pincode]);

    setState(() {
      _latitude = result.point.lat;
      _longitude = result.point.lng;
      _city = resolvedCity;
      _state = resolvedState;
      _pincode = resolvedPincode;
      // Address, City and State/PIN Code all come straight from Ola Maps'
      // reverse-geocode result on every pin drop now — House No., Building
      // and Landmark are the details Ola can never know, so those stay
      // manual (Landmark is only pre-filled below when Ola actually names a
      // nearby place, and only if the customer hasn't typed one already).
      if ((resolvedAddress ?? '').isNotEmpty) {
        _addressController.text = resolvedAddress!;
      }
      _cityController.text = resolvedCity ?? '';
      _stateController.text = resolvedState ?? '';
      _pincodeController.text = resolvedPincode ?? '';
      final landmark = result.landmark?.trim() ?? '';
      if (landmark.isNotEmpty && _landmarkController.text.trim().isEmpty) {
        _landmarkController.text = landmark;
      }
    });

    _schedulePincodeValidation(resolvedPincode);
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
            _applyPincodeMappingOverride(validation);
          } else {
            _pincodeStatus = _PincodeValidationStatus.invalid;
            _pincodeMessage = 'Delivery is not available at this pin yet.';
          }
        });
      },
    );
  }

  // Admin-curated override (dashboard: Settings -> Pincode Mapping) — only
  // populated when this exact pincode has an ACTIVE mapping row. Unlike the
  // reverse-geocoded guess (which is deliberately never used to fill City,
  // see _applyMapResult above), this data is admin-verified, so City is
  // safe to auto-fill here — this is precisely how known-wrong geocode
  // results (e.g. some Gujarat pincodes resolving to the wrong city) get
  // corrected for customers. Landmark is only filled when still empty, so a
  // user's own note isn't overwritten.
  void _applyPincodeMappingOverride(PincodeValidationResult validation) {
    final mappedCity = validation.city?.trim();
    if ((mappedCity ?? '').isNotEmpty) {
      _city = mappedCity;
      _cityController.text = mappedCity!;
    }
    final mappedState = validation.state?.trim();
    if ((mappedState ?? '').isNotEmpty) {
      _state = mappedState;
      _stateController.text = mappedState!;
    }
    final mappedArea = validation.area?.trim();
    if ((mappedArea ?? '').isNotEmpty &&
        _landmarkController.text.trim().isEmpty) {
      _landmarkController.text = mappedArea!;
    }
  }

  Future<void> _prefillPhoneFromAccount() async {
    final authState = ref.read(authStateProvider);
    if (authState case AuthAuthenticated(:final user)) {
      if (_receiverPhoneController.text.trim().isEmpty &&
          user.phone.trim().isNotEmpty) {
        _receiverPhoneController.text = _sanitizePhone(user.phone);
        setState(() {});
        return;
      }
      AppToast.show(context, '✅ Phone number is already filled.',
          type: ToastType.info);
      return;
    }

    AppToast.show(context, 'ℹ️ Add the phone number manually.',
        type: ToastType.info);
  }

  Future<void> _saveAddress() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasPinnedLocation) {
      AppToast.show(
          context, '📍 Pick the delivery pin before saving this address.',
          type: ToastType.warning);
      return;
    }

    if (_pincodeStatus != _PincodeValidationStatus.valid ||
        (_city ?? '').trim().isEmpty ||
        (_state ?? '').trim().isEmpty ||
        (_pincode ?? '').trim().isEmpty) {
      AppToast.show(context, '📍 Choose a valid delivery pin to continue.',
          type: ToastType.warning);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final fullName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();

    // First time this account provides a name (whether that's the very
    // first address ever, or an older account that predates this field),
    // save it as the account's own default display name — the backend
    // refuses to place an order for a nameless account regardless
    // (NAME_REQUIRED, orders.service.js#placeOrder), so this is what
    // actually satisfies that requirement now that there's no separate
    // onboarding prompt for it. A later address with a different
    // recipient name (e.g. an office receptionist) deliberately does NOT
    // overwrite it again — this only ever fires once, the first time the
    // account name is missing.
    final authState = ref.read(authStateProvider);
    final hasAccountName = switch (authState) {
      AuthAuthenticated(:final user) => (user.name ?? '').trim().isNotEmpty,
      _ => true,
    };
    if (!hasAccountName && fullName.isNotEmpty) {
      try {
        await ref.read(profileProvider.notifier).updateProfile(name: fullName);
      } catch (_) {
        // Best-effort — never let a profile-name hiccup block saving the
        // address itself. The backend's own NAME_REQUIRED check at
        // checkout is the real backstop if this happens to fail.
      }
    }

    final params = AddressUpsertParams(
      label: _selectedLabel,
      addressLine1: _addressController.text.trim(),
      addressLine2: _composeSecondaryAddress(),
      receiverName: _emptyToNull(fullName),
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
      _houseNoController.text.trim(),
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
    // iOS has no hardware/gesture back button to fall back on, and this
    // screen's SAVE ADDRESS button used to live in bottomNavigationBar,
    // which Scaffold does not reposition above the software keyboard — so
    // once it was covered (e.g. the numeric keypad for PIN Code / phone),
    // tapping elsewhere on the form was the only other way to dismiss it,
    // and this screen never actually wired that up either. Reported:
    // customer stuck with the keyboard covering Save, unable to close it by
    // tapping anywhere. Fixed three ways: tapping outside a field now
    // unfocuses via the GestureDetector below, a keyboard-hide icon in the
    // AppBar (never covered by the keyboard) is a second always-visible way
    // to close it, and SAVE ADDRESS itself is no longer in
    // bottomNavigationBar at all — it's an AnimatedPositioned that floats
    // directly above the keyboard and slides back down when it closes.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !widget.forceCompletion,
      child: Scaffold(
        // Scaffold's own keyboard-avoidance (on by default) already shrinks
        // this screen's body to end exactly at the keyboard's top edge —
        // stacking the AnimatedPositioned's own `bottom: bottomInset` on top
        // of that double-counts the keyboard height and shoves SAVE ADDRESS
        // toward the top of the screen instead of sitting on the keyboard.
        // Turning this off hands keyboard avoidance entirely to the
        // AnimatedPositioned below, which already accounts for it correctly.
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          leading: widget.forceCompletion
              ? null
              : IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: PhosphorIcon(
                    PhosphorIcons.caretLeftBold,
                    size: 20.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
          title: Text('Add Address Details', style: AppTextStyles.h2),
          actions: <Widget>[
            IconButton(
              onPressed: () => FocusScope.of(context).unfocus(),
              icon: Icon(
                Icons.keyboard_hide_rounded,
                size: 22.sp,
                color: AppColors.orderViolet,
              ),
            ),
          ],
        ),
        body: Stack(
          children: <Widget>[
            GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            // resizeToAvoidBottomInset is off (see comment above), so this
            // scroll view's viewport never actually shrinks when the
            // keyboard opens — without the extra bottomInset here, there is
            // no genuine scrollable room below a lower field for
            // Scrollable.ensureVisible (in _FormField) to scroll into, and
            // it silently does nothing. Reported: focusing Receiver's Phone
            // Number left it hidden behind the keyboard with only the
            // floating SAVE ADDRESS button visible above it.
            padding: EdgeInsets.only(bottom: 120.h + bottomInset),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    color: Colors.white,
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 0),
                          child: _FullNameSection(
                            firstNameController: _firstNameController,
                            lastNameController: _lastNameController,
                          ),
                        ),
                        _AddressHeader(
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
                          controller: _houseNoController,
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
                          controller: _addressController,
                          label: 'Address *',
                          textInputAction: TextInputAction.next,
                          validator: (String? value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Address is required.';
                            }
                            return null;
                          },
                        ),
                        Gap(12.h),
                        _FormField(
                          controller: _landmarkController,
                          label: 'Landmark & Area Name (Optional)',
                          textInputAction: TextInputAction.next,
                        ),
                        Gap(12.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: _FormField(
                                controller: _cityController,
                                label: 'City *',
                                textInputAction: TextInputAction.next,
                                validator: (String? value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'City is required.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            Gap(12.w),
                            Expanded(
                              child: _FormField(
                                controller: _pincodeController,
                                label: 'PIN Code *',
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                maxLength: 6,
                                validator: (String? value) {
                                  final trimmed = (value ?? '').trim();
                                  if (trimmed.isEmpty) {
                                    return 'PIN code is required.';
                                  }
                                  return Validators.validatePincode(trimmed);
                                },
                              ),
                            ),
                          ],
                        ),
                        Gap(12.h),
                        _FormField(
                          controller: _stateController,
                          label: 'State *',
                          textInputAction: TextInputAction.done,
                          validator: (String? value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'State is required.';
                            }
                            return null;
                          },
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
                          phoneController: _receiverPhoneController,
                          onContactTap: _prefillPhoneFromAccount,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
            ),
            // Floats directly above the software keyboard, sliding smoothly
            // back down to the screen edge when it closes — bottomNavigationBar
            // does not reposition above the keyboard on its own, so without
            // this SAVE ADDRESS was left hidden behind it (reported: numeric
            // keypad for PIN Code / phone covering Save with no way to reach
            // it except dismissing the keyboard first).
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              bottom: bottomInset,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  12.h,
                  16.w,
                  12.h + (bottomInset == 0 ? MediaQuery.of(context).padding.bottom : 0),
                ),
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'SAVE ADDRESS',
                            style: AppTextStyles.buttonLarge.copyWith(
                              color: _canSave
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full Name — required, shown at the top of the form (see AddEditAddressScreen
/// docs). This is what actually collects the account's display name now
/// that there's no separate onboarding popup for it (see home_screen.dart):
/// the first time an account has no name on file, saving any address with
/// these fields filled in also sets it as the account's own name. Pre-filled
/// from that same account name on every later address, so a returning
/// customer only has to fill in what's actually new for that location.
class _FullNameSection extends StatelessWidget {
  const _FullNameSection({
    required this.firstNameController,
    required this.lastNameController,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Your Name',
          style: AppTextStyles.labelLarge.copyWith(
            fontFamily: 'Poppins',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        Gap(12.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _FormField(
                controller: firstNameController,
                label: 'First Name *',
                textInputAction: TextInputAction.next,
                validator: (String? value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'First name is required.';
                  }
                  return null;
                },
              ),
            ),
            Gap(12.w),
            Expanded(
              child: _FormField(
                controller: lastNameController,
                label: 'Last Name *',
                textInputAction: TextInputAction.next,
                validator: (String? value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Last name is required.';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddressHeader extends StatelessWidget {
  const _AddressHeader({
    required this.buttonLabel,
    required this.onChangeTap,
    this.statusMessage,
    this.statusColor,
  });

  final String buttonLabel;
  final VoidCallback onChangeTap;
  final String? statusMessage;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: (statusMessage ?? '').trim().isNotEmpty
                ? Text(
                    statusMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: statusColor ?? AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : const SizedBox.shrink(),
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

class _FormField extends StatefulWidget {
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
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  // Light-purple highlight for an empty box — a quiet nudge toward the
  // fields the customer still needs to fill in (most useful right after
  // auto-detect, which only ever seeds City/State/PIN Code, leaving House
  // No., Building, Address and Landmark blank on purpose). Listens to the
  // controller directly rather than needing extra setState calls — the
  // highlight clears itself the moment the customer types.
  static const Color _emptyHighlightFill = Color(0xFFF3E8FD);
  static const Color _emptyHighlightBorder = Color(0xFFC9A6F0);

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) return;
    // The keyboard is still animating open (and MediaQuery.viewInsets.bottom
    // hasn't settled to its final height) the instant a field gains focus —
    // ensureVisible right away would scroll against a stale/zero keyboard
    // height and land short. Waiting for the keyboard's own slide-up
    // animation (~250ms on both platforms) to finish first fixes that.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_focusNode.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    });
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final isEmpty = value.text.trim().isEmpty;
        return TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLength: widget.maxLength,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            counterText: '',
            filled: true,
            fillColor: isEmpty ? _emptyHighlightFill : const Color(0xFFF0F4F8),
            prefixIcon: widget.prefix,
            suffixIcon: widget.suffixIcon,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: isEmpty
                  ? const BorderSide(color: _emptyHighlightBorder, width: 1.2)
                  : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: isEmpty
                  ? const BorderSide(color: _emptyHighlightBorder, width: 1.2)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(
                color: isEmpty ? _emptyHighlightBorder : AppColors.borderFocus,
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
      },
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
    required this.phoneController,
    required this.onContactTap,
  });

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
          suffixIcon: IconButton(
            onPressed: onContactTap,
            icon: Icon(
              Icons.contact_page_outlined,
              size: 20.sp,
              color: const Color(0xFF6B7B8C),
            ),
          ),
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

// addressLine2 is saved as "houseNo, building, landmark" going forward, so
// edit mode restores the same three boxes from it. Addresses saved before
// the Address field existed only ever had two segments (building,
// landmark) — those legacy rows redistribute across the three boxes on
// first edit; nothing is lost, it just lands in a different box until the
// user re-saves.
(String, String, String) _splitSecondaryAddress(String? rawValue) {
  final value = (rawValue ?? '').trim();
  if (value.isEmpty) {
    return ('', '', '');
  }

  final parts = value
      .split(',')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return ('', '', '');
  }
  if (parts.length == 1) {
    return (parts[0], '', '');
  }
  if (parts.length == 2) {
    return (parts[0], parts[1], '');
  }
  return (parts[0], parts[1], parts.sublist(2).join(', '));
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

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _sanitizePhone(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

// A stored full name (account name, or an older address's single
// receiverName field) only ever came in as one string — split on the
// first space so it can seed the First/Last Name fields. A single-word
// name lands entirely in First Name, leaving Last Name blank for the user
// to fill in themselves.
(String, String) _splitFullName(String? rawValue) {
  final value = (rawValue ?? '').trim();
  if (value.isEmpty) {
    return ('', '');
  }
  final spaceIndex = value.indexOf(' ');
  if (spaceIndex == -1) {
    return (value, '');
  }
  return (
    value.substring(0, spaceIndex).trim(),
    value.substring(spaceIndex + 1).trim(),
  );
}
