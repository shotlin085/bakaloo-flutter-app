import 'package:flutter/foundation.dart';

import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';

/// Whether the won prize's real-world reward (coupon targeted / wallet
/// credited) actually landed. `failed` still means the customer won and the
/// wheel should celebrate normally — the reward issuance itself hit a
/// server-side snag an admin fixes from the dashboard's History tab, not
/// something to surface as an error to the customer mid-celebration.
enum SpinRewardStatus { issued, failed, notApplicable }

SpinRewardStatus _rewardStatusFromBackend(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'ISSUED':
      return SpinRewardStatus.issued;
    case 'FAILED':
      return SpinRewardStatus.failed;
    default:
      return SpinRewardStatus.notApplicable;
  }
}

/// Server-resolved outcome of one `POST /spin-wheel/spin` call. Carries the
/// FULL won-prize details (not just an id) — the celebration dialog is
/// always accurate straight from this, with no dependency on the client's
/// cached wheel config still matching what the backend has (see
/// [SpinWheelNotifier.spin]'s doc comment for why that distinction
/// matters: only the landing *animation* needs a same-list index lookup).
@immutable
class SpinResult {
  const SpinResult({
    required this.success,
    this.prizeId,
    this.prizeType,
    this.prizeIconKey,
    this.prizeLabel,
    this.prizeValue,
    this.rewardStatus = SpinRewardStatus.notApplicable,
    this.spinsRemaining = 0,
    this.message,
  });

  /// False when the user had no spins available — every prize* field is
  /// null in that case (the backend never resolves a winner).
  final bool success;
  final String? prizeId;
  final String? prizeType;
  final String? prizeIconKey;
  final String? prizeLabel;
  final double? prizeValue;
  final SpinRewardStatus rewardStatus;
  final int spinsRemaining;
  final String? message;

  bool get isWin => success && prizeType != null && prizeType != 'BETTER_LUCK';

  /// Builds the won prize straight from this result's own fields — the
  /// authoritative source for what to celebrate, independent of whether
  /// the client's `GET /spin-wheel/config` cache still has a matching
  /// entry. [segmentColor] is cosmetically irrelevant here (the result
  /// dialog never paints a wedge), so it just reuses index 0's palette
  /// color rather than taking a parameter no caller has a meaningful
  /// value for.
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

  factory SpinResult.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;
    if (!success) {
      return SpinResult(
        success: false,
        message: json['message'] is String ? json['message'] as String : null,
      );
    }
    final prize = json['prize'];
    final prizeMap = prize is Map ? prize : const <String, dynamic>{};
    final rawValue = prizeMap['value'];
    return SpinResult(
      success: true,
      prizeId: prizeMap['id'] as String?,
      prizeType: prizeMap['type'] as String?,
      prizeIconKey: prizeMap['iconKey'] as String?,
      prizeLabel: prizeMap['label'] as String?,
      prizeValue: rawValue is num ? rawValue.toDouble() : null,
      rewardStatus: _rewardStatusFromBackend(
        json['rewardStatus'] is String ? json['rewardStatus'] as String : '',
      ),
      spinsRemaining: (json['spinsRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Pairs a resolved [SpinResult] with the wedge *index* to land the wheel
/// animation on — found by matching [SpinResult.prizeId] against the
/// currently-displayed prize list. Falls back to index 0 if the id isn't
/// found there (the rare case where an admin changed the prize list in the
/// moments between this app fetching config and this spin resolving) —
/// the celebration dialog itself stays correct regardless, since it's
/// built from [SpinResult.toPrize] directly, not from this index.
@immutable
class ResolvedSpin {
  const ResolvedSpin({required this.prizeIndex, required this.result});

  final int prizeIndex;
  final SpinResult result;
}
