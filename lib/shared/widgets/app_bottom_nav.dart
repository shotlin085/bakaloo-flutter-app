import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_route_loading_gate.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    required this.navigationShell,
    required this.branchNavigatorKeys,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  // Drives the footer nav reveal. 1.0 = fully visible, 0.0 = hidden.
  late final AnimationController _navController;
  late final Animation<double> _navAnimation;

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 200),
      value: 1,
    );
    _navAnimation = CurvedAnimation(
      parent: _navController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  void _showNav() {
    if (_navController.status != AnimationStatus.completed) {
      _navController.forward();
    }
  }

  void _hideNav() {
    if (_navController.status != AnimationStatus.dismissed) {
      _navController.reverse();
    }
  }

  bool _handleScroll(UserScrollNotification notification) {
    // Ignore horizontal scrollers (carousels, chip rows) — only vertical
    // page scrolling should toggle the footer.
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    // Keep the bar visible when the content isn't tall enough to scroll.
    if (notification.metrics.maxScrollExtent <= 0) {
      _showNav();
      return false;
    }
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _hideNav();
      case ScrollDirection.forward:
        _showNav();
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final branchNavigatorKeys = widget.branchNavigatorKeys;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final selectedIndex = navigationShell.currentIndex;
    final liveSyncController = ref.read(orderLiveSyncControllerProvider);
    final authGate = ref.read(authGateControllerProvider);
    final routeLoadingController = ref.read(appRouteLoadingProvider.notifier);
    final currentBranchNavigator =
        branchNavigatorKeys[selectedIndex].currentState;
    final branchCanPop = currentBranchNavigator?.canPop() ?? false;

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
            NotificationListener<UserScrollNotification>(
              onNotification: _handleScroll,
              child: navigationShell,
            ),
            _CartPillHost(
              selectedIndex: selectedIndex,
              navAnimation: _navAnimation,
              bottomInset: bottomInset,
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
        bottomNavigationBar: SizeTransition(
          sizeFactor: _navAnimation,
          axisAlignment: -1,
          child: DecoratedBox(
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
                  4.h,
                  12.w,
                  bottomInset > 0 ? 2.h : 4.h,
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
                            // Remember the intent then go directly to phone screen
                            // (avoids stale context issue after bottom sheet closes)
                            authGate.rememberRouteIntent(nextPath);
                            if (context.mounted) {
                              context.push(RouteNames.phone);
                            }
                            return;
                          }
                          // Reveal the footer whenever the user switches tabs.
                          _showNav();
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
      ),
    );
  }
}

class _CartPillHost extends ConsumerWidget {
  const _CartPillHost({
    required this.selectedIndex,
    required this.navAnimation,
    required this.bottomInset,
    required this.onTap,
  });

  final int selectedIndex;
  final Animation<double> navAnimation;
  final double bottomInset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: productOptionSheetVisible,
      builder: (context, isSheetOpen, _) {
        final showCartPill = cartCount > 0 && !isSheetOpen;
    // Pill sits just above the bottom nav (≈12dp gap), centred horizontally,
    // and spans ~60% of the screen width — never full-width, never mid-screen.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pillWidth = (screenWidth * 0.60).clamp(220.0, 360.0);
    // When the footer nav is hidden the body grows to the screen edge, so the
    // pill must keep a comfortable gap above the bottom safe area instead of
    // dropping under the home indicator. The body's bottom reference moves with
    // the nav's SizeTransition, so we add back just enough to (a) keep an 8.h
    // gap above the nav when shown, and (b) clear the safe area when hidden —
    // letting the pill glide down with the nav without ever clipping.
    final hiddenGap = bottomInset > 0 ? bottomInset : 10.h;
    return AnimatedBuilder(
      animation: navAnimation,
      builder: (context, child) {
        // navAnimation: 1 = nav visible, 0 = nav hidden.
        final bottomOffset = 8.h + hiddenGap * (1 - navAnimation.value);
        return Positioned(
          bottom: bottomOffset,
          left: 0,
          right: 0,
          child: child!,
        );
      },
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
      },
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
          padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 6.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 48.w,
                height: 30.h,
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Image.asset(
                            iconAsset,
                            width: 28.w,
                            height: 28.h,
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
                              width: 28.w,
                              height: 28.h,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                  ),
                ),
              ),
              Gap(3.h),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTextStyles.labelSmall.copyWith(
                  color: labelColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.sp,
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
