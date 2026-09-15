import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/nav_button/domain/entities/nav_button_entity.dart';

class NavButtonRemoteDataSource {
  const NavButtonRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<NavButtonEntity?> getNavButton() async {
    final response = await _apiClient.getNavButton();
    final raw = response.data;
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);

    final destinationType =
        navButtonDestinationTypeFromJson(json['destination_type'] as String?);
    final destinationValue = json['destination_value'] as String?;
    // A row this client doesn't understand (a newer destination_type
    // added server-side after this build shipped, or malformed data) is
    // treated the same as "no button configured" — never crash the whole
    // bottom nav over one bad row.
    if (destinationType == null ||
        destinationValue == null ||
        destinationValue.isEmpty) {
      return null;
    }

    final iconType = (json['icon_type'] as String?) == 'CUSTOM'
        ? NavButtonIconType.custom
        : NavButtonIconType.preset;
    final customIconActiveUrl = json['custom_icon_active_url'] as String?;
    // A CUSTOM row with no active image is malformed (the backend
    // requires one) — fall back to a PRESET star rather than rendering
    // nothing at all.
    if (iconType == NavButtonIconType.custom &&
        (customIconActiveUrl == null || customIconActiveUrl.isEmpty)) {
      return NavButtonEntity(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        iconType: NavButtonIconType.preset,
        iconKey: 'star',
        destinationType: destinationType,
        destinationValue: destinationValue,
        passIdentity: json['pass_identity'] as bool? ?? false,
      );
    }

    return NavButtonEntity(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      iconType: iconType,
      iconKey: json['icon_key'] as String? ?? 'star',
      accentColor: json['accent_color'] as String?,
      customIconActiveUrl: customIconActiveUrl,
      customIconInactiveUrl: json['custom_icon_inactive_url'] as String?,
      destinationType: destinationType,
      destinationValue: destinationValue,
      passIdentity: json['pass_identity'] as bool? ?? false,
    );
  }

  /// Mints the short-lived identity-handoff token for a WEBVIEW button with
  /// pass_identity=true. Fetched fresh right before opening the WebView
  /// (never cached — it expires in ~10 minutes) so a customer who opens
  /// the button a while after cold-starting the app still gets a live
  /// token, not one already expired.
  Future<String?> getWebviewToken() async {
    final response = await _apiClient.postNavButtonWebviewToken();
    final raw = response.data;
    if (raw is! Map) return null;
    return raw['token'] as String?;
  }
}
