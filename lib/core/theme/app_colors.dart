import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primaryGreen = Color(0xFF0C831F);
  static const primaryGreenLight = Color(0xFFE8F5E9);
  static const primaryGreenDark = Color(0xFF0A6B19);

  static const accentYellow = Color(0xFFF8CB2E);
  static const accentYellowLight = Color(0xFFFFF8DC);
  static const accentYellowDark = Color(0xFFE6B800);
  static const warmOrange = Color(0xFFFFA31A);
  static const warmOrangeDark = Color(0xFFEE8F00);
  static const warmOrangeSoft = Color(0xFFFFE1AF);
  static const warmCream = Color(0xFFFFFBF5);
  static const warmCanvas = Color(0xFFF7F1E8);
  static const warmCard = Color(0xFFFFF4DB);
  static const warmMuted = Color(0xFF8A7B67);
  static const warmChip = Color(0xFFF2ECE2);
  static const warmTintGreen = Color(0xFFEAF5C6);

  static const errorRed = Color(0xFFD32F2F);
  static const outOfStockRed = Color(0xFFE53935);
  static const successGreen = Color(0xFF2E7D32);
  static const warningOrange = Color(0xFFFF6D00);
  static const infoBlue = Color(0xFF1565C0);

  static const bgPrimary = Color(0xFFF8F8F8);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgSection = Color(0xFFF0F0F0);
  static const bgInput = Color(0xFFF5F5F5);
  static const bgSkeleton = Color(0xFFEEEEEE);

  static const textPrimary = Color(0xFF1C1C1C);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary = Color(0xFF999999);
  static const textDisabled = Color(0xFFBBBBBB);
  static const textOnGreen = Color(0xFFFFFFFF);
  static const textLink = Color(0xFF0C831F);

  static const divider = Color(0xFFEEEEEE);
  static const borderLight = Color(0xFFE0E0E0);
  static const borderFocus = Color(0xFF0C831F);

  static const overlayDark = Color(0xCC000000);
  static const overlayLight = Color(0x33000000);
  static const shimmerHighlight = Color(0xFFF5F5F5);
  static const ratingGold = Color(0xFFFFA000);
  static const vegGreen = Color(0xFF388E3C);
  static const nonVegRed = Color(0xFFD32F2F);

  // Product Detail — Zepto UI
  static const cartPink = Color(0xFFE91E63);
  static const cartPinkPressed = Color(0xFFC2185B);
  static const cartPinkLight = Color(0xFFFCE4EC);
  static const promoPurpleStart = Color(0xFF6A1B9A);
  static const promoPurpleMid = Color(0xFF7B1FA2);
  static const promoPurpleEnd = Color(0xFF9C27B0);
  static const promoBrandGold = Color(0xFFFFD54F);
  static const highlightOverlay = Color(0x99000000);
  static const highlightLabel = Color(0x8CFFFFFF);
  static const imageBg = Color(0xFFF2F2F2);
  static const cardBorderLight = Color(0xFFE8E8E8);
  static const priceBadgeBorder = Color(0xFF000000);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0C831F),
      Color(0xFF4CAF50),
    ],
  );

  static const walletCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A237E),
      Color(0xFF3949AB),
    ],
  );

  static const offerBannerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFFF8DC),
      Color(0xFFFFF3CD),
    ],
  );

  // Auth — Zepto-inspired Dark Purple Theme
  static const authPurpleDeep = Color(0xFF2D0A4E);
  static const authPurpleMid = Color(0xFF3B1260);
  static const authPurpleLight = Color(0xFF4A1A6B);
  static const authPurpleSurface = Color(0xFF5C2D82);
  static const authPurpleInput = Color(0xFF6B3D91);
  static const authPink = Color(0xFFFF6B8A);
  static const authPinkDark = Color(0xFFE8527A);
  static const authPinkGradientStart = Color(0xFFFF6B8A);
  static const authPinkGradientEnd = Color(0xFFFF8FA3);
  static const authTextWhite = Color(0xFFFFFFFF);
  static const authTextMuted = Color(0xFFB89AD4);
  static const authTextLink = Color(0xFFFF6B8A);
  static const authInputBorder = Color(0xFF7B4FA0);
  static const authSkipBg = Color(0x33FFFFFF);

  static const authBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [authPurpleDeep, authPurpleMid, authPurpleLight],
  );

  static const authBtnGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [authPinkGradientStart, authPinkGradientEnd],
  );
}
