import 'package:flutter/foundation.dart';

/// Popup background image + banner-box copy — dashboard-configurable from
/// Spin & Win → Settings (`GET /spin-wheel/appearance`). Every field is
/// nullable: null means "no admin override yet", and callers fall back to
/// the bundled default asset / hardcoded copy — see `spin_win_dialog.dart`.
/// No separate "model" class (unlike [SpinPrizeModel]) since this is plain
/// strings with no UI type resolution needed, same shape as
/// `spin_eligibility.dart`'s `SpinEligibility`.
@immutable
class SpinAppearance {
  const SpinAppearance({
    this.backgroundImageUrl,
    this.bannerTitle,
    this.bannerSubtitle,
    this.bannerTagline,
  });

  final String? backgroundImageUrl;
  final String? bannerTitle;
  final String? bannerSubtitle;
  final String? bannerTagline;

  factory SpinAppearance.fromJson(Map<String, dynamic> json) {
    String? nonEmpty(dynamic value) {
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return SpinAppearance(
      backgroundImageUrl: nonEmpty(json['backgroundImageUrl']),
      bannerTitle: nonEmpty(json['bannerTitle']),
      bannerSubtitle: nonEmpty(json['bannerSubtitle']),
      bannerTagline: nonEmpty(json['bannerTagline']),
    );
  }
}
