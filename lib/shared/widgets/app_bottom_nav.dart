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
                context.push(RouteNames.cart);
              },
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFBF9FF),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                12.w,
                10.h,
                12.w,
                bottomInset > 0 ? 4.h : 10.h,
              ),
              child: Row(
                children: List<Widget>.generate(_tabs.length, (index) {
                  final tab = _tabs[index];
                  return Expanded(
                    child: _NavTabButton(
                      tab: tab,
                      selected: index == selectedIndex,
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
                            title: nextPath == RouteNames.orders
                                ? 'Log in to view your orders'
                                : 'Log in to open your profile',
                            message: nextPath == RouteNames.orders
                                ? 'Please log in first to track and manage your orders.'
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
    final showCartPill = cartCount > 0;
    // Pill sits just above the bottom nav (≈12dp gap), centred horizontally,
    // and spans ~60% of the screen width — never full-width, never mid-screen.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pillWidth = (screenWidth * 0.60).clamp(220.0, 360.0);
    return Positioned(
      bottom: 8.h,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !showCartPill,
        child: Center(
          child: RepaintBoundary(
            child: AnimatedSlide(
              offset: showCartPill ? Offset.zero : const Offset(0, 1.5),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: showCartPill ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: SizedBox(
                  width: pillWidth,
                  child: _FloatingCartPill(cartCount: cartCount, onTap: onTap),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    const Color pillColor = Color(0xFF6C4DFF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56.h,
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: Row(
            children: <Widget>[
              // Leading cart icon in a soft translucent circle.
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: PhosphorIcon(
                  PhosphorIcons.basket(PhosphorIconsStyle.fill),
                  size: 17.sp,
                  color: Colors.white,
                ),
              ),
              Gap(10.w),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'View cart',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.sp,
                        letterSpacing: 0.1,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      '$cartCount item${cartCount == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        fontSize: 11.sp,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(6.w),
              PhosphorIcon(
                PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
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
    required this.onTap,
  });

  final AppShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color activeColor = Color(0xFF6C4DFF);
    const Color inactiveColor = Color(0xFF1A1A1A);
    final String iconAsset = selected ? tab.activeIcon : tab.inactiveIcon;
    final Color labelColor = selected ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 48.w,
                height: 36.h,
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Image.asset(
                            iconAsset,
                            width: 34.w,
                            height: 34.h,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          )
                        : ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF1A1A1A),
                              BlendMode.srcIn,
                            ),
                            child: Image.asset(
                              iconAsset,
                              width: 34.w,
                              height: 34.h,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                  ),
                ),
              ),
              Gap(6.h),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTextStyles.labelSmall.copyWith(
                  color: labelColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.sp,
                ),
                child: Text(tab.label),
              ),
              Gap(6.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 3.h,
                width: selected ? 22.w : 0,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
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
  final String inactiveIcon;
  final String activeIcon;
}

const String _footerIconBase = 'assets/icon/footer_icon';

final List<AppShellTab> _tabs = <AppShellTab>[
  AppShellTab(
    label: 'Home',
    path: RouteNames.home,
    inactiveIcon: '$_footerIconBase/bakaloo-home-outline-icon.png',
    activeIcon: '$_footerIconBase/bakaloo-home-filled-icon.png',
  ),
  AppShellTab(
    label: 'Orders',
    path: RouteNames.orders,
    inactiveIcon: '$_footerIconBase/bakaloo-orders-outline-icon.png',
    activeIcon: '$_footerIconBase/bakaloo-orders-filled-icon.png',
  ),
  AppShellTab(
    label: 'Categories',
    path: RouteNames.categories,
    inactiveIcon: '$_footerIconBase/bakaloo-categories-outline-icon.png',
    activeIcon: '$_footerIconBase/bakaloo-categories-filled-icon.png',
  ),
  AppShellTab(
    label: 'Profile',
    path: RouteNames.profile,
    inactiveIcon: '$_footerIconBase/bakaloo-profile-outline-icon.png',
    activeIcon: '$_footerIconBase/bakaloo-profile-filled-icon.png',
  ),
];
