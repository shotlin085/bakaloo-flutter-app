import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/order_notification_flags_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/active_order_provider.dart';

const Color kOrderBannerPurple = Color(0xFF6C4DFF);

/// The order-notification-settings timeline-type key each status maps to,
/// for looking it up in [orderNotificationFlagsProvider]'s flag map — kept
/// in sync with bakaloo-backend's order-notification-settings.js registry.
String? _notificationEventKeyFor(OrderStatus status) {
  switch (status) {
    case OrderStatus.PENDING:
    case OrderStatus.CONFIRMED:
      return 'CONFIRMED';
    case OrderStatus.PREPARING:
      return 'PREPARING';
    case OrderStatus.PACKED:
      return 'PACKED';
    case OrderStatus.OUT_FOR_DELIVERY:
      return 'PICKED_UP';
    case OrderStatus.DELIVERED:
    case OrderStatus.CANCELLED:
    case OrderStatus.REFUNDED:
      return null;
  }
}

/// Matches the wording already used elsewhere for order-status copy, so
/// nothing contradicts the Orders screen. Stays quiet (returns '') for a
/// status whose matching push/in-app notification is switched off in
/// Settings → Order Notifications — [notificationFlags] missing a key (still
/// loading, fetch failed) defaults to enabled, never to suppressed.
String _bannerMessageFor(OrderStatus status, Map<String, bool> notificationFlags) {
  final eventKey = _notificationEventKeyFor(status);
  if (eventKey != null && notificationFlags[eventKey] == false) {
    return '';
  }

  switch (status) {
    case OrderStatus.PENDING:
    case OrderStatus.CONFIRMED:
      return 'Your order is confirmed';
    case OrderStatus.PREPARING:
      return 'Your order is being packed';
    case OrderStatus.PACKED:
      return 'Your order is packed and ready';
    case OrderStatus.OUT_FOR_DELIVERY:
      return 'Your order is on the way 🚚';
    case OrderStatus.DELIVERED:
    case OrderStatus.CANCELLED:
    case OrderStatus.REFUNDED:
      return '';
  }
}

/// Owns the "is there a fresh order-status banner to show right now" state.
///
/// A single source of truth (rather than each widget re-deriving it) so the
/// banner itself and [OrderTrackingTopBanner]'s home-screen layout neighbor
/// (which needs to know whether to give the banner room) never disagree.
///
/// Every *new* status push (a fresh `orderId::status` pair) is shown for a
/// brief window and then auto-hides itself — it doesn't stay glued to the
/// screen for as long as the order remains in that status.
class OrderTrackingBannerController extends Notifier<String> {
  static const _visibleDuration = Duration(seconds: 5);

  Timer? _hideTimer;
  String? _trackedKey;
  String? _dismissedKey;

  @override
  String build() {
    ref.onDispose(() => _hideTimer?.cancel());

    final activeOrderAsync = ref.watch(activeOrderProvider);
    final notificationFlags =
        ref.watch(orderNotificationFlagsProvider).asData?.value ?? const <String, bool>{};

    // `handleStatusEvent` (order_live_sync_provider.dart) invalidates
    // activeOrderProvider on *every* socket push — including ones that
    // don't actually change the coarse status (rider-location pings,
    // duplicate events, the second invalidate after its own REST refetch).
    // Each invalidation briefly re-enters this loading state. Treating a
    // valueless loading blip the same as "no active order" would reset
    // _trackedKey to null, so the very next resolve looks like a *new*
    // status and restarts the 5-second timer from scratch — the banner
    // would then never get far enough into its countdown to actually
    // disappear. Only a *settled* loading/error/no-order result should
    // clear tracking; an in-flight refetch should change nothing.
    if (activeOrderAsync.isLoading && !activeOrderAsync.hasValue) {
      return state;
    }

    final activeOrder = activeOrderAsync.value;
    final rawMessage = (activeOrder != null && activeOrder.status.isActive)
        ? _bannerMessageFor(activeOrder.status, notificationFlags)
        : '';

    if (rawMessage.isEmpty) {
      _trackedKey = null;
      _dismissedKey = null;
      _hideTimer?.cancel();
      return '';
    }

    final key = '${activeOrder!.id}::${activeOrder.status.name}';
    if (key != _trackedKey) {
      _trackedKey = key;
      _dismissedKey = null;
      _hideTimer?.cancel();
      _hideTimer = Timer(_visibleDuration, () {
        _dismissedKey = key;
        state = '';
      });
    }

    return key == _dismissedKey ? '' : rawMessage;
  }
}

final orderTrackingBannerProvider =
    NotifierProvider<OrderTrackingBannerController, String>(
  OrderTrackingBannerController.new,
);

/// A structural — not floating — purple strip shown at the very top of the
/// Home screen, directly above `HomeHeader`. It occupies real layout space
/// (pushing the header down) instead of overlaying it, and collapses back
/// to zero height a few seconds after each new status update — the header
/// slides back up to normal once it's gone.
class OrderTrackingTopBanner extends ConsumerWidget {
  const OrderTrackingTopBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(orderTrackingBannerProvider);
    final activeOrderId = ref.watch(activeOrderProvider).value?.id;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: message.isEmpty || activeOrderId == null
          ? const SizedBox(width: double.infinity)
          : _BannerBody(
              key: ValueKey(message),
              message: message,
              onTap: () => context.push('/orders/$activeOrderId'),
            ),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.message, required this.onTap, super.key});

  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipPath(
        clipper: const _ScallopedWaveClipper(),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20.w, topInset + 12.h, 20.w, 26.h),
          color: kOrderBannerPurple,
          alignment: Alignment.center,
          child: Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 15.5.sp,
              color: Colors.white,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}

/// Repeating scalloped bottom edge — several soft bumps across the width,
/// matching the reference design's wavy bottom border.
class _ScallopedWaveClipper extends CustomClipper<Path> {
  const _ScallopedWaveClipper({this.waveCount = 5, this.waveHeight = 12});

  final int waveCount;
  final double waveHeight;

  @override
  Path getClip(Size size) {
    final double base = size.height - waveHeight;
    final double waveWidth = size.width / waveCount;
    final path = Path()..lineTo(0, base);

    for (int i = 0; i < waveCount; i++) {
      final double startX = i * waveWidth;
      final double midX = startX + waveWidth / 2;
      final double endX = startX + waveWidth;
      path.quadraticBezierTo(midX, base + waveHeight, endX, base);
    }

    return path
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
