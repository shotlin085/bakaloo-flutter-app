class StorageKeys {
  StorageKeys._();

  static const accessToken = 'bakaloo_access_token';
  static const refreshToken = 'bakaloo_refresh_token';
  static const userId = 'bakaloo_user_id';
  static const hiveEncryptionKey = 'bakaloo_hive_encryption_key';

  static const productsBox = 'products';
  static const categoriesBox = 'categories';
  static const ordersBox = 'orders';
  static const searchHistoryBox = 'search_history';
  static const recentlyViewedBox = 'recently_viewed';
  static const bannersBox = 'banners';
  static const userBox = 'user';
  static const settingsBox = 'settings';
  static const cacheMetaBox = 'cache_meta';
  static const remoteThemeBox = 'remote_theme';

  static const onboardingShown = 'onboarding_shown';
  static const walletBiometric = 'wallet_biometric_enabled';
  static const lastFcmToken = 'last_fcm_token';
  static const themeMode = 'theme_mode';
  static const hideSensitiveItems = 'hide_sensitive_items';
  static const nonServiceableLocationDetected =
      'non_serviceable_location_detected';

  static const cacheCategories = 'cache_categories';
  static const cacheFeatured = 'cache_featured';
  static const cacheBanners = 'cache_banners';
  static const cacheOrders = 'cache_orders';
  static const cacheUserProfile = 'cache_user_profile';
  static const cacheAddresses = 'cache_addresses';
  /// Fast-launch cache of the active price mode ('wholesale'/'retail') —
  /// read synchronously by PriceModeInterceptor on every request and by
  /// PriceModeNotifier.build() at startup. Server-authoritative: always
  /// re-derived from the user's live b2bStatus/b2bEnabled on login/refresh,
  /// this is only a same-session fast path, never the source of truth.
  static const cachePriceMode = 'cache_price_mode';
  static const cacheRemoteTheme = 'cache_remote_theme';
  static String cacheProduct(String productId) => 'cache_product_$productId';
  static String cacheRemoteThemeForStore(String storeKey) =>
      'cache_remote_theme_$storeKey';
  static String cacheRemoteThemeHome(String storeKey, String tabKey) =>
      'cache_remote_theme_home_${storeKey}_$tabKey';
}
