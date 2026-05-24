import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:open_file/open_file.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/active_order_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_live_sync_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';
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
  bool _isCancellingOrder = false;
  bool _isReordering = false;
  bool _isDownloadingInvoice = false;

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
    if (_isCancellingOrder) {
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
      _isCancellingOrder = true;
    });

    final result =
        await ref.read(orderListControllerProvider).cancelOrder(order.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isCancellingOrder = false;
    });

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (_) {
        ref
          ..invalidate(activeOrderProvider)
          ..invalidate(orderDetailProvider(order.id));
        _pagingController.refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully')),
        );
      },
    );
  }

  Future<void> _reorder(OrderEntity order) async {
    if (_isReordering) {
      return;
    }

    setState(() {
      _isReordering = true;
    });
    final result =
        await ref.read(orderListControllerProvider).reorder(order.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isReordering = false;
    });

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (data) {
        ref.invalidate(cartProvider);
        final warnings =
            data.warnings.isEmpty ? '' : '\n${data.warnings.join('\n')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Items added to cart$warnings'),
            action: SnackBarAction(
              label: 'View Cart',
              onPressed: () => context.go(RouteNames.cart),
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadInvoice(OrderEntity order) async {
    if (_isDownloadingInvoice) {
      return;
    }

    setState(() {
      _isDownloadingInvoice = true;
    });
    final result =
        await ref.read(orderListControllerProvider).downloadInvoice(order.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isDownloadingInvoice = false;
    });

    await result.fold(
      (failure) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (file) async {
        final openResult = await OpenFile.open(file.path);
        if (!mounted) {
          return;
        }
        if (openResult.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invoice downloaded: ${file.fileName}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(openResult.message)),
          );
        }
      },
    );
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
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('My Orders', style: AppTextStyles.h2),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 56.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final filter = OrderFilter.values[index];
                final selected = _currentFilter == filter;
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: selected,
                  onSelected: (_) => _changeFilter(filter),
                  selectedColor: AppColors.primaryGreenLight,
                  side: BorderSide(
                    color: selected
                        ? AppColors.primaryGreen
                        : AppColors.borderLight,
                  ),
                  labelStyle: AppTextStyles.buttonSmall.copyWith(
                    color: selected
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary,
                  ),
                );
              },
              separatorBuilder: (_, __) => Gap(10.w),
              itemCount: OrderFilter.values.length,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: PagedListView<int, OrderEntity>.separated(
                pagingController: _pagingController,
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
                separatorBuilder: (_, __) => Gap(12.h),
                builderDelegate: PagedChildBuilderDelegate<OrderEntity>(
                  itemBuilder: (context, order, index) {
                    return _OrderCard(
                      order: order,
                      isCancelling: _isCancellingOrder,
                      isReordering: _isReordering,
                      isDownloadingInvoice: _isDownloadingInvoice,
                      onTap: () => context.push('/orders/${order.id}'),
                      onTrack: () => context.push('/orders/${order.id}/track'),
                      onCancel: () => _cancelOrder(order),
                      onReorder: () => _reorder(order),
                      onDownloadInvoice: () => _downloadInvoice(order),
                      onRate: () => context.push(RouteNames.myReviews),
                    );
                  },
                  firstPageProgressIndicatorBuilder: (context) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    );
                  },
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
                  noItemsFoundIndicatorBuilder: (context) {
                    return const _OrdersEmptyState();
                  },
                  newPageProgressIndicatorBuilder: (_) => Padding(
                    padding: EdgeInsets.all(12.w),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  newPageErrorIndicatorBuilder: (_) => TextButton(
                    onPressed: _pagingController.retryLastFailedRequest,
                    child: const Text('Retry'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isCancelling,
    required this.isReordering,
    required this.isDownloadingInvoice,
    required this.onTap,
    required this.onTrack,
    required this.onCancel,
    required this.onReorder,
    required this.onDownloadInvoice,
    required this.onRate,
  });

  final OrderEntity order;
  final bool isCancelling;
  final bool isReordering;
  final bool isDownloadingInvoice;
  final VoidCallback onTap;
  final VoidCallback onTrack;
  final VoidCallback onCancel;
  final VoidCallback onReorder;
  final VoidCallback onDownloadInvoice;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final actions = _actionsForStatus(order.status);

    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border(
            left: BorderSide(
              color: order.status.isActive
                  ? AppColors.primaryGreen
                  : Colors.transparent,
              width: 3.w,
            ),
          ),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(status: order.status),
              ],
            ),
            Gap(6.h),
            Text(
              order.createdAt.toIndianDateTime,
              style: AppTextStyles.bodySmall,
            ),
            Gap(12.h),
            Row(
              children: <Widget>[
                _OrderItemThumbnails(items: order.items),
                Gap(10.w),
                Expanded(
                  child: Text(
                    '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  order.total.toInrCurrency,
                  style: AppTextStyles.h3.copyWith(fontSize: 17.sp),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...<Widget>[
              Gap(12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: actions.map((action) {
                  final isLoading = switch (action.type) {
                    _OrderActionType.cancel => isCancelling,
                    _OrderActionType.reorder => isReordering,
                    _OrderActionType.invoice => isDownloadingInvoice,
                    _OrderActionType.track || _OrderActionType.rate => false,
                  };

                  return action.type == _OrderActionType.track
                      ? FilledButton.icon(
                          onPressed: action.onTap,
                          icon: PhosphorIcon(
                            PhosphorIcons.navigationArrow(),
                            size: 14.sp,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.textOnGreen,
                          ),
                          label: Text(action.label),
                        )
                      : OutlinedButton(
                          onPressed: isLoading ? null : action.onTap,
                          child: isLoading
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(action.label),
                        );
                }).toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_OrderAction> _actionsForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.PENDING:
      case OrderStatus.CONFIRMED:
      case OrderStatus.PREPARING:
      case OrderStatus.PACKED:
      case OrderStatus.OUT_FOR_DELIVERY:
        return <_OrderAction>[
          _OrderAction(
            label: 'Track',
            type: _OrderActionType.track,
            onTap: onTrack,
          ),
          _OrderAction(
            label: 'Cancel',
            type: _OrderActionType.cancel,
            onTap: onCancel,
          ),
        ];
      case OrderStatus.DELIVERED:
        return <_OrderAction>[
          _OrderAction(
            label: 'Rate',
            type: _OrderActionType.rate,
            onTap: onRate,
          ),
          _OrderAction(
            label: 'Reorder',
            type: _OrderActionType.reorder,
            onTap: onReorder,
          ),
          _OrderAction(
            label: 'Invoice',
            type: _OrderActionType.invoice,
            onTap: onDownloadInvoice,
          ),
        ];
      case OrderStatus.CANCELLED:
        return <_OrderAction>[
          _OrderAction(
            label: 'Reorder',
            type: _OrderActionType.reorder,
            onTap: onReorder,
          ),
        ];
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: _statusBackground(status),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: _statusColor(status),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus value) {
    return switch (value) {
      OrderStatus.PENDING => const Color(0xFF8D6E63),
      OrderStatus.CONFIRMED => const Color(0xFF1976D2),
      OrderStatus.PREPARING => const Color(0xFF00897B),
      OrderStatus.PACKED => const Color(0xFF7B1FA2),
      OrderStatus.OUT_FOR_DELIVERY => AppColors.primaryGreen,
      OrderStatus.DELIVERED => AppColors.successGreen,
      OrderStatus.CANCELLED => AppColors.errorRed,
    };
  }

  Color _statusBackground(OrderStatus value) {
    return switch (value) {
      OrderStatus.PENDING => const Color(0xFFF3E5F5),
      OrderStatus.CONFIRMED => const Color(0xFFE3F2FD),
      OrderStatus.PREPARING => const Color(0xFFE0F2F1),
      OrderStatus.PACKED => const Color(0xFFF3E5F5),
      OrderStatus.OUT_FOR_DELIVERY => AppColors.primaryGreenLight,
      OrderStatus.DELIVERED => const Color(0xFFE8F5E9),
      OrderStatus.CANCELLED => const Color(0xFFFFEBEE),
    };
  }
}

class _OrderItemThumbnails extends StatelessWidget {
  const _OrderItemThumbnails({required this.items});

  final List<OrderItemEntity> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(3).toList(growable: false);
    final extra = items.length - visible.length;

    return SizedBox(
      width: 90.w,
      height: 28.w,
      child: Stack(
        children: <Widget>[
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: (i * 20).w,
              child: Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgCard, width: 1.5),
                ),
                child: ClipOval(
                  child: visible[i].thumbnailUrl == null
                      ? ColoredBox(
                          color: AppColors.bgInput,
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 14.sp,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: visible[i].thumbnailUrl!,
                          memCacheWidth: 300,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: AppColors.bgInput,
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 14.sp,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: (visible.length * 20).w,
              child: Container(
                width: 28.w,
                height: 28.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bgSection,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgCard, width: 1.5),
                ),
                child: Text(
                  '+$extra',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState();

  static const String _emptyBoxSvg = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <rect x="20" y="30" width="80" height="60" rx="8" fill="#F5F5F5" stroke="#D9D9D9" stroke-width="2"/>
  <path d="M30 45h60" stroke="#D9D9D9" stroke-width="2"/>
  <circle cx="46" cy="60" r="5" fill="#E0E0E0"/>
  <circle cx="74" cy="60" r="5" fill="#E0E0E0"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 72.h),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SvgPicture.string(_emptyBoxSvg, width: 100.w, height: 100.w),
            Gap(14.h),
            Text('No orders yet', style: AppTextStyles.h3),
            Gap(6.h),
            Text(
              'Start shopping to see your orders here.',
              style: AppTextStyles.bodyMedium,
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
            Gap(12.h),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OrderActionType { track, cancel, reorder, invoice, rate }

class _OrderAction {
  const _OrderAction({
    required this.label,
    required this.type,
    required this.onTap,
  });

  final String label;
  final _OrderActionType type;
  final VoidCallback onTap;
}
