import 'package:flutter/foundation.dart';

import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';

/// Whether the won prize's real-world reward (coupon targeted / wallet
/// credited) actually landed. Mirrors [SpinRewardStatus] exactly — kept as
/// its own enum (not reused) since scratch-card.service.js and
/// spin-wheel.service.js resolve this independently and a future
/// divergence between the two shouldn't need touching shared code.
enum ScratchRewardStatus { issued, failed, notApplicable }

ScratchRewardStatus _rewardStatusFromBackend(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'ISSUED':
      return ScratchRewardStatus.issued;
    case 'FAILED':
      return ScratchRewardStatus.failed;
    default:
      return ScratchRewardStatus.notApplicable;
  }
}

/// Server-resolved outcome of one `POST /scratch-card/scratch` call.
/// Deliberately builds a [SpinPrize] in [toPrize] and is celebrated via the
/// spin-wheel feature's `showSpinResultDialog` — a won prize is a won
/// prize regardless of which mini-game produced it, so the celebration UI
/// (confetti, gift-box reveal, per-type copy) is shared rather than
/// duplicated. Mirrors `spin_result.dart`'s shape and reasoning otherwise.
@immutable
class ScratchResult {
  const ScratchResult({
    required this.success,
    this.prizeId,
    this.prizeType,
    this.prizeIconKey,
    this.prizeLabel,
    this.prizeValue,
    this.rewardStatus = ScratchRewardStatus.notApplicable,
    this.scratchesRemaining = 0,
    this.message,
  });

  /// False when the user had no scratch cards available — every prize*
  /// field is null in that case (the backend never resolves a winner).
  final bool success;
  final String? prizeId;
  final String? prizeType;
  final String? prizeIconKey;
  final String? prizeLabel;
  final double? prizeValue;
  final ScratchRewardStatus rewardStatus;
  final int scratchesRemaining;
  final String? message;

  bool get isWin => success && prizeType != null && prizeType != 'BETTER_LUCK';

  /// Builds the won prize straight from this result's own fields — see
  /// [SpinResult.toPrize]'s doc comment for why this never depends on any
  /// client-side prize-list cache. [segmentColor] is irrelevant here (the
  /// result dialog never paints a wedge).
  SpinPrize? toPrize() {
    if (!success || prizeId == null || prizeType == null || prizeLabel == null) {
      return null;
    }
    return SpinPrize(
      id: prizeId!,
      label: prizeLabel!,
      type: spinPrizeTypeFromBackend(prizeType!),
      icon: spinIconForKey(prizeIconKey ?? 'gift'),
      segmentColor: spinSegmentColorForIndex(0),
      value: prizeValue,
    );
  }

  factory ScratchResult.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;
    if (!success) {
      return ScratchResult(
        success: false,
        message: json['message'] is String ? json['message'] as String : null,
      );
    }
    final prize = json['prize'];
    final prizeMap = prize is Map ? prize : const <String, dynamic>{};
    final rawValue = prizeMap['value'];
    return ScratchResult(
      success: true,
      prizeId: prizeMap['id'] as String?,
      prizeType: prizeMap['type'] as String?,
      prizeIconKey: prizeMap['iconKey'] as String?,
      prizeLabel: prizeMap['label'] as String?,
      prizeValue: rawValue is num ? rawValue.toDouble() : null,
      rewardStatus: _rewardStatusFromBackend(
        json['rewardStatus'] is String ? json['rewardStatus'] as String : '',
      ),
      scratchesRemaining: (json['scratchesRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}
