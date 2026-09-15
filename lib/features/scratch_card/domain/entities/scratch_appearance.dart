import 'package:flutter/foundation.dart';

/// Cover ("foil") image scratched away to reveal the prize —
/// dashboard-configurable from Scratch Card → Settings (`GET
/// /scratch-card/appearance`). Null means "no admin override yet"; callers
/// fall back to a plain branded color instead of an image — see
/// `scratch_card_dialog.dart`. Mirrors `spin_appearance.dart`'s shape.
@immutable
class ScratchAppearance {
  const ScratchAppearance({this.coverImageUrl});

  final String? coverImageUrl;

  factory ScratchAppearance.fromJson(Map<String, dynamic> json) {
    final raw = json['coverImageUrl'];
    final trimmed = raw is String ? raw.trim() : '';
    return ScratchAppearance(coverImageUrl: trimmed.isEmpty ? null : trimmed);
  }
}
