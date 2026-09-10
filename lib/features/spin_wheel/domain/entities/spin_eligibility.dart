import 'package:flutter/foundation.dart';

/// Where/when the Spin & Win popup auto-shows itself, dashboard-configured
/// (`spin_wheel_settings.trigger_mode`). The Profile → "Spin & Win" tile is
/// unconditional in every mode — this only governs the automatic popup.
enum SpinTriggerMode {
  /// Auto-shows once per app session for any logged-in user, even at 0
  /// spins available (the dialog then shows a "come back tomorrow" state).
  alwaysOnLogin,

  /// Auto-shows once per session only when the user actually has a spin
  /// available — nothing to interrupt them for otherwise.
  milestoneOnly,

  /// Never auto-shows.
  manualOnly,
}

SpinTriggerMode spinTriggerModeFromBackend(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'MILESTONE_ONLY':
      return SpinTriggerMode.milestoneOnly;
    case 'MANUAL_ONLY':
      return SpinTriggerMode.manualOnly;
    case 'ALWAYS_ON_LOGIN':
    default:
      return SpinTriggerMode.alwaysOnLogin;
  }
}

/// How many spins the current user has right now — from
/// `GET /spin-wheel/eligibility`. `spinsAvailable` already reflects today's
/// not-yet-claimed daily allowance (the backend projects it lazily; no
/// separate "claim" step needed client-side).
@immutable
class SpinEligibility {
  const SpinEligibility({
    required this.spinsAvailable,
    required this.dailyFreeSpins,
    required this.triggerMode,
  });

  final int spinsAvailable;
  final int dailyFreeSpins;
  final SpinTriggerMode triggerMode;

  bool get hasSpinsAvailable => spinsAvailable > 0;

  factory SpinEligibility.fromJson(Map<String, dynamic> json) {
    return SpinEligibility(
      spinsAvailable: (json['spinsAvailable'] as num?)?.toInt() ?? 0,
      dailyFreeSpins: (json['dailyFreeSpins'] as num?)?.toInt() ?? 0,
      triggerMode: spinTriggerModeFromBackend(
        json['triggerMode'] is String ? json['triggerMode'] as String : '',
      ),
    );
  }
}
