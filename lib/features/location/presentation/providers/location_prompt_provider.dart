import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bakaloo_flutter_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';

// ── Key stored in shared_prefs to remember we've shown the prompt ────────────
const String _kLocationPromptShownKey = 'location_prompt_shown_v1';

/// Returns true if the one-time location prompt should be shown:
///   - User is authenticated
///   - Never shown before
///   - Device location services are OFF (already on = no need to nag)
///   - Location permission is NOT already granted (already granted = no need)
final locationPromptShouldShowProvider = FutureProvider<bool>((ref) async {
  // Only show to authenticated users
  final authState = ref.watch(authStateProvider);
  if (authState is! AuthAuthenticated) return false;

  // Only show once
  final prefs = await SharedPreferences.getInstance();
  final alreadyShown = prefs.getBool(_kLocationPromptShownKey) ?? false;
  if (alreadyShown) return false;

  // If permission already granted, no need to prompt
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse) {
    // Already granted — mark as shown so we never prompt again
    await prefs.setBool(_kLocationPromptShownKey, true);
    return false;
  }

  // Only nag when the device's location service is actually off.
  // If it's already on, the OS permission dialog (triggered elsewhere) is
  // enough — this sheet is specifically for the "location is off" nudge.
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (serviceEnabled) return false;

  return true;
});

/// Call this to mark the prompt as shown (so it never appears again).
Future<void> markLocationPromptShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kLocationPromptShownKey, true);
}

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

/// Requests permission, gets current position, reverse-geocodes it,
/// and saves it as the user's default address.
/// Returns a [LocationAutoDetectResult] indicating what happened.
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

    // 3. Get current position (timeout 10s)
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );

    // 4. Reverse geocode
    List<Placemark> placemarks;
    try {
      placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (_) {
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

    // 5. Save as default address
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

    final result =
        await ref.read(addressProvider.notifier).createAddress(params);

    if (!result.isSuccess) {
      return LocationAutoDetectResult.saveFailed;
    }

    // Refresh addresses so cart/checkout picks up the new default
    ref.invalidate(addressProvider);

    return LocationAutoDetectResult.success;
  } catch (_) {
    return LocationAutoDetectResult.unknown;
  }
}
