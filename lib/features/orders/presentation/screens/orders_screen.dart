import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/active_order_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_live_sync_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_card.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_card_skeleton.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_filter_tabs.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/confirmation_dialog.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const int _limit = 10;

  final PagingController<int, OrderEntity> _pagingController =
      PagingController<int, OrderEntity>(firstPageKey: 1);

  OrderFilter _currentFilter = OrderFilter.all;
  final Set<String> _cancellingIds = <String>{};
  final Set<String> _reorderingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await ref.read(orderListControllerProvider).fetchPage(
          filter: _currentFilter,
          page: pageKey,
          limit: _limit,
        );

    result.fold(
      (failure) {
        _pagingController.error = StateError(failure.message);
      },
      (pageResult) {
        final isLastPage = pageResult.pagination.totalPages == 0 ||
            pageResult.pagination.page >= pageResult.pagination.totalPages ||
            pageResult.orders.length < _limit;

        if (isLastPage) {
          _pagingController.appendLastPage(pageResult.orders);
        } else {
          _pagingController.appendPage(pageResult.orders, pageKey + 1);
        }
      },
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(activeOrderProvider);
    _pagingController.refresh();
  }

  void _changeFilter(OrderFilter filter) {
    if (_currentFilter == filter) {
      return;
    }

    setState(() {
      _currentFilter = filter;
    });
    _pagingController.refresh();
  }

  Future<void> _cancelOrder(OrderEntity order) async {
    if (_cancellingIds.contains(order.id)) {
      return;
    }

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Cancel Order?',
      message: 'Do you really want to cancel ${order.orderNumber}?',
      confirmLabel: 'Cancel Order',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _cancellingIds.add(order.id);
    });

    final result =
        await ref.read(orderListControllerProvider).cancelOrder(order.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _cancellingIds.remove(order.id);
    });

    result.fold(
      (failure) {
        _showSnackBar(failure.message);
      },
      (_) {
        ref
          ..invalidate(activeOrderProvider)
          ..invalidate(orderDetailProvider(order.id));
        _pagingController.refresh();
        _showSnackBar('Order cancelled successfully');
      },
    );
  }

  Future<void> _reorder(OrderEntity order) async {
    if (_reorderingIds.contains(order.id)) {
      return;
    }

    setState(() {
      _reorderingIds.add(order.id);
    });
    final result =
        await ref.read(orderListControllerProvider).reorder(order.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _reorderingIds.remove(order.id);
    });

    result.fold(
      (failure) {
        _showSnackBar(failure.message);
      },
      (data) {
        ref.invalidate(cartProvider);
        final warnings =
            data.warnings.isEmpty ? '' : '\n${data.warnings.join('\n')}';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Items added to cart$warnings'),
              action: SnackBarAction(
                label: 'View Cart',
                onPressed: () => context.push(RouteNames.cart),
              ),
            ),
          );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(orderListRefreshTickProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      _pagingController.refresh();
    });

    return Scaffold(
      backgroundColor: AppColors.orderCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const _OrdersHeader(),
            Gap(4.h),
            OrderFilterTabs(
              selected: _currentFilter,
              onSelected: _changeFilter,
            ),
            Gap(8.h),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.orderViolet,
                onRefresh: _refresh,
                child: PagedListView<int, OrderEntity>.separated(
                  pagingController: _pagingController,
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                  separatorBuilder: (_, __) => Gap(14.h),
                  builderDelegate: PagedChildBuilderDelegate<OrderEntity>(
                    animateTransitions: true,
                    itemBuilder: (context, order, index) {
                      return RepaintBoundary(
                        child: OrderCard(
                          order: order,
                          isCancelling: _cancellingIds.contains(order.id),
                          isReordering: _reorderingIds.contains(order.id),
                          onTap: () => context.push('/orders/${order.id}'),
                          onTrack: () =>
                              context.push('/orders/${order.id}/track'),
                          onCancel: () => _cancelOrder(order),
                          onReorder: () => _reorder(order),
                          onViewDetails: () =>
                              context.push('/orders/${order.id}'),
                        ),
                      );
                    },
                    firstPageProgressIndicatorBuilder: (context) =>
                        const _OrdersLoadingList(),
                    firstPageErrorIndicatorBuilder: (context) {
                      final error = _pagingController.error;
                      final message = error is StateError
                          ? error.message.toString()
                          : 'Unable to load orders.';
                      return _OrdersErrorState(
                        message: message,
                        onRetry: _pagingController.refresh,
                      );
                    },
                    noItemsFoundIndicatorBuilder: (context) =>
                        const _OrdersEmptyState(),
                    newPageProgressIndicatorBuilder: (_) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.orderViolet,
                        ),
                      ),
                    ),
                    newPageErrorIndicatorBuilder: (_) => Center(
                      child: TextButton(
                        onPressed: _pagingController.retryLastFailedRequest,
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: AppColors.orderViolet),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersHeader extends ConsumerWidget {
  const _OrdersHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 16.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _HeaderIconButton(
            icon: PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
            semanticLabel: 'Back',
            onTap: () =>
                context.canPop() ? context.pop() : context.go(RouteNames.home),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('My Orders', style: AppTextStyles.h1),
                SizedBox(height: 2.h),
                Text(
                  'Track and manage your grocery orders',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          _HeaderIconButton(
            icon: PhosphorIcons.handbag(PhosphorIconsStyle.bold),
            semanticLabel: 'Cart',
            badgeCount: cartCount,
            onTap: () => context.push(RouteNames.cart),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.badgeCount = 0,
  });

  final PhosphorIconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48.w,
          height: 48.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 42.w,
                height: 42.w,
                decoration: const BoxDecoration(
                  color: AppColors.orderVioletSurface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: PhosphorIcon(
                    icon,
                    size: 20.sp,
                    color: AppColors.orderViolet,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 2.w,
                  top: 2.h,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    constraints: BoxConstraints(minWidth: 16.w),
                    decoration: BoxDecoration(
                      color: AppColors.orderStatusRed,
                      borderRadius: BorderRadius.circular(100.r),
                      border:
                          Border.all(color: AppColors.orderCanvas, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersLoadingList extends StatelessWidget {
  const _OrdersLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < 4; i++) ...<Widget>[
          const OrderCardSkeleton(),
          Gap(14.h),
        ],
      ],
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState();

  static const String _emptyBoxSvg = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <rect x="20" y="34" width="80" height="58" rx="10" fill="#F3EEFE" stroke="#E2D6F9" stroke-width="2"/>
  <path d="M20 50h80" stroke="#E2D6F9" stroke-width="2"/>
  <circle cx="46" cy="70" r="6" fill="#D9C8F5"/>
  <circle cx="74" cy="70" r="6" fill="#D9C8F5"/>
  <path d="M48 26l12 12 12-12" fill="none" stroke="#B79AEC" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 80.h),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SvgPicture.string(_emptyBoxSvg, width: 110.w, height: 110.w),
            Gap(16.h),
            Text('No orders yet', style: AppTextStyles.h3),
            Gap(6.h),
            Text(
              'Start shopping to see your orders here.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersErrorState extends StatelessWidget {
  const _OrdersErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.warningCircle(),
              size: 42.sp,
              color: AppColors.warningOrange,
            ),
            Gap(12.h),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            Gap(16.h),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orderViolet,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
