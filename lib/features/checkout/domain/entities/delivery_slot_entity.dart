/// Represents a single deliverable time slot.
class DeliverySlotEntity {
  const DeliverySlotEntity({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.available,
    this.reason,
  });

  final String id;
  final String label;
  final DateTime start;
  final DateTime end;
  final bool available;
  final String? reason;

  factory DeliverySlotEntity.fromJson(Map<String, dynamic> json) {
    return DeliverySlotEntity(
      id: json['id'] as String,
      label: json['label'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

/// Represents one day's worth of delivery slots.
class DeliverySlotDayEntity {
  const DeliverySlotDayEntity({
    required this.date,
    required this.label,
    required this.slots,
  });

  final String date;
  final String label;
  final List<DeliverySlotEntity> slots;

  factory DeliverySlotDayEntity.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List<dynamic>? ?? [];
    return DeliverySlotDayEntity(
      date: json['date'] as String,
      label: json['label'] as String,
      slots: rawSlots
          .map((s) => DeliverySlotEntity.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

/// The user's selected delivery preference — either ASAP or a specific slot.
class SelectedDeliverySlot {
  const SelectedDeliverySlot.asap() : mode = 'ASAP', slot = null, dayLabel = null;

  const SelectedDeliverySlot.scheduled({
    required DeliverySlotEntity this.slot,
    required String this.dayLabel,
  }) : mode = 'SCHEDULED';

  final String mode;
  final DeliverySlotEntity? slot;
  final String? dayLabel;

  bool get isAsap => mode == 'ASAP';
  bool get isScheduled => mode == 'SCHEDULED';

  /// Short display label for the cart row / checkout card.
  String get displayLabel {
    if (isAsap) return 'Delivering in 6 mins';
    return '$dayLabel, ${slot!.label}';
  }

  /// Full label stored on the order (e.g. "Today, 7:00 PM – 9:00 PM")
  String get slotLabel => isAsap ? '' : '$dayLabel, ${slot!.label}';
}
