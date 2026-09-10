import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// How a won prize redeems. Mirrors [CouponDiscountType]
/// (lib/features/checkout/domain/entities/coupon_entity.dart) wherever a
/// direct equivalent exists — the backend issues the real reward via the
/// same coupon/wallet primitives that type already maps to. `buyOneGetOne`
/// has no dedicated backend discount type; the linked coupon underneath it
/// can be whatever the admin configured (see spin-wheel.service.js).
enum SpinPrizeType {
  freeDelivery,
  percentageOff,
  flatOff,
  buyOneGetOne,
  extraSavings,
  betterLuck,
}

/// Backend `spin_prizes.type` (e.g. `'PERCENTAGE_OFF'`) → [SpinPrizeType].
/// Unrecognized/future values fall back to `betterLuck` (a no-op wedge)
/// rather than crashing the wheel on an unexpected string.
SpinPrizeType spinPrizeTypeFromBackend(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'FREE_DELIVERY':
      return SpinPrizeType.freeDelivery;
    case 'PERCENTAGE_OFF':
      return SpinPrizeType.percentageOff;
    case 'FLAT_OFF':
      return SpinPrizeType.flatOff;
    case 'BUY_ONE_GET_ONE':
      return SpinPrizeType.buyOneGetOne;
    case 'CASHBACK':
      return SpinPrizeType.extraSavings;
    default:
      return SpinPrizeType.betterLuck;
  }
}

/// Backend `spin_prizes.icon_key` → the Phosphor glyph shown on that wedge.
/// Same fallback philosophy as [spinPrizeTypeFromBackend] — an
/// unrecognized key (e.g. a future icon added server-side before this app
/// is updated) renders a generic gift icon instead of crashing.
IconData spinIconForKey(String key) {
  switch (key.trim().toLowerCase()) {
    case 'shopping_cart':
      return PhosphorIcons.shoppingCartLight;
    case 'percent':
      return PhosphorIcons.sealPercentLight;
    case 'basket':
      return PhosphorIcons.basketLight;
    case 'coins':
      return PhosphorIcons.handCoinsLight;
    case 'sad_face':
      return PhosphorIcons.smileySadLight;
    case 'star':
      return PhosphorIcons.starLight;
    case 'ticket':
      return PhosphorIcons.ticketLight;
    case 'gift':
    default:
      return PhosphorIcons.giftLight;
  }
}

/// The wheel's pastel wedge backgrounds never come from the backend (odds
/// and content do; color is purely a client-side rendering choice) — cycled
/// by position so a 2-8 length list always reads as the same alternating
/// cream/pink/lavender pattern the original 8-wedge design used.
const List<Color> _segmentColorCycle = <Color>[
  AppColors.spinSegmentCream,
  AppColors.spinSegmentPink,
  AppColors.spinSegmentCream,
  AppColors.spinSegmentPink,
  AppColors.spinSegmentCream,
  AppColors.spinSegmentLavender,
  AppColors.spinSegmentCream,
  AppColors.spinSegmentLavender,
];

Color spinSegmentColorForIndex(int index) =>
    _segmentColorCycle[index % _segmentColorCycle.length];

/// A single wedge on the Spin & Win wheel. Plain immutable class (not
/// freezed) — [icon]/[segmentColor] are resolved once, at the
/// model-to-entity mapping boundary (see `spin_prize_model.dart`), from the
/// backend's `iconKey`/position via the helpers above, so
/// [SpinWheelDial]/[SpinWheelPainter] keep reading plain `IconData`/`Color`
/// fields exactly as they did in phase 1 — no widget changes needed for a
/// dynamic, variable-length (2-8) prize list.
@immutable
class SpinPrize {
  const SpinPrize({
    required this.id,
    required this.label,
    required this.type,
    required this.icon,
    required this.segmentColor,
    this.value,
  });

  /// Backend `spin_prizes.id` — correlates a `POST /spin-wheel/spin`
  /// result back to this wedge's index in the currently-displayed list.
  final String id;
  final String label;
  final SpinPrizeType type;
  final IconData icon;
  final Color segmentColor;
  /// Percentage points, flat rupees, etc. — meaning depends on [type]. Null
  /// for `buyOneGetOne`, `extraSavings` and `betterLuck`.
  final double? value;

  bool get isWinning => type != SpinPrizeType.betterLuck;
}

/// Offline/error-state fallback ONLY — rendered when the live
/// `GET /spin-wheel/config` fetch fails, so the wheel still shows
/// *something* instead of a blank dialog. Never used to resolve a real
/// spin (that always requires the network round trip in
/// `SpinWheelNotifier.spin()`), so tapping SPIN while this fallback is
/// showing is disabled — see `spin_win_dialog.dart`.
const List<SpinPrize> kSpinWheelPrizes = <SpinPrize>[
  SpinPrize(
    id: 'fallback-0',
    label: 'Free Delivery',
    type: SpinPrizeType.freeDelivery,
    icon: PhosphorIcons.shoppingCartLight,
    segmentColor: AppColors.spinSegmentCream,
  ),
  SpinPrize(
    id: 'fallback-1',
    label: '5% OFF',
    type: SpinPrizeType.percentageOff,
    value: 5,
    icon: PhosphorIcons.sealPercentLight,
    segmentColor: AppColors.spinSegmentPink,
  ),
  SpinPrize(
    id: 'fallback-2',
    label: '10% OFF',
    type: SpinPrizeType.percentageOff,
    value: 10,
    icon: PhosphorIcons.basketLight,
    segmentColor: AppColors.spinSegmentCream,
  ),
  SpinPrize(
    id: 'fallback-3',
    label: '₹50 OFF',
    type: SpinPrizeType.flatOff,
    value: 50,
    icon: PhosphorIcons.handCoinsLight,
    segmentColor: AppColors.spinSegmentPink,
  ),
  SpinPrize(
    id: 'fallback-4',
    label: '₹100 OFF',
    type: SpinPrizeType.flatOff,
    value: 100,
    icon: PhosphorIcons.giftLight,
    segmentColor: AppColors.spinSegmentCream,
  ),
  SpinPrize(
    id: 'fallback-5',
    label: 'Better Luck\nNext Time',
    type: SpinPrizeType.betterLuck,
    icon: PhosphorIcons.smileySadLight,
    segmentColor: AppColors.spinSegmentLavender,
  ),
  SpinPrize(
    id: 'fallback-6',
    label: 'Extra Savings',
    type: SpinPrizeType.extraSavings,
    icon: PhosphorIcons.starLight,
    segmentColor: AppColors.spinSegmentCream,
  ),
  SpinPrize(
    id: 'fallback-7',
    label: 'BUY 1\nGET 1',
    type: SpinPrizeType.buyOneGetOne,
    icon: PhosphorIcons.giftLight,
    segmentColor: AppColors.spinSegmentLavender,
  ),
];
