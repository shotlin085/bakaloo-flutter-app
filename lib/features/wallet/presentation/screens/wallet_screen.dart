import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';

import 'package:bakaloo_flutter_app/core/security/screenshot_prevention.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/transaction_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  static const int _pageSize = 20;

  final LocalAuthentication _localAuth = LocalAuthentication();
  late final PagingController<int, TransactionEntity> _pagingController;

  WalletTransactionFilter _filter = WalletTransactionFilter.all;
  bool _balanceUnlocked = false;
  bool _isAuthenticating = true;

  @override
  void initState() {
    super.initState();
    unawaited(ScreenshotPrevention.enable());
    _pagingController = PagingController<int, TransactionEntity>(
      firstPageKey: 1,
    )..addPageRequestListener(_fetchPage);
    unawaited(_authenticateForBalance());
  }

  @override
  void dispose() {
    unawaited(ScreenshotPrevention.disable());
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await ref.read(walletProvider.notifier).getTransactionsPage(
          page: pageKey,
          limit: _pageSize,
          filter: _filter,
        );

    result.fold(
      (failure) {
        _pagingController.error = failure.message;
      },
      (data) {
        final isLastPage = data.pagination.totalPages <= pageKey ||
            data.transactions.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(data.transactions);
          return;
        }
        _pagingController.appendPage(data.transactions, pageKey + 1);
      },
    );
  }

  Future<void> _authenticateForBalance() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    bool unlocked = false;
    String? failureMessage;
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        unlocked = true;
      } else {
        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        final shouldRequireBiometric =
            canCheckBiometrics && availableBiometrics.isNotEmpty;

        unlocked = await _localAuth.authenticate(
          localizedReason: 'Authenticate to view your wallet balance',
          options: AuthenticationOptions(
            biometricOnly: shouldRequireBiometric,
            stickyAuth: true,
            sensitiveTransaction: true,
          ),
        );
      }
    } on PlatformException catch (error) {
      failureMessage = _friendlyAuthMessage(error.code);
      unlocked = false;
    } catch (_) {
      failureMessage = 'Authentication failed. Please try again.';
      unlocked = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _balanceUnlocked = unlocked;
      _isAuthenticating = false;
    });

    if (!unlocked && failureMessage != null) {
      _showSnack(failureMessage);
    }
  }

  Future<bool> _authenticateForTransfer() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return true;
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to transfer money',
        options: AuthenticationOptions(
          biometricOnly: canCheckBiometrics && availableBiometrics.isNotEmpty,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException catch (error) {
      _showSnack(_friendlyAuthMessage(error.code));
      return false;
    } catch (_) {
      _showSnack('Authentication failed. Please try again.');
      return false;
    }
  }

  Future<void> _openTopup() async {
    final completed = await context.push<bool>(RouteNames.topup);
    if (!mounted || completed != true) {
      return;
    }

    await ref.read(walletProvider.notifier).refreshWallet();
    _pagingController.refresh();
  }

  Future<void> _openTransferSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TransferSheet(
        onSubmit: (
          String phone,
          double amount,
          String? description,
        ) async {
          final didAuthenticate = await _authenticateForTransfer();
          if (!didAuthenticate) {
            return 'Biometric authentication required.';
          }

          final transferResult =
              await ref.read(walletProvider.notifier).transfer(
                    WalletTransferParams(
                      phone: phone,
                      amount: amount,
                      description: description,
                    ),
                  );

          if (!transferResult.isSuccess) {
            return transferResult.failure!.message;
          }

          _pagingController.refresh();
          return null;
        },
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final isSuccess = result.isEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSuccess ? 'Money transferred successfully.' : result,
        ),
        backgroundColor:
            isSuccess ? AppColors.successGreen : AppColors.outOfStockRed,
      ),
    );
  }

  Future<void> _refreshAll() async {
    await ref.read(walletProvider.notifier).refreshWallet();
    _pagingController.refresh();
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyAuthMessage(String code) {
    return switch (code) {
      'NotAvailable' => 'Biometric authentication is not available.',
      'NotEnrolled' => 'No biometric is enrolled on this device.',
      'LockedOut' => 'Too many attempts. Try again later.',
      'PermanentlyLockedOut' =>
        'Biometric is locked. Unlock with device PIN/password.',
      'auth_in_progress' => 'Authentication is already in progress.',
      'passcodeNotSet' => 'Set a device lock to use secure authentication.',
      _ => 'Authentication failed. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final wallet = walletAsync.asData?.value;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Bakaloo Wallet', style: AppTextStyles.h2),
      ),
      body: walletAsync.when(
        loading: () => wallet == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryGreen,
                ),
              )
            : _buildContent(wallet),
        error: (error, _) => wallet == null
            ? _WalletErrorState(
                message: error.toString().replaceFirst('Bad state: ', ''),
                onRetry: () => ref.invalidate(walletProvider),
              )
            : _buildContent(wallet),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(WalletEntity wallet) {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: Column(
            children: <Widget>[
              _BalanceCard(
                balance: wallet.balance,
                unlocked: _balanceUnlocked,
                isAuthenticating: _isAuthenticating,
                onUnlock: _authenticateForBalance,
                onAddMoney: _openTopup,
                onTransfer: _openTransferSheet,
              ),
              Gap(14.h),
              _QuickActionRow(
                onAddMoney: _openTopup,
                onTransfer: _openTransferSheet,
                onHistory: _pagingController.refresh,
              ),
              Gap(14.h),
              _TransactionFilterChips(
                selected: _filter,
                onChanged: (value) {
                  if (_filter == value) {
                    return;
                  }
                  setState(() {
                    _filter = value;
                  });
                  _pagingController.refresh();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: _refreshAll,
            child: PagedListView<int, TransactionEntity>(
              pagingController: _pagingController,
              padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 24.h),
              physics: const AlwaysScrollableScrollPhysics(),
              builderDelegate: PagedChildBuilderDelegate<TransactionEntity>(
                itemBuilder: (context, transaction, index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _TransactionTile(transaction: transaction),
                  );
                },
                firstPageProgressIndicatorBuilder: (_) => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
                newPageProgressIndicatorBuilder: (_) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                firstPageErrorIndicatorBuilder: (_) => _WalletErrorState(
                  message: _pagingController.error?.toString() ??
                      'Unable to load transactions.',
                  onRetry: _pagingController.refresh,
                ),
                noItemsFoundIndicatorBuilder: (_) => _EmptyTransactionsState(
                  filter: _filter,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.unlocked,
    required this.isAuthenticating,
    required this.onUnlock,
    required this.onAddMoney,
    required this.onTransfer,
  });

  final double balance;
  final bool unlocked;
  final bool isAuthenticating;
  final Future<void> Function() onUnlock;
  final VoidCallback onAddMoney;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    Widget amountText = Text(
      balance.toInrCurrency,
      style: AppTextStyles.display.copyWith(
        color: Colors.white,
        fontSize: 32.sp,
      ),
    );

    if (!unlocked) {
      amountText = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: amountText,
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: AppColors.walletCardGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: const <BoxShadow>[AppShadows.floatingShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Wallet balance',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          Gap(8.h),
          amountText,
          Gap(16.h),
          Row(
            children: <Widget>[
              _WalletPill(
                icon: PhosphorIcons.plus(),
                label: 'Add Money',
                onTap: onAddMoney,
              ),
              Gap(10.w),
              _WalletPill(
                icon: PhosphorIcons.arrowsClockwise(),
                label: 'Transfer',
                onTap: onTransfer,
              ),
              const Spacer(),
              IconButton(
                onPressed: isAuthenticating ? null : onUnlock,
                icon: isAuthenticating
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : PhosphorIcon(
                        unlocked
                            ? PhosphorIcons.lockOpen()
                            : PhosphorIcons.fingerprint(),
                        color: Colors.white,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(icon, color: Colors.white, size: 14.sp),
            Gap(6.w),
            Text(
              label,
              style: AppTextStyles.buttonSmall.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onAddMoney,
    required this.onTransfer,
    required this.onHistory,
  });

  final VoidCallback onAddMoney;
  final VoidCallback onTransfer;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        _QuickActionCircle(
          icon: PhosphorIcons.plusCircle(),
          label: 'Add',
          onTap: onAddMoney,
        ),
        _QuickActionCircle(
          icon: PhosphorIcons.arrowsLeftRight(),
          label: 'Transfer',
          onTap: onTransfer,
        ),
        _QuickActionCircle(
          icon: PhosphorIcons.clockCounterClockwise(),
          label: 'History',
          onTap: onHistory,
        ),
      ],
    );
  }
}

class _QuickActionCircle extends StatelessWidget {
  const _QuickActionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Column(
        children: <Widget>[
          Container(
            width: 56.w,
            height: 56.w,
            decoration: const BoxDecoration(
              color: AppColors.primaryGreenLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                icon,
                color: AppColors.primaryGreen,
                size: 22.sp,
              ),
            ),
          ),
          Gap(6.h),
          Text(label, style: AppTextStyles.labelLarge),
        ],
      ),
    );
  }
}

class _TransactionFilterChips extends StatelessWidget {
  const _TransactionFilterChips({
    required this.selected,
    required this.onChanged,
  });

  final WalletTransactionFilter selected;
  final ValueChanged<WalletTransactionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: WalletTransactionFilter.values.map((filter) {
        final isSelected = selected == filter;
        return Padding(
          padding: EdgeInsets.only(right: 8.w),
          child: ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onChanged(filter),
            label: Text(
              filter.label,
              style: AppTextStyles.labelLarge.copyWith(
                color:
                    isSelected ? AppColors.primaryGreen : AppColors.textPrimary,
              ),
            ),
            selectedColor: AppColors.primaryGreenLight,
            backgroundColor: AppColors.bgCard,
            side: BorderSide(
              color:
                  isSelected ? AppColors.primaryGreen : AppColors.borderLight,
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
  });

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == WalletTransactionType.CREDIT;
    final color = isCredit ? AppColors.successGreen : AppColors.outOfStockRed;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                isCredit ? PhosphorIcons.arrowDown() : PhosphorIcons.arrowUp(),
                color: color,
                size: 18.sp,
              ),
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  transaction.description,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap(2.h),
                Text(
                  transaction.createdAt.toIndianDateTime,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${transaction.amount.toInrCurrency}',
            style: AppTextStyles.h3.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({
    required this.onSubmit,
  });

  final Future<String?> Function(
    String phone,
    double amount,
    String? description,
  ) onSubmit;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    setState(() {
      _submitting = true;
    });

    final error = await widget.onSubmit(
      _phoneController.text.trim(),
      amount,
      description,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (error == null) {
      Navigator.of(context).pop('');
      return;
    }

    Navigator.of(context).pop(error);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.w,
        8.h,
        16.w,
        MediaQuery.of(context).viewInsets.bottom + 16.h,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Transfer money', style: AppTextStyles.h2),
            Gap(10.h),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Recipient phone',
                prefixText: '+91 ',
                counterText: '',
              ),
              validator: (value) {
                final normalized = value?.trim() ?? '';
                if (normalized.length != 10) {
                  return 'Enter a valid 10-digit number';
                }
                return null;
              },
            ),
            Gap(8.h),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            Gap(8.h),
            TextFormField(
              controller: _descriptionController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            Gap(8.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  minimumSize: Size.fromHeight(48.h),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Transfer',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: Colors.white,
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

class _WalletErrorState extends StatelessWidget {
  const _WalletErrorState({
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
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            Gap(10.h),
            FilledButton(
              onPressed: onRetry,
              child: Text('Retry', style: AppTextStyles.buttonMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState({
    required this.filter,
  });

  final WalletTransactionFilter filter;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      WalletTransactionFilter.all => 'transactions',
      WalletTransactionFilter.credit => 'credit transactions',
      WalletTransactionFilter.debit => 'debit transactions',
    };

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Text(
          'No $label found yet.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
