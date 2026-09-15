import 'package:freezed_annotation/freezed_annotation.dart';

part 'nav_button_entity.freezed.dart';

enum NavButtonDestinationType { appRoute, category, product, webview }

NavButtonDestinationType? navButtonDestinationTypeFromJson(String? value) {
  switch (value) {
    case 'APP_ROUTE':
      return NavButtonDestinationType.appRoute;
    case 'CATEGORY':
      return NavButtonDestinationType.category;
    case 'PRODUCT':
      return NavButtonDestinationType.product;
    case 'WEBVIEW':
      return NavButtonDestinationType.webview;
    default:
      return null;
  }
}

enum NavButtonIconType { preset, custom }

@freezed
abstract class NavButtonEntity with _$NavButtonEntity {
  const factory NavButtonEntity({
    required String id,
    required String label,
    required NavButtonDestinationType destinationType,
    required String destinationValue,
    @Default(NavButtonIconType.preset) NavButtonIconType iconType,
    // PRESET fields.
    String? iconKey,
    String? accentColor,
    // CUSTOM fields — customIconActiveUrl is required when iconType is
    // custom (enforced server-side); customIconInactiveUrl is optional
    // and falls back to the active image when absent.
    String? customIconActiveUrl,
    String? customIconInactiveUrl,
    @Default(false) bool passIdentity,
  }) = _NavButtonEntity;
}
