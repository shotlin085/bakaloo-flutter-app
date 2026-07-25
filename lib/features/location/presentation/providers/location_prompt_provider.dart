import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bakaloo_flutter_app/core/utils/resilient_location.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';

/// Returns true if the location-enable prompt should be shown right now:
/// the user is authenticated AND has no saved address at all.
///
/// A saved address — complete or not — is handled entirely by
/// home_screen.dart's `_maybeShowLocationPrompt` without this provider:
/// once there's at least one address, whether to nudge the customer again
/// depends on whether THAT address still needs a house/building number,
/// never on the device's current permission/service state.
///
/// Previously this also returned true whenever permission was denied or
/// the location service was off, even for a customer who already had a
/// complete saved address — so toggling location off and back on (or any
/// of the several things that made the OS re-report service status, which
/// happens on plenty of ordinary refreshes/resumes) brought the "enable
/// location" sheet back every time, regardless of the fact that they had
/// nothing left to do. Reported bug: "I already filled my address... I
/// refresh the page... same location popup comes again." Having any
/// saved address at all now fully satisfies this check.
final locationPromptShouldShowProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AuthAuthenticated) return false;

  final addresses = await ref.watch(addressProvider.future);
  return addresses.isEmpty;
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

    // 3. Get the current position — see getResilientCurrentPosition's own
    // doc comment for why this isn't a single flat getCurrentPosition()
    // call (right after the customer turns location on from Settings and
    // comes back, a single attempt regularly failed with "Could not
    // detect location" because the OS's location subsystem hasn't warmed
    // back up yet).
    Position position;
    try {
      position = await getResilientCurrentPosition();
    } catch (err, stack) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          err,
          stack,
          reason: 'detectAndSaveCurrentLocation: getResilientCurrentPosition '
              'exhausted every fallback with no position to fall back on',
          fatal: false,
        ),
      );
      return LocationAutoDetectResult.unknown;
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
