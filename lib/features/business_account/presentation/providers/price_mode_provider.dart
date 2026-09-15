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
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/home_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_list_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/recently_viewed_provider.dart';
import 'package:bakaloo_flutter_app/features/search/presentation/providers/search_provider.dart';

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
    final initial =
        cached == 'wholesale' ? PriceMode.wholesale : PriceMode.retail;

    // Watching starts the live account lookup for every app launch. The
    // previous listen-only implementation could keep the Hive "retail"
    // launch guess indefinitely when the account response had already
    // completed before the listener was registered. That meant a customer
    // with approved B2B enabled sent no `priceMode=wholesale` at all.
    final account = ref.watch(myBusinessAccountProvider).asData?.value;
    final liveMode =
        account != null && account.status == 'APPROVED' && account.b2bEnabled
            ? PriceMode.wholesale
            : initial;

    if (account != null && liveMode != initial) {
      unawaited(_persist(liveMode));
      // The ref.listen below only fires for CHANGES from the point it's
      // (re-)registered onward — it can never observe the very
      // loading->data transition that this build() call is already
      // reacting to via its own ref.watch above, because that listen is
      // torn down and freshly re-attached on every rebuild, including
      // this one. Net effect without this call: state/the toggle
      // correctly flip to wholesale (or back to retail), but Home/
      // Category/Search/product-detail — already fetched under the stale
      // Hive launch guess — never get invalidated, so they keep
      // rendering the wrong mode's prices until something unrelated
      // happens to refetch them (pull-to-refresh, leaving and
      // re-entering a screen, ...). Reported: B2B toggle showed active
      // on Profile, but Home/Search/Category still showed retail prices
      // and a quantity of 1 instead of the bulk minimum.
      unawaited(_clearPriceSensitiveState());
    }

    // Self-correct as soon as the live business-account status is known —
    // the Hive value above is only ever a same-session fast-launch guess.
    ref.listen(myBusinessAccountProvider, (previous, next) {
      final account = next.asData?.value;
      final eligible =
          account != null && account.status == 'APPROVED' && account.b2bEnabled;
      final corrected = eligible ? PriceMode.wholesale : PriceMode.retail;
      if (corrected != state) {
        state = corrected;
        unawaited(_persist(corrected));
        // A live account refresh can correct the Hive launch guess without
        // going through toggle(). Invalidate the same price-sensitive state
        // here, otherwise category/search can retain B2C cards.
        unawaited(_clearPriceSensitiveState());
      }
    });

    return liveMode;
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
        final next =
            account.b2bEnabled ? PriceMode.wholesale : PriceMode.retail;
        state = next;
        await _persist(next);
        ref.invalidate(myBusinessAccountProvider);

        // Keep the cached auth identity's b2bEnabled in sync so it survives
        // an app restart even before the next /business-accounts/me fetch.
        // Must be awaited, not fire-and-forget: restoreSession() on the
        // NEXT cold start reads this exact cached user to seed the
        // fast-launch price mode guess (_syncPriceModeLaunchCache). An
        // unawaited write here raced the app being closed right after a
        // toggle — the write could still be in flight when the process
        // died, so the next launch read the pre-toggle snapshot and opened
        // on the wrong mode. Reported: toggle B2B on, close/reopen the app
        // shortly after, and it comes back on retail.
        final authState = ref.read(authStateProvider);
        if (authState is AuthAuthenticated) {
          await ref.read(authNotifierProvider.notifier).syncCachedUser(
                authState.user.copyWith(
                  b2bStatus: account.status,
                  b2bEnabled: account.b2bEnabled,
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
  ///
  /// clearPriceSensitiveCaches() only clears the on-disk Hive box these
  /// fetches persist to — it does nothing to an already-built Riverpod
  /// provider sitting in memory with the old mode's result, which is what
  /// Home/Category/Search/Product-detail actually render from while
  /// mounted. Each one needs its own explicit ref.invalidate() the same way
  /// cartProvider and the section-manifest family already get below.
  /// Reported: toggling wholesale updated the cart correctly but left
  /// Home, Category, Search, and the product detail page all still
  /// showing retail prices and quantities until a cold restart.
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
      ref
        ..invalidate(sectionManifestProvider)
        ..invalidate(activeSectionManifestProvider);
    } catch (_) {}
    try {
      await ref.read(managedThemeRefreshProvider.notifier).refresh();
    } catch (_) {}
    // Every provider that fetches priced product data outside the Tab Home
    // Content system above (which managedThemeRefreshProvider.refresh()
    // already covers) — Home's featured/new-arrivals/deals/trending/
    // per-category rails, Category's product shelf, Search results, and
    // the product detail page (plus its related/pair-with/recently-viewed
    // rails). invalidate() on a family clears every cached instance of it.
    try {
      ref
        ..invalidate(homeProvider)
        ..invalidate(homeFeaturedProductsProvider)
        ..invalidate(homeNewArrivalsProvider)
        ..invalidate(homeDealsProvider)
        ..invalidate(homeTrendingProductsProvider)
        ..invalidate(homeCategoryProductsProvider)
        ..invalidate(categoryProductShelfProvider)
        ..invalidate(productListProvider)
        ..invalidate(searchProvider)
        ..invalidate(productDetailProvider)
        ..invalidate(relatedProductsProvider)
        ..invalidate(pairWithProductsProvider)
        ..invalidate(recentlyViewedProductsProvider);
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
