class AppConstants {
  AppConstants._();

  static const paginationLimit = 20;
  static const searchDebounceMs = 300;
  static const otpLength = 6;
  static const otpResendSeconds = 60;
  static const freeDeliveryThreshold = 499.0;
  static const standardDeliveryFee = 25.0;
  static const platformFee = 5.0;
  static const maxCodAmount = 2000.0;
  static const maxSearchHistory = 10;
  static const imageCacheSizeMB = 256;
  static const imageCacheMaxCount = 1000;
  static const socketReconnectAttempts = 10;
  static const socketReconnectDelayMs = 2000;
  static const connectTimeoutSeconds = 15;
  static const receiveTimeoutSeconds = 30;
}
