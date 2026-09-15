import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/entities/business_account_entity.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/repositories/business_account_repository.dart';
import 'package:bakaloo_flutter_app/features/business_account/presentation/providers/business_account_provider.dart';
import 'package:bakaloo_flutter_app/features/business_account/presentation/providers/price_mode_provider.dart';

/// Apply for (or view the status of) a B2B/wholesale account, and — once
/// approved — switch wholesale pricing on/off. Reached from Profile ›
/// Account Settings › Business Account.
class BusinessAccountScreen extends ConsumerWidget {
  const BusinessAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(myBusinessAccountProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text('Business Account', style: AppTextStyles.h2)),
      body: accountAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orderViolet),
        ),
        error: (error, _) => _ErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: () => ref.invalidate(myBusinessAccountProvider),
        ),
        data: (account) => account == null
            ? const _ApplyForm()
            : _StatusView(account: account),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            Gap(12.h),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ApplyForm extends ConsumerStatefulWidget {
  const _ApplyForm();

  @override
  ConsumerState<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends ConsumerState<_ApplyForm> {
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();

  // Standard 15-char GSTIN format — matches the backend's own validation
  // pattern, so a malformed entry is caught before the network round trip.
  static final RegExp _gstinPattern = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );

  bool _submitting = false;

  @override
  void dispose() {
    _companyController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _companyController.text.trim().length >= 2 &&
      _gstinPattern.hasMatch(_gstController.text.trim().toUpperCase());

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);

    final result = await ref.read(businessAccountProvider.notifier).apply(
          BusinessAccountApplyParams(
            companyName: _companyController.text.trim(),
            gstNumber: _gstController.text.trim().toUpperCase(),
          ),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.orderVioletSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PhosphorIcon(PhosphorIcons.briefcase, size: 22.sp, color: AppColors.orderViolet),
              Gap(10.w),
              Expanded(
                child: Text(
                  'Apply for a business account to unlock wholesale pricing on eligible products.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.orderViolet),
                ),
              ),
            ],
          ),
        ),
        Gap(20.h),
        Text('Company name', style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700)),
        Gap(8.h),
        TextField(
          controller: _companyController,
          maxLength: 255,
          style: AppTextStyles.bodyMedium,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'e.g. Sharma Traders Pvt Ltd'),
        ),
        Gap(16.h),
        Text('GST number', style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700)),
        Gap(8.h),
        TextField(
          controller: _gstController,
          maxLength: 15,
          textCapitalization: TextCapitalization.characters,
          style: AppTextStyles.bodyMedium,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '22AAAAA0000A1Z5'),
        ),
        Gap(24.h),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_submitting || !_canSubmit) ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: Size.fromHeight(46.h)),
            child: _submitting
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Submit Application'),
          ),
        ),
      ],
    );
  }
}

class _StatusView extends ConsumerWidget {
  const _StatusView({required this.account});

  final BusinessAccountEntity account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (account.canReapply) {
      // A REJECTED application can be corrected and resubmitted — same form,
      // with the rejection reason shown above it for context.
      return ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
        children: <Widget>[
          _StatusCard(account: account),
          Gap(20.h),
          const _ApplyForm(),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: <Widget>[
        _StatusCard(account: account),
        if (account.isApproved) ...<Widget>[
          Gap(16.h),
          const _WholesaleToggleCard(),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.account});

  final BusinessAccountEntity account;

  @override
  Widget build(BuildContext context) {
    final (Color accent, Color surface, IconData icon, String title, String subtitle) =
        switch (account.status) {
      'PENDING' => (
          AppColors.orderViolet,
          AppColors.orderVioletSurface,
          PhosphorIcons.clockCountdown,
          'Application pending',
          "We've received your application — our team typically reviews it within 24-48 hours.",
        ),
      'APPROVED' => (
          AppColors.primaryGreen,
          AppColors.primaryGreenLight,
          PhosphorIcons.checkCircleFill,
          'Business account approved',
          'You can switch wholesale pricing on or off any time below.',
        ),
      'REJECTED' => (
          AppColors.errorRed,
          const Color(0xFFFEF2F2),
          PhosphorIcons.xCircleFill,
          'Application not approved',
          (account.rejectionReason ?? '').trim().isNotEmpty
              ? account.rejectionReason!.trim()
              : 'Our team reviewed this application and it was not approved.',
        ),
      _ => (
          AppColors.textSecondary,
          AppColors.bgSection,
          PhosphorIcons.prohibit,
          'Business account suspended',
          'Contact support if you think this is a mistake.',
        ),
    };

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PhosphorIcon(icon, size: 20.sp, color: accent),
              Gap(10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700, color: accent),
                    ),
                    Gap(4.h),
                    Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          Gap(10.h),
          Text(account.companyName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          Text(
            account.gstNumber,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _WholesaleToggleCard extends ConsumerStatefulWidget {
  const _WholesaleToggleCard();

  @override
  ConsumerState<_WholesaleToggleCard> createState() => _WholesaleToggleCardState();
}

class _WholesaleToggleCardState extends ConsumerState<_WholesaleToggleCard> {
  bool _toggling = false;

  Future<void> _onChanged(bool _) async {
    setState(() => _toggling = true);
    final result = await ref.read(priceModeProvider.notifier).toggle();
    if (!mounted) return;
    setState(() => _toggling = false);
    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched directly (not threaded in from the parent's _StatusView build
    // as a constructor field, which this widget used to do) so the switch
    // always reflects the CURRENT provider state, not whatever value was
    // current at the moment _StatusView last happened to rebuild. Every
    // other price-mode-aware widget in the app (product cards, search,
    // product detail) already watches this provider directly for the same
    // reason. Reported: tapping the switch showed the spinner, then
    // reverted to its old position — needed a second tap, and even then
    // only "took" after leaving and re-entering the screen.
    final enabled = ref.watch(isWholesalePricingActiveProvider);
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Wholesale pricing', style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                Gap(2.h),
                Text(
                  enabled
                      ? 'Prices across the app reflect your wholesale rates.'
                      : "You're currently browsing at regular (retail) prices.",
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _toggling
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: enabled,
                  activeThumbColor: AppColors.primaryGreen,
                  onChanged: _onChanged,
                ),
        ],
      ),
    );
  }
}
