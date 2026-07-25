import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bakaloo_flutter_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';

/// Returns true if the location prompt should be shown right now:
///   - User is authenticated
///   - AND either:
///       - the user has no saved address yet — the strongest signal, since
///         without one they can't even place an order, so this fires
///         regardless of permission/service state, or
///       - location isn't actually usable yet: permission not granted
///         and/or the device's location service is off
///
/// Previously this returned false the instant permission was granted,
/// without ever checking the service toggle — so a user who granted
/// permission once but later switched their device location off (or was
/// never asked for permission at all while service stayed on, which is
/// the common case on a fresh install) would never see this prompt again.
/// Location is only actually "ready" when BOTH are true.
final locationPromptShouldShowProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AuthAuthenticated) return false;

  final addresses = await ref.watch(addressProvider.future);
  if (addresses.isEmpty) return true;

  final permission = await Geolocator.checkPermission();
  final permissionGranted = permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();

  return !(permissionGranted && serviceEnabled);
});

/// Result of attempting to detect and save the user's location.
enum LocationAutoDetectResult {
  success,
  permissionDenied,
  permissionPermanentlyDenied,
  locationServiceDisabled,
  geocodingFailed,
  saveFailed,
  unknown,
}

/// Requests permission, gets a position, reverse-geocodes it, and saves it
/// as the user's default address. Used both by the sheet's own "Enable"
/// button and its auto-trigger on open — either way there's a visible
/// spinner, so a multi-second wait is fine.
///
/// Prefers the OS's cached last-known position (near-instant, no GPS
/// engagement, and accurate enough for a delivery address) before paying
/// the cost of a fresh fix, which can easily take well over 10s on a cold
/// start (indoors, weak signal) — that used to surface as a flat "could
/// not detect location" no matter how long the customer waited. Only
/// requests a fresh fix when there's no cached position at all.
Future<LocationAutoDetectResult> detectAndSaveCurrentLocation(
  WidgetRef ref,
) async {
  try {
    // 1. Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationAutoDetectResult.locationServiceDisabled;
    }

    // 2. Request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return LocationAutoDetectResult.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationAutoDetectResult.permissionPermanentlyDenied;
    }

    // 3. Prefer the cached last-known fix; only request a fresh one if
    // there's nothing cached yet.
    var position = await Geolocator.getLastKnownPosition();
    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (err, stack) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            err,
            stack,
            reason: 'detectAndSaveCurrentLocation: getCurrentPosition failed '
                'and no last-known position to fall back on',
            fatal: false,
          ),
        );
        return LocationAutoDetectResult.unknown;
      }
    }

    return _geocodeAndSave(ref, position);
  } catch (err, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        err,
        stack,
        reason: 'detectAndSaveCurrentLocation: unexpected failure',
        fatal: false,
      ),
    );
    return LocationAutoDetectResult.unknown;
  }
}

/// Reverse-geocodes [position] and saves it as the user's default address.
/// Shared tail end of both detect paths above.
Future<LocationAutoDetectResult> _geocodeAndSave(
  WidgetRef ref,
  Position position,
) async {
  List<Placemark> placemarks;
  try {
    placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
  } catch (err, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        err,
        stack,
        reason: '_geocodeAndSave: reverse geocoding failed',
        fatal: false,
      ),
    );
    return LocationAutoDetectResult.geocodingFailed;
  }

  if (placemarks.isEmpty) {
    return LocationAutoDetectResult.geocodingFailed;
  }

  final place = placemarks.first;

  // Build address parts from geocoding result
  final street = [
    place.subThoroughfare,
    place.thoroughfare,
    place.subLocality,
  ].where((s) => s != null && s.trim().isNotEmpty).join(', ');

  final addressLine1 = street.isNotEmpty
      ? street
      : place.locality ?? place.administrativeArea ?? 'My Location';

  final city = place.locality ??
      place.subAdministrativeArea ??
      place.administrativeArea ??
      '';
  final state = place.administrativeArea ?? '';
  final pincode = place.postalCode ?? '';

  // Save as default address
  final params = AddressUpsertParams(
    label: 'Home',
    addressLine1: addressLine1,
    addressLine2: place.subLocality != null && place.subLocality!.isNotEmpty
        ? place.subLocality
        : null,
    city: city,
    state: state,
    pincode: pincode,
    latitude: position.latitude,
    longitude: position.longitude,
    isDefault: true,
  );

  final result = await ref.read(addressProvider.notifier).createAddress(params);

  if (!result.isSuccess) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        StateError(result.failure?.message ?? 'unknown'),
        StackTrace.current,
        reason: '_geocodeAndSave: createAddress failed',
        fatal: false,
      ),
    );
    return LocationAutoDetectResult.saveFailed;
  }

  // Refresh addresses so cart/checkout picks up the new default
  ref.invalidate(addressProvider);

  return LocationAutoDetectResult.success;
}
