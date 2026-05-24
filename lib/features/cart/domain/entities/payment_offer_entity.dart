import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_offer_entity.freezed.dart';
part 'payment_offer_entity.g.dart';

double _paymentOfferAmountFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

@freezed
abstract class PaymentOfferEntity with _$PaymentOfferEntity {
  const factory PaymentOfferEntity({
    required String id,
    required String title,
    required String provider,
    required bool isLocked,
    String? description,
    String? iconUrl,
    @Default(0)
    @JsonKey(fromJson: _paymentOfferAmountFromJson)
    double cashbackAmount,
    @Default(0)
    @JsonKey(fromJson: _paymentOfferAmountFromJson)
    double minOrderAmount,
    String? lockMessage,
    @Default(0)
    @JsonKey(fromJson: _paymentOfferAmountFromJson)
    double unlockProgress,
  }) = _PaymentOfferEntity;

  factory PaymentOfferEntity.fromJson(Map<String, dynamic> json) =>
      _$PaymentOfferEntityFromJson(json);
}
