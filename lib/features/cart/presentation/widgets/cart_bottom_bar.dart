import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CartBottomBar extends StatelessWidget {
  const CartBottomBar({
    required this.hasAddress,
    required this.toPay,
    super.key,
    this.onAddAddress,
    this.onPayOnline,
    this.onCashOrWallet,
    this.isPlacingOrder = false,
    this.onlineEnabled = true,
    this.codEnabled = true,
    this.walletEnabled = true,
    this.paymentMethodsKnown = true,
  });

  final bool hasAddress;
  final double toPay;
  final VoidCallback? onAddAddress;
  final VoidCallback? onPayOnline;
  final VoidCallback? onCashOrWallet;
  final bool isPlacingOrder;

  /// False only while there has never yet been a successful payment-methods
  /// answer for this cart (first load, or a hard failure with nothing
  /// cached). The three `*Enabled` flags default to `true` so a caller that
  /// genuinely doesn't track this keeps the old always-enabled behavior —
  /// but while this is false, those flags must be treated as an unverified
  /// guess and the bar shows a loading placeholder instead of buttons a
  /// customer could act on.
  final bool paymentMethodsKnown;

  /// Admin toggles (Settings → Payments on the dashboard) — each button
  /// reflects these directly: disabled (visible, greyed, not tappable)
  /// when its method is off, and the Cash/Wallet button's own label
  /// narrows to whichever single method is actually on. When all three are
  /// off, the whole row is replaced by an "unavailable" message instead of
  /// three dead buttons.
  final bool onlineEnabled;
  final bool codEnabled;
  final bool walletEnabled;

  bool get _cashOrWalletEnabled => codEnabled || walletEnabled;

  String get _cashOrWalletLabel {
    if (codEnabled && walletEnabled) return 'Cash / Wallet';
    if (codEnabled) return 'Cash on Delivery';
    if (walletEnabled) return 'Bakaloo Wallet';
    return 'Cash / Wallet';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFF0F0F0)),
          ),
          boxShadow: hasAddress
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, -6),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        child: hasAddress ? _buildPaymentState() : _buildAddressState(),
      ),
    );
  }

  Widget _buildAddressState() {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: onAddAddress,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE23372),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: Text(
          'Add Address to Proceed',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentState() {
    if (!paymentMethodsKnown) {
      return _buildPaymentButtonsLoadingState();
    }
    if (!onlineEnabled && !_cashOrWalletEnabled) {
      return _buildUnavailableState();
    }

    return Row(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(right: 10.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'To Pay',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF666666),
                  fontFamily: 'Inter',
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '₹${toPay.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF222222),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 52.h,
            child: OutlinedButton.icon(
              onPressed: (onlineEnabled && !isPlacingOrder) ? onPayOnline : null,
              icon: Icon(Icons.credit_card_rounded, size: 18.sp),
              label: Text(
                'Pay Online',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                disabledForegroundColor:
                    const Color(0xFF7C3AED).withValues(alpha: 0.4),
                side: BorderSide(
                  color: const Color(0xFF7C3AED)
                      .withValues(alpha: onlineEnabled ? 1 : 0.35),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: SizedBox(
            height: 52.h,
            child: ElevatedButton(
              onPressed: (_cashOrWalletEnabled && !isPlacingOrder)
                  ? onCashOrWallet
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                disabledBackgroundColor:
                    const Color(0xFF7C3AED).withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                padding: EdgeInsets.zero,
              ),
              child: isPlacingOrder
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _cashOrWalletLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shown only until the real summary — payment methods AND price — is
  /// known for the first time. Both the price and the buttons shimmer
  /// together rather than showing a guessed ₹ figure next to a guessed
  /// button state: the two were never independent (both come from the same
  /// backend summary), so a customer must never see one update ahead of
  /// the other. Same 52.h row the real buttons occupy, so there's no
  /// layout jump when they swap in.
  Widget _buildPaymentButtonsLoadingState() {
    Widget block({double? width}) {
      return Container(
        width: width,
        height: 52.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(14.r),
        ),
      );
    }

    return Row(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(right: 10.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'To Pay',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF666666),
                  fontFamily: 'Inter',
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                width: 64.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: block()),
        SizedBox(width: 10.w),
        Expanded(child: block()),
      ],
    );
  }

  Widget _buildUnavailableState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FB),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE3DCF2)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            color: const Color(0xFF7C3AED),
            size: 20.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Payment methods are currently unavailable. Please check back shortly.',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3A2E52),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
