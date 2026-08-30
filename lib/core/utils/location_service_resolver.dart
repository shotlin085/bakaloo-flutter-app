import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as location_pkg;

/// Prompts the customer to turn device location ON using Android's native
/// Google Play Services "Location Accuracy" resolution dialog — the same
/// in-app "Turn on" dialog Zomato/Blinkit use — instead of bouncing them
/// out to the OS Settings app and back.
///
/// geolocator (used everywhere else in this app for permission/position
/// APIs) has no equivalent of this: it can only detect that the service is
/// off and open Settings via `Geolocator.openLocationSettings()`. Only the
/// `location` package's `requestService()` drives Play Services'
/// `SettingsClient`, which is what actually renders that native dialog and
/// resolves it without leaving the app. It's used here purely for that one
/// call — everything else location-related in this app still goes through
/// geolocator.
///
/// Returns true once the service is confirmed on (whether it already was,
/// or the customer just turned it on from the dialog); false if they
/// dismissed it ("No, thanks") or it's still off for any other reason.
///
/// iOS has no equivalent API — Apple doesn't expose a way to resolve this
/// in-app — so there this falls back to opening Settings directly, same as
/// before.
Future<bool> requestEnableLocationService() async {
  if (!Platform.isAndroid) {
    await Geolocator.openLocationSettings();
    return _waitForServiceEnabled();
  }

  try {
    return await location_pkg.Location().requestService();
  } catch (_) {
    // Play Services unavailable/out of date, or the resolution flow failed
    // for some other reason — Settings is still a working fallback rather
    // than leaving the customer stuck with no way forward at all.
    await Geolocator.openLocationSettings();
    return _waitForServiceEnabled();
  }
}

/// Waits for the OS to actually report location as enabled, instead of
/// checking `Geolocator.isLocationServiceEnabled()` immediately.
///
/// Root cause of the iOS bug this fixes: `Geolocator.openLocationSettings()`
/// only launches the Settings app — its Future completes the instant that
/// launch succeeds, which is a fraction of a second later, NOT when the
/// customer has actually found Location Services and switched it on and
/// come back. Checking the service state right after that await was
/// therefore always checking before the customer had done anything, so it
/// read "still off" and reported failure on effectively every attempt —
/// regardless of whether they went on to enable it moments later. This
/// waits for the real enabled event (with a generous timeout in case they
/// back out of Settings without changing anything), so "Enable" only
/// reports success once location is genuinely on.
Future<bool> _waitForServiceEnabled() async {
  if (await Geolocator.isLocationServiceEnabled()) {
    return true;
  }
  try {
    await Geolocator.getServiceStatusStream()
        .firstWhere((status) => status == ServiceStatus.enabled)
        .timeout(const Duration(minutes: 3));
    return true;
  } catch (_) {
    return Geolocator.isLocationServiceEnabled();
  }
}
