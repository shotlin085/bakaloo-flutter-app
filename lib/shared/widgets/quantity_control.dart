import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class QuantityControl extends StatefulWidget {
  const QuantityControl({
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    this.width = 88,
    this.height = 36,
    super.key,
  });

  final int quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final double width;
  final double height;

  @override
  State<QuantityControl> createState() => _QuantityControlState();
}

class _QuantityControlState extends State<QuantityControl> {
  double _countScale = 1;

  @override
  void didUpdateWidget(covariant QuantityControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity && widget.quantity > 0) {
      setState(() {
        _countScale = 1.2;
      });
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _countScale = 1;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAddState = widget.quantity <= 0;

    return SizedBox(
      width: widget.width.w,
      height: widget.height.h,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: isAddState
            ? _AddButton(
                key: const ValueKey<String>('add-state'),
                onTap: widget.onAdd,
              )
            : _QtySelector(
                key: ValueKey<int>(widget.quantity),
                quantity: widget.quantity,
                countScale: _countScale,
                onIncrement: widget.onIncrement,
                onDecrement: widget.onDecrement,
              ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.onTap,
    super.key,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primaryGreen),
        backgroundColor: AppColors.bgCard,
        foregroundColor: AppColors.primaryGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        padding: EdgeInsets.zero,
      ),
      child: Text(
        'ADD',
        style: AppTextStyles.buttonSmall.copyWith(
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }
}

class _QtySelector extends StatelessWidget {
  const _QtySelector({
    required this.quantity,
    required this.countScale,
    required this.onIncrement,
    required this.onDecrement,
    super.key,
  });

  final int quantity;
  final double countScale;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          _IconTapButton(
            icon: PhosphorIcons.minus(),
            onTap: onDecrement,
          ),
          Expanded(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              scale: countScale,
              child: Center(
                child: Text(
                  '$quantity',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.textOnGreen,
                  ),
                ),
              ),
            ),
          ),
          _IconTapButton(
            icon: PhosphorIcons.plus(),
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _IconTapButton extends StatelessWidget {
  const _IconTapButton({
    required this.icon,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: SizedBox(
        width: 26.w,
        child: Center(
          child: PhosphorIcon(
            icon,
            size: 15,
            color: AppColors.textOnGreen,
          ),
        ),
      ),
    );
  }
}
