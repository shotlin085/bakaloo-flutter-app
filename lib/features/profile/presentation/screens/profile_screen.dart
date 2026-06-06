import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/screens/coupons_screen.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/entities/user_stats_entity.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/appearance_toggle.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/birthday_banner.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/logout_sheet.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/menu_section.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/menu_tile.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/stats_row.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final InAppReview _inAppReview = InAppReview.instance;

  bool _hideSensitiveItems = false;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    final hiddenValue = HiveService.settingsBox.get(
      StorageKeys.hideSensitiveItems,
    );
    _hideSensitiveItems = hiddenValue is bool ? hiddenValue : false;
    unawaited(_loadAppVersion());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(profileProvider.notifier).fetchProfile());
      ref.invalidate(userStatsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileProvider, (previous, next) {
      if (!mounted || !next.hasError || next.isLoading) {
        return;
      }
      final previousError = previous?.error;
      if (previousError != next.error) {
        final message = next.error.toString().replaceFirst('Bad state: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });

    final profileAsync = ref.watch(profileProvider);
    final currentUser = ref.watch(currentUserProvider);
    // FIX: Use walletProvider (WalletNotifier, keepAlive) instead of
    // walletBalanceProvider (auto-dispose) so the balance persists across
    // rebuilds and always shows the correct fetched value.
    final walletAsync = ref.watch(walletProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final profileData = profileAsync.asData?.value;
    final user = profileData?.user ?? currentUser;
    final birthday = profileData?.birthday;

    if (user == null && profileAsync.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.orderViolet),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Unable to load your profile.',
                style: AppTextStyles.bodyMedium,
              ),
              Gap(10.h),
              FilledButton(
                onPressed: () {
                  unawaited(ref.read(profileProvider.notifier).fetchProfile());
                },
                child: Text('Retry', style: AppTextStyles.buttonMedium),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 30.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ProfileHeader(
              name: user.name,
              phone: user.phone,
              avatarUrl: user.avatarUrl,
              onAccountTap: _openEditProfile,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  BirthdayBanner(
                    birthday: birthday,
                    onSelectBirthday: _updateBirthday,
                  ),
                  Gap(16.h),
                  _buildStats(statsAsync),
                  Gap(16.h),
                  MenuSection(
                    title: 'MY ACTIVITY',
                    children: <Widget>[
                      MenuTile(
                        icon: PhosphorIcons.package(),
                        label: 'Orders',
                        onTap: () => context.push(RouteNames.orders),
                      ),
                      _divider(),
                      MenuTile(
                        icon: PhosphorIcons.mapPin(),
                        label: 'Addresses',
                        onTap: () =>
                            context.push('${RouteNames.profile}/addresses'),
                      ),
                      _divider(),
                      MenuTile(
                        icon: PhosphorIcons.heart(),
                        label: 'Wishlist',
                        onTap: () => context.push(RouteNames.wishlist),
                      ),
                    ],
                  ),
                  Gap(14.h),
                  MenuSection(
                    title: 'PAYMENTS',
                    children: <Widget>[
                      MenuTile(
                        icon: PhosphorIcons.wallet(),
                        label: 'Wallet',
                        trailing: _WalletPill(label: _walletLabel(walletAsync)),
                        onTap: () =>
                            context.push('${RouteNames.profile}/wallet'),
                      ),
                      _divider(),
                      MenuTile(
                        icon: PhosphorIcons.ticket(),
                        label: 'Coupons',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CouponsScreen(),
                            ),
                          );
                        },
                      ),
                      _divider(),
                      MenuTile(
                        icon: PhosphorIcons.creditCard(),
                        label: 'Payment settings',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                    ],
                  ),
                  Gap(14.h),
                  MenuSection(
                    title: 'ACCOUNT SETTINGS',
                    children: <Widget>[
                      MenuTile(
                        icon: PhosphorIcons.bellRinging(),
                        label: 'Notification preferences',
                        onTap: () => context.push(
                          '${RouteNames.profile}/notifications/preferences',
                        ),
                      ),
                      _divider(),
                      MenuTile(
                        icon: PhosphorIcons.shieldCheck(),
                        label: 'Privacy',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                    ],
                  ),
                  Gap(10.h),
                  const AppearanceToggle(),
                  Gap(10.h),
                  _buildHideSensitiveCard(),
                  Gap(14.h),
                  MenuSection(
                    title: 'HELP & ABOUT',
                    children: <Widget>[
                      MenuTile(
                        icon: PhosphorIcons.question(),
                        label: 'Support',
                        onTap: _showSupportSheet,
                      ),
                      _divider(),
                      MenuTile(
                        icon: PhosphorIcons.shareFat(),
                        label: 'Share the app',
                        onTap: () {
                          Share.share(
                            'Order groceries on Bakaloo: https://bakaloo.app',
                          );
                        },
                      ),
                      _divider(),
                      MenuTile(
                        icon: PhosphorIcons.star(),
                        label: 'Rate us',
                        onTap: _rateApp,
                      ),
                      _divider(),
                      MenuTile(
                        icon: PhosphorIcons.info(),
                        label: 'About us',
                        onTap: _showAbout,
                      ),
                    ],
                  ),
                  Gap(14.h),
                  MenuSection(
                    title: 'DANGER ZONE',
                    children: <Widget>[
                      MenuTile(
                        icon: PhosphorIcons.signOut(),
                        label: 'Log out',
                        isDanger: true,
                        onTap: () => LogoutSheet.show(context),
                      ),
                      _divider(),
                      MenuTile(
                        icon: PhosphorIcons.trash(),
                        label: 'Delete account',
                        isDanger: true,
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                  Gap(10.h),
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(AsyncValue<UserStatsEntity> statsAsync) {
    return statsAsync.when(
      loading: () => Container(
        height: 82.h,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.orderViolet),
      ),
      error: (_, __) => Container(
        height: 82.h,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        alignment: Alignment.center,
        child: Text(
          'Stats unavailable right now',
          style: AppTextStyles.bodySmall,
        ),
      ),
      data: (stats) => StatsRow(stats: stats),
    );
  }

  Widget _buildHideSensitiveCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg.r),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: SwitchListTile.adaptive(
        value: _hideSensitiveItems,
        activeThumbColor: AppColors.orderViolet,
        activeTrackColor: AppColors.orderVioletSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
        title: Text(
          'Hide sensitive items',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Scouts, wellness, vending products and other sensitive items will be hidden',
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 11.sp,
            color: AppColors.textSecondary,
          ),
        ),
        onChanged: (value) async {
          setState(() => _hideSensitiveItems = value);
          await HiveService.settingsBox.put(
            StorageKeys.hideSensitiveItems,
            value,
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.only(bottom: 32.h, top: 4.h),
      child: Center(
        child: Text(
          'bakaloo v$_appVersion',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1.h,
      thickness: 1.h,
      color: AppColors.divider,
    );
  }

  Future<void> _updateBirthday(DateTime date) async {
    final result = await ref.read(profileProvider.notifier).updateProfile(
          birthday: date,
        );
    if (!mounted || result.isSuccess) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.failure!.message)),
    );
  }

  Future<void> _openEditProfile() async {
    final changed = await context.push<bool>('${RouteNames.profile}/edit');
    if (!mounted || changed != true) {
      return;
    }
    await ref.read(profileProvider.notifier).fetchProfile();
    ref.invalidate(userStatsProvider);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await DeleteAccountDialog.show(context);
    if (!mounted || confirmed != true) {
      return;
    }

    final authenticated = await _authenticateForDelete();
    if (!mounted || !authenticated) {
      return;
    }

    final result = await ref.read(profileProvider.notifier).deleteAccount();
    if (!mounted) {
      return;
    }

    if (!result.isSuccess && result.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
      return;
    }
    context.go(RouteNames.phone);
  }

  Future<bool> _authenticateForDelete() async {
    try {
      final canUseBiometric = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      if (!canUseBiometric || !deviceSupported) {
        return true;
      }
      return await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to delete account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _showSupportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20.r),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Need help?', style: AppTextStyles.h2),
              Gap(10.h),
              Text(
                'Reach us at support@bakaloo.app or call +91 90000 00000.',
                style: AppTextStyles.bodyMedium,
              ),
              Gap(14.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Done',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: AppColors.textOnGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Bakaloo',
      applicationVersion: _appVersion,
      applicationLegalese: '© ${DateTime.now().year} Bakaloo',
    );
  }

  Future<void> _rateApp() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        return;
      }
    } catch (_) {
      // Fall through and show feedback.
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating is not available right now.')),
    );
  }

  // FIX: Now receives AsyncValue<WalletEntity> from walletProvider instead of
  // AsyncValue<double> from the auto-dispose walletBalanceProvider.
  String _walletLabel(AsyncValue<dynamic> walletAsync) {
    return walletAsync.when(
      data: (wallet) {
        // walletProvider returns WalletEntity with .balance field.
        if (wallet is WalletEntity) {
          return wallet.balance.toInrCurrency;
        }
        // Fallback: if somehow a double slips through.
        if (wallet is double) {
          return wallet.toInrCurrency;
        }
        return '...';
      },
      error: (_, __) => '--',
      loading: () => '...',
    );
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() => _appVersion = info.version);
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.orderVioletSurface,
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.orderViolet,
          fontWeight: FontWeight.w700,
          fontSize: 12.5.sp,
        ),
      ),
    );
  }
}
