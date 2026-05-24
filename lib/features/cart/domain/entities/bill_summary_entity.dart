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
    @Default(6) int minutes,
    @Default('Delivering in 6 mins') String label,
  }) = _DeliveryEstimate;

  factory DeliveryEstimate.fromJson(Map<String, dynamic> json) =>
      _$DeliveryEstimateFromJson(json);
}
