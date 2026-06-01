import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/notifications/notification_router.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/notification_provider.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/unread_count_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_live_sync_provider.dart';
import 'package:bakaloo_flutter_app/features/tracking/presentation/providers/order_status_stream_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_access.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/badge_count.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_route_loading_gate.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.navigationShell,
    required this.branchNavigatorKeys,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final selectedIndex = navigationShell.currentIndex;
    final liveSyncController = ref.read(orderLiveSyncControllerProvider);
    final authGate = ref.read(authGateControllerProvider);
    final routeLoadingController = ref.read(appRouteLoadingProvider.notifier);
    final currentBranchNavigator =
        branchNavigatorKeys[selectedIndex].currentState;
    final branchCanPop = currentBranchNavigator?.canPop() ?? false;

    final navBarHeight = 64.h + (bottomInset > 0 ? bottomInset + 4.h : 8.h);

    ref
      ..listen(socketNotificationStreamProvider, (previous, next) {
        next.whenData((event) {
          ref.read(notificationProvider.notifier).addSocketNotification(event);
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger == null) return;
          messenger
            ..clearMaterialBanners()
            ..showMaterialBanner(
              MaterialBanner(
                backgroundColor: AppColors.bgCard,
                leading: PhosphorIcon(
                  PhosphorIcons.bellRinging(),
                  color: AppColors.primaryGreen,
                ),
                content: Text(
                  '${event.title}\n${event.body}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      messenger.clearMaterialBanners();
                      final path = NotificationRouter.getPath(
                        <String, dynamic>{...event.data, 'type': event.type},
                      );
                      if (path != null && context.mounted) context.go(path);
                    },
                    child: const Text('Open'),
                  ),
                  TextButton(
                    onPressed: messenger.clearMaterialBanners,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            );
          ref.invalidate(unreadCountProvider);
          Future<void>.delayed(const Duration(seconds: 4), () {
            messenger.clearMaterialBanners();
          });
        });
      })
      ..listen(orderStatusStreamProvider, (previous, next) {
        next.whenData((event) {
          liveSyncController.handleStatusEvent(event);
        });
      });

    return PopScope(
      canPop: selectedIndex == 0 && !branchCanPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final currentNavigator =
            branchNavigatorKeys[selectedIndex].currentState;
        if (currentNavigator?.canPop() ?? false) {
          await currentNavigator!.maybePop();
          return;
        }
        if (selectedIndex != 0) navigationShell.goBranch(0);
      },
      child: Scaffold(
        extendBody: false,
        body: Stack(
          children: <Widget>[
            navigationShell,
            _CartPillHost(
              selectedIndex: selectedIndex,
              navBarHeight: navBarHeight,
              onTap: () {
                HapticFeedback.lightImpact();
                if (!authGate.isAuthenticated && context.mounted) {
                  authGate.protectRoute(
                    context,
                    route: RouteNames.cart,
                    title: 'Log in to view your cart',
                    message:
                        'Please log in first to review your items and continue to checkout.',
                  );
                  return;
                }
                navigationShell.goBranch(1);
              },
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                10.w,
                8.h,
                10.w,
                bottomInset > 0 ? 4.h : 8.h,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFEAEAEA)),
                ),
              ),
              child: Row(
                children: List<Widget>.generate(_tabs.length, (index) {
                  final tab = _tabs[index];
                  return Expanded(
                    child: _NavTabButton(
                      tab: tab,
                      selected: index == selectedIndex,
                      isCartTab: tab.path == RouteNames.cart,
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        if (index == selectedIndex) return;
                        final nextPath = tab.path;
                        if (RouteAccess.isProtectedTab(nextPath) &&
                            !authGate.isAuthenticated &&
                            context.mounted) {
                          await authGate.protectRoute(
                            context,
                            route: nextPath,
                            title: nextPath == RouteNames.cart
                                ? 'Log in to view your cart'
                                : 'Log in to open your profile',
                            message: nextPath == RouteNames.cart
                                ? 'Please log in first to review your items and continue to checkout.'
                                : 'Please log in first to access your profile, orders, saved addresses, and notifications.',
                          );
                          return;
                        }
                        await routeLoadingController.playForFooterNavigation(
                          () => navigationShell.goBranch(index),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartPillHost extends ConsumerWidget {
  const _CartPillHost({
    required this.selectedIndex,
    required this.navBarHeight,
    required this.onTap,
  });

  final int selectedIndex;
  final double navBarHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final showCartPill = cartCount > 0 && selectedIndex != 1;
    return Positioned(
      left: 16.w,
      right: 16.w,
      bottom: navBarHeight + 8.h,
      child: RepaintBoundary(
        child: AnimatedSlide(
          offset: showCartPill ? Offset.zero : const Offset(0, 1.5),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: showCartPill ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !showCartPill,
              child: _FloatingCartPill(cartCount: cartCount, onTap: onTap),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartTabBadge extends ConsumerWidget {
  const _CartTabBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    if (count <= 0) return const SizedBox.shrink();
    return BadgeCount(count: count);
  }
}

class _FloatingCartPill extends StatelessWidget {
  const _FloatingCartPill({
    required this.cartCount,
    required this.onTap,
  });

  final int cartCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52.h,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(26.r),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.40),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: <Widget>[
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$cartCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.sp,
                    height: 1.0,
                  ),
                ),
              ),
              Gap(10.w),
              Expanded(
                child: Text(
                  'View cart',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              PhosphorIcon(
                PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
                size: 18.sp,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.tab,
    required this.selected,
    required this.isCartTab,
    required this.onTap,
  });

  final AppShellTab tab;
  final bool selected;
  final bool isCartTab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? tab.activeIcon : tab.inactiveIcon;
    const activeColor = Color(0xFF35D86F);
    final iconColor = selected ? activeColor : const Color(0xFF171717);
    const labelColor = Color(0xFF171717);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 6.w),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 42.w,
                height: 28.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Center(
                      child: AnimatedScale(
                        scale: selected ? 1.06 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: PhosphorIcon(
                          icon,
                          size: 22.sp,
                          color: iconColor,
                        ),
                      ),
                    ),
                    if (isCartTab)
                      const Positioned(
                        right: -2,
                        top: -4,
                        child: _CartTabBadge(),
                      ),
                  ],
                ),
              ),
              Gap(4.h),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTextStyles.labelSmall.copyWith(
                  color: labelColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11.sp,
                ),
                child: Text(tab.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShellTab {
  AppShellTab({
    required this.label,
    required this.path,
    required this.inactiveIcon,
    required this.activeIcon,
  });

  final String label;
  final String path;
  final PhosphorIconData inactiveIcon;
  final PhosphorIconData activeIcon;
}

final List<AppShellTab> _tabs = <AppShellTab>[
  AppShellTab(
    label: 'Home',
    path: RouteNames.home,
    inactiveIcon: PhosphorIcons.house(),
    activeIcon: PhosphorIcons.house(PhosphorIconsStyle.fill),
  ),
  AppShellTab(
    label: 'Cart',
    path: RouteNames.cart,
    inactiveIcon: PhosphorIcons.basket(),
    activeIcon: PhosphorIcons.basket(PhosphorIconsStyle.fill),
  ),
  AppShellTab(
    label: 'Categories',
    path: RouteNames.categories,
    inactiveIcon: PhosphorIcons.gridFour(),
    activeIcon: PhosphorIcons.gridFour(PhosphorIconsStyle.fill),
  ),
  AppShellTab(
    label: 'Profile',
    path: RouteNames.profile,
    inactiveIcon: PhosphorIcons.user(),
    activeIcon: PhosphorIcons.user(PhosphorIconsStyle.fill),
  ),
];
