import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/business_account/presentation/providers/business_account_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';

part 'price_mode_provider.g.dart';

enum PriceMode { retail, wholesale }

class PriceModeActionResult {
  const PriceModeActionResult({this.failure});

  final Failure? failure;

  bool get isSuccess => failure == null;
}

/// The active price mode — server-authoritative (mirrors the business
/// account's b2b_enabled once APPROVED), with a Hive-backed value used only
/// as a fast-launch guess so the UI doesn't flash 'retail' for a split
/// second on every cold start before the live account status loads.
///
/// [toggle] is the single place that flips B2B pricing on/off across the
/// whole app: it calls PATCH /business-accounts/me/toggle, then drops every
/// cache that could otherwise keep showing prices from the old mode
/// (product list/detail cache, cart, and — since audience follows the same
/// APPROVED+enabled flag — the active theme/banners).
@Riverpod(keepAlive: true)
class PriceModeNotifier extends _$PriceModeNotifier {
  @override
  PriceMode build() {
    final cached = HiveService.settingsBox.get(StorageKeys.cachePriceMode);
    final initial = cached == 'wholesale' ? PriceMode.wholesale : PriceMode.retail;

    // Self-correct as soon as the live business-account status is known —
    // the Hive value above is only ever a same-session fast-launch guess.
    ref.listen(myBusinessAccountProvider, (previous, next) {
      final account = next.asData?.value;
      final eligible = account != null && account.status == 'APPROVED' && account.b2bEnabled;
      final corrected = eligible ? PriceMode.wholesale : PriceMode.retail;
      if (corrected != state) {
        state = corrected;
        unawaited(_persist(corrected));
      }
    });

    return initial;
  }

  Future<PriceModeActionResult> toggle() async {
    final wantsWholesale = state != PriceMode.wholesale;

    if (wantsWholesale) {
      final account = ref.read(myBusinessAccountProvider).asData?.value;
      if (account == null || account.status != 'APPROVED') {
        return const PriceModeActionResult(
          failure: ValidationFailure(
            message:
                'Your business account must be approved before you can switch to wholesale pricing.',
          ),
        );
      }
    }

    final result = await ref
        .read(toggleBusinessAccountUseCaseProvider)
        .call(wantsWholesale);

    return result.fold<Future<PriceModeActionResult>>(
      (failure) async => PriceModeActionResult(failure: failure),
      (account) async {
        final next = account.b2bEnabled ? PriceMode.wholesale : PriceMode.retail;
        state = next;
        await _persist(next);
        ref.invalidate(myBusinessAccountProvider);

        // Keep the cached auth identity's b2bEnabled in sync so it survives
        // an app restart even before the next /business-accounts/me fetch.
        final authState = ref.read(authStateProvider);
        if (authState is AuthAuthenticated) {
          unawaited(
            ref.read(authNotifierProvider.notifier).syncCachedUser(
                  authState.user.copyWith(
                    b2bStatus: account.status,
                    b2bEnabled: account.b2bEnabled,
                  ),
                ),
          );
        }

        await _clearPriceSensitiveState();
        return const PriceModeActionResult();
      },
    );
  }

  Future<void> _persist(PriceMode mode) async {
    try {
      await HiveService.settingsBox.put(
        StorageKeys.cachePriceMode,
        mode == PriceMode.wholesale ? 'wholesale' : 'retail',
      );
    } catch (_) {
      // best-effort — Hive is only a fast-launch cache here.
    }
  }

  /// Drops every cache that could otherwise keep rendering prices/theme
  /// content from the mode just switched away from.
  Future<void> _clearPriceSensitiveState() async {
    await AppCacheManager.clearPriceSensitiveCaches();
    try {
      ref.invalidate(cartProvider);
    } catch (_) {}
    // Section manifests (the Section Builder home-screen content) are
    // cached separately from tab themes/home-merch, keyed only by
    // store+tab — not audience — so a plain theme refresh wouldn't pick up
    // the other audience's section layout. Clear them explicitly and
    // invalidate every instance of the family so the currently visible tab
    // refetches immediately.
    try {
      await clearAllSectionManifestCaches();
      ref.invalidate(sectionManifestProvider);
      ref.invalidate(activeSectionManifestProvider);
    } catch (_) {}
    try {
      await ref.read(managedThemeRefreshProvider.notifier).refresh();
    } catch (_) {}
  }
}

/// Whether the current price mode is wholesale — a plain bool convenience
/// for widgets that don't need the enum itself (e.g. a "Wholesale pricing
/// active" banner on the cart/product screens).
@riverpod
bool isWholesalePricingActive(Ref ref) {
  return ref.watch(priceModeProvider) == PriceMode.wholesale;
}
