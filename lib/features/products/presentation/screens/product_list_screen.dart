import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_list_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/empty_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({
    this.categoryId,
    this.title = 'Products',
    super.key,
  });

  final String? categoryId;
  final String title;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  late final ScrollController _scrollController;

  ProductListParams get _params => ProductListParams(
        categoryId: widget.categoryId,
        title: widget.title,
      );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent * 0.8;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(productListProvider(_params).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final productListAsync = ref.watch(productListProvider(_params));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(widget.title)),
      body: productListAsync.when(
        loading: _buildLoading,
        error: (error, stackTrace) => ErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: () {
            ref.read(productListProvider(_params).notifier).refresh();
          },
        ),
        data: (viewState) {
          if (viewState.items.isEmpty) {
            return const EmptyState(
              title: 'No products yet',
              message: 'Products will appear here when inventory is available.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(productListProvider(_params).notifier).refresh();
              await ref.read(productListProvider(_params).future);
            },
            color: AppColors.primaryGreen,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                if (viewState.isStale)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellowLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                      child: Text(
                        'Showing cached products. Reconnect to refresh the latest inventory.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.all(16.w),
                  sliver: SliverGrid.builder(
                    itemCount: viewState.items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                      mainAxisExtent: 246.h,
                    ),
                    itemBuilder: (context, index) {
                      final product = viewState.items[index];
                      return RepaintBoundary(
                        child: ProductCard(
                          product: product,
                          style: ProductCardStyle.grid,
                          onTap: () => context.push('/product/${product.id}'),
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                    child: Column(
                      children: <Widget>[
                        if (viewState.isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        if (viewState.paginationMessage != null)
                          Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: Text(
                              viewState.paginationMessage!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.warningOrange,
                              ),
                            ),
                          ),
                        if (!viewState.hasMore)
                          Text(
                            'You have reached the end of the list.',
                            style: AppTextStyles.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: EdgeInsets.all(16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        mainAxisExtent: 246.h,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonLoader(height: 132, radius: 12),
          Gap(AppDimensions.spacing12),
          SkeletonLoader(height: 14, radius: 8),
          Gap(AppDimensions.spacing8),
          SkeletonLoader(height: 12, width: 80, radius: 8),
        ],
      ),
    );
  }
}
