import 'package:flutter/foundation.dart';

import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_eligibility.dart'
    show SpinTriggerMode, spinTriggerModeFromBackend;

/// How many scratch cards the current user has right now — from `GET
/// /scratch-card/eligibility`. Reuses [SpinTriggerMode] from the spin-wheel
/// feature rather than declaring an identical enum a second time — the
/// three trigger semantics (always/milestone-only/manual-only) aren't
/// spin-specific, they're a generic "popup auto-show" concept both games
/// share (same as reusing `SpinPrize`/`showSpinResultDialog` for the win
/// celebration — see `scratch_result.dart`).
@immutable
class ScratchEligibility {
  const ScratchEligibility({
    required this.scratchesAvailable,
    required this.dailyFreeScratches,
    required this.triggerMode,
  });

  final int scratchesAvailable;
  final int dailyFreeScratches;
  final SpinTriggerMode triggerMode;

  bool get hasScratchesAvailable => scratchesAvailable > 0;

  factory ScratchEligibility.fromJson(Map<String, dynamic> json) {
    return ScratchEligibility(
      scratchesAvailable: (json['scratchesAvailable'] as num?)?.toInt() ?? 0,
      dailyFreeScratches: (json['dailyFreeScratches'] as num?)?.toInt() ?? 0,
      triggerMode: spinTriggerModeFromBackend(
        json['triggerMode'] is String ? json['triggerMode'] as String : '',
      ),
    );
  }
}
