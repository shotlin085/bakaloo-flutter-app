import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';

/// Wire format for one item of `GET /spin-wheel/config`'s response — the
/// backend deliberately omits `winProbability`/`linkedCouponId` from this
/// endpoint (the client renders wedges, it never needs the odds).
class SpinPrizeModel {
  const SpinPrizeModel({
    required this.id,
    required this.type,
    required this.iconKey,
    required this.label,
    required this.value,
    required this.displayOrder,
  });

  final String id;
  final String type;
  final String iconKey;
  final String label;
  final double? value;
  final int displayOrder;

  factory SpinPrizeModel.fromJson(Map<String, dynamic> json) {
    final rawValue = json['value'];
    return SpinPrizeModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? 'gift',
      label: json['label'] as String? ?? '',
      value: rawValue is num ? rawValue.toDouble() : null,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  /// [index] is this prize's position within the *already-sorted* list
  /// being converted — used only to cycle the wedge's pastel background
  /// (see [spinSegmentColorForIndex]), a purely client-side rendering
  /// choice the backend has no opinion on.
  SpinPrize toEntity(int index) {
    return SpinPrize(
      id: id,
      label: label,
      type: spinPrizeTypeFromBackend(type),
      icon: spinIconForKey(iconKey),
      segmentColor: spinSegmentColorForIndex(index),
      value: value,
    );
  }
}
