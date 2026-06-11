import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/savings_breakdown_entity.dart';

part 'bill_summary_entity.freezed.dart';
part 'bill_summary_entity.g.dart';

@freezed
abstract class BillSummaryEntity with _$BillSummaryEntity {
  const BillSummaryEntity._();

  const factory BillSummaryEntity({
    required ItemTotal itemTotal,
    required DeliveryFeeInfo deliveryFee,
    required FeeInfo handlingFee,
    required LateNightFeeInfo lateNightFee,
    required BillToPay toPay,
    required SavingsBreakdownEntity savings,
    required DeliveryEstimate deliveryEstimate,
    @Default(0) double couponDiscount,
    @Default(0) double tipAmount,
    @Default(0) int itemCount,
    // ── Canonical dynamic-fee fields (backend TotalsEngine) ──────────
    @Default(FeeInfo()) FeeInfo platformFee,
    @Default(FeeInfo()) FeeInfo smallCartFee,
    @Default(DistanceInfo()) DistanceInfo distance,
    @Default(FreeDeliveryInfo()) FreeDeliveryInfo freeDelivery,
    @Default(0) double totalPayable,
    @Default(<FeeLine>[]) List<FeeLine> fees,
  }) = _BillSummaryEntity;

  factory BillSummaryEntity.fromJson(Map<String, dynamic> json) =>
      _$BillSummaryEntityFromJson(json);

  factory BillSummaryEntity.empty() => const BillSummaryEntity(
        itemTotal: ItemTotal(),
        deliveryFee: DeliveryFeeInfo(),
        handlingFee: FeeInfo(),
        lateNightFee: LateNightFeeInfo(),
        toPay: BillToPay(),
        savings: SavingsBreakdownEntity(),
        deliveryEstimate: DeliveryEstimate(),
      );

  /// The amount the customer pays. Prefers the backend canonical
  /// `totalPayable`; falls back to the legacy `toPay.final` so older
  /// payloads keep working.
  double get payable =>
      totalPayable > 0 ? totalPayable : toPay.finalAmount;
}

@freezed
abstract class ItemTotal with _$ItemTotal {
  const factory ItemTotal({
    @Default(0) double original,
    @Default(0) double discounted,
  }) = _ItemTotal;

  factory ItemTotal.fromJson(Map<String, dynamic> json) =>
      _$ItemTotalFromJson(json);
}

@freezed
abstract class DeliveryFeeInfo with _$DeliveryFeeInfo {
  const factory DeliveryFeeInfo({
    @Default(0) double amount,
    @Default(false) bool isFree,
    @Default(0) double freeIn,
    @Default(0) double originalAmount,
    String? waiverReason,
  }) = _DeliveryFeeInfo;

  factory DeliveryFeeInfo.fromJson(Map<String, dynamic> json) =>
      _$DeliveryFeeInfoFromJson(json);
}

@freezed
abstract class FeeInfo with _$FeeInfo {
  const factory FeeInfo({
    @Default(0) double amount,
    @Default(false) bool isFree,
    @Default(0) double savedAmount,
  }) = _FeeInfo;

  factory FeeInfo.fromJson(Map<String, dynamic> json) =>
      _$FeeInfoFromJson(json);
}

@freezed
abstract class LateNightFeeInfo with _$LateNightFeeInfo {
  const factory LateNightFeeInfo({
    @Default(0) double amount,
    @Default(false) bool isFree,
    @Default(0) double savedAmount,
    @Default(false) bool isLateNight,
  }) = _LateNightFeeInfo;

  factory LateNightFeeInfo.fromJson(Map<String, dynamic> json) =>
      _$LateNightFeeInfoFromJson(json);
}

@freezed
abstract class BillToPay with _$BillToPay {
  const factory BillToPay({
    @Default(0) double original,
    @Default(0) @JsonKey(name: 'final') double finalAmount,
  }) = _BillToPay;

  factory BillToPay.fromJson(Map<String, dynamic> json) =>
      _$BillToPayFromJson(json);
}

@freezed
abstract class DeliveryEstimate with _$DeliveryEstimate {
  const factory DeliveryEstimate({
    @Default(30) int minutes,
    @Default('Delivering in 30 mins') String label,
  }) = _DeliveryEstimate;

  factory DeliveryEstimate.fromJson(Map<String, dynamic> json) =>
      _$DeliveryEstimateFromJson(json);
}

/// Delivery distance from the store to the customer (backend-computed).
@freezed
abstract class DistanceInfo with _$DistanceInfo {
  const factory DistanceInfo({
    double? km,
    @Default('') String label,
    @Default(false) bool known,
  }) = _DistanceInfo;

  factory DistanceInfo.fromJson(Map<String, dynamic> json) =>
      _$DistanceInfoFromJson(json);
}

/// Free-delivery progress info for the customer-facing progress UI.
@freezed
abstract class FreeDeliveryInfo with _$FreeDeliveryInfo {
  const factory FreeDeliveryInfo({
    @Default(false) bool enabled,
    double? threshold,
    @Default(false) bool unlocked,
    @Default(0) double amountToUnlock,
  }) = _FreeDeliveryInfo;

  factory FreeDeliveryInfo.fromJson(Map<String, dynamic> json) =>
      _$FreeDeliveryInfoFromJson(json);
}

/// One line in the canonical fee breakdown (delivery / handling / platform / …).
@freezed
abstract class FeeLine with _$FeeLine {
  const factory FeeLine({
    @Default('') String code,
    @Default('') String label,
    @Default(0) double amount,
    @Default(0) double originalAmount,
    @Default(false) bool waived,
    @Default('') String description,
  }) = _FeeLine;

  factory FeeLine.fromJson(Map<String, dynamic> json) =>
      _$FeeLineFromJson(json);
}
