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
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/notification_provider.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/unread_count_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/active_order_provider.dart';
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
              onTapCart: () {
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

/// The states the Smart Bottom Bar can be in, in priority order (first
/// matching state wins — see [_resolveSmartBarState]).
enum _SmartBarStateKind {
  orderTracking,
  milestoneProgress,
  freeDeliveryUnlocked,
  plainCart,
}

class _SmartBarState {
  const _SmartBarState.orderTracking({
    required this.orderId,
    required this.message,
  })  : kind = _SmartBarStateKind.orderTracking,
        cartCount = 0,
        amountToUnlock = 0,
        progress = 0;

  const _SmartBarState.milestone({
    required this.cartCount,
    required this.amountToUnlock,
    required this.progress,
  })  : kind = _SmartBarStateKind.milestoneProgress,
        orderId = null,
        message = null;

  const _SmartBarState.freeDeliveryUnlocked({required this.cartCount})
      : kind = _SmartBarStateKind.freeDeliveryUnlocked,
        orderId = null,
        message = null,
        amountToUnlock = 0,
        progress = 1;

  const _SmartBarState.plainCart({required this.cartCount})
      : kind = _SmartBarStateKind.plainCart,
        orderId = null,
        message = null,
        amountToUnlock = 0,
        progress = 0;

  final _SmartBarStateKind kind;
  final String? orderId;
  final String? message;
  final int cartCount;
  final double amountToUnlock;
  final double progress;
}

/// Maps an active order's status to the short message shown in the bar.
String _orderTrackingMessage(OrderStatus status) {
  switch (status) {
    case OrderStatus.PENDING:
    case OrderStatus.CONFIRMED:
      return 'Your order is confirmed';
    case OrderStatus.PREPARING:
      return 'Your order is being packed';
    case OrderStatus.PACKED:
      return 'Your order is packed and ready';
    case OrderStatus.OUT_FOR_DELIVERY:
      return 'Rider is on the way';
    case OrderStatus.DELIVERED:
    case OrderStatus.CANCELLED:
      return '';
  }
}

class _CartPillHost extends ConsumerWidget {
  const _CartPillHost({
    required this.selectedIndex,
    required this.navAnimation,
    required this.bottomInset,
    required this.onTapCart,
  });

  final int selectedIndex;
  final Animation<double> navAnimation;
  final double bottomInset;
  final VoidCallback onTapCart;

  /// The bar should only appear on product-related tabs:
  /// 0 = Home (includes search, product detail sub-routes)
  /// 2 = Categories (includes category product pages)
  /// NOT on Orders (1) or Profile (3) or address/settings sub-pages.
  static bool _isProductTab(int tabIndex) => tabIndex == 0 || tabIndex == 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final activeOrderAsync = ref.watch(activeOrderProvider);
    final billSummaryAsync =
        cartCount > 0 ? ref.watch(billSummaryProvider) : null;

    final activeOrder = activeOrderAsync.value;
    final billSummary = billSummaryAsync?.value;

    _SmartBarState? state;
    if (activeOrder != null && activeOrder.status.isActive) {
      final message = _orderTrackingMessage(activeOrder.status);
      if (message.isNotEmpty) {
        state = _SmartBarState.orderTracking(
          orderId: activeOrder.id,
          message: message,
        );
      }
    }
    if (state == null && cartCount > 0) {
      final free = billSummary?.freeDelivery;
      if (free != null && free.enabled && !free.unlocked && free.amountToUnlock > 0) {
        final threshold = free.threshold ?? 0;
        final progress = threshold > 0
            ? (1 - (free.amountToUnlock / threshold)).clamp(0.0, 1.0)
            : 0.0;
        state = _SmartBarState.milestone(
          cartCount: cartCount,
          amountToUnlock: free.amountToUnlock,
          progress: progress,
        );
      } else if (free != null && free.unlocked) {
        state = _SmartBarState.freeDeliveryUnlocked(cartCount: cartCount);
      } else {
        state = _SmartBarState.plainCart(cartCount: cartCount);
      }
    }

    // Full-width bar with a comfortable side margin, sitting just above the
    // bottom nav. When the footer nav is hidden the body grows to the screen
    // edge, so we keep a comfortable gap above the safe area instead of
    // dropping under the home indicator — the bar glides down with the nav
    // without ever clipping.
    final hiddenGap = bottomInset > 0 ? bottomInset : 10.h;
    final horizontalMargin = 12.w;

    return ValueListenableBuilder<bool>(
      valueListenable: productOptionSheetVisible,
      builder: (context, isProductSheetOpen, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: addressSheetVisible,
          builder: (context, isAddressSheetOpen, _) {
            final showBar = state != null &&
                !isProductSheetOpen &&
                !isAddressSheetOpen &&
                _isProductTab(selectedIndex);
            return AnimatedBuilder(
              animation: navAnimation,
              builder: (context, child) {
                final bottomOffset =
                    8.h + hiddenGap * (1 - navAnimation.value);
                return Positioned(
                  bottom: bottomOffset,
                  left: horizontalMargin,
                  right: horizontalMargin,
                  child: child!,
                );
              },
              child: IgnorePointer(
                ignoring: !showBar,
                child: RepaintBoundary(
                  child: AnimatedSlide(
                    offset: showBar ? Offset.zero : const Offset(0, 1.5),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: showBar ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: state == null
                          ? const SizedBox.shrink()
                          : _SmartBottomBar(
                              state: state,
                              onTap: () {
                                if (state!.kind ==
                                        _SmartBarStateKind.orderTracking &&
                                    state.orderId != null) {
                                  context.push(
                                    '/orders/${state.orderId}/track',
                                  );
                                } else {
                                  onTapCart();
                                }
                              },
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SmartBottomBar extends StatelessWidget {
  const _SmartBottomBar({
    required this.state,
    required this.onTap,
  });

  final _SmartBarState state;
  final VoidCallback onTap;

  static const Color _barColor = Color(0xFF6C4DFF);
  static const Color _successColor = Color(0xFF12B76A);

  @override
  Widget build(BuildContext context) {
    final bool isTracking = state.kind == _SmartBarStateKind.orderTracking;
    final bool isUnlocked =
        state.kind == _SmartBarStateKind.freeDeliveryUnlocked;
    final Color barColor = isUnlocked ? _successColor : _barColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: barColor.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 12.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: _buildMessage(context)),
                  Gap(10.w),
                  if (!isTracking) _buildCartSummary(context),
                  Gap(6.w),
                  PhosphorIcon(
                    PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                    size: 18.sp,
                    color: Colors.white,
                  ),
                ],
              ),
              if (state.kind == _SmartBarStateKind.milestoneProgress) ...<Widget>[
                Gap(10.h),
                _ProgressLine(progress: state.progress),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    switch (state.kind) {
      case _SmartBarStateKind.orderTracking:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.moped(PhosphorIconsStyle.fill),
              size: 18.sp,
              color: Colors.white,
            ),
            Gap(8.w),
            Flexible(
              child: Text(
                state.message ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        );
      case _SmartBarStateKind.milestoneProgress:
        return RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
              height: 1.25,
            ),
            children: <InlineSpan>[
              TextSpan(text: 'Add ₹${state.amountToUnlock.toStringAsFixed(0)} more to unlock '),
              TextSpan(
                text: 'FREE DELIVERY',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp),
              ),
            ],
          ),
        );
      case _SmartBarStateKind.freeDeliveryUnlocked:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
              size: 18.sp,
              color: Colors.white,
            ),
            Gap(8.w),
            Flexible(
              child: Text(
                'Free delivery unlocked',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        );
      case _SmartBarStateKind.plainCart:
        return Text(
          'View cart',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15.sp,
          ),
        );
    }
  }

  Widget _buildCartSummary(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              'CART',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11.sp,
                letterSpacing: 0.4,
                height: 1.1,
              ),
            ),
            Text(
              '${state.cartCount} ITEM${state.cartCount == 1 ? '' : 'S'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                fontSize: 9.5.sp,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
          ],
        ),
        Gap(8.w),
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8.r),
          ),
          alignment: Alignment.center,
          child: PhosphorIcon(
            PhosphorIcons.basket(PhosphorIconsStyle.fill),
            size: 16.sp,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Thin rounded progress track shown under the milestone message — a
/// lightweight, bottom-bar-specific indicator (the fuller bill-summary
/// progress widget on the cart screen has different sizing/styling needs).
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.r),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            children: <Widget>[
              Container(
                height: 5.h,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.r),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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
                width: 56.w,
                height: 38.h,
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Image.asset(
                            iconAsset,
                            width: 36.w,
                            height: 36.h,
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
                              width: 36.w,
                              height: 36.h,
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
