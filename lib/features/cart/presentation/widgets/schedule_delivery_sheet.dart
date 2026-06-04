import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/delivery_slot_provider.dart';

// ─── Brand colours ────────────────────────────────────────────────────────────
const _kPurple = Color(0xFF7C3AED);
const _kPurpleLight = Color(0xFFF5F3FF);
const _kPurpleBorder = Color(0xFFDDD6FE);
const _kGreen = Color(0xFF0AC26B);
const _kBlack = Color(0xFF111827);
const _kGrey = Color(0xFF6B7280);
const _kGreyLight = Color(0xFFF3F4F6);
const _kWhite = Colors.white;

/// Bottom sheet for choosing ASAP or scheduled delivery.
///
/// Shows a mode selector (ASAP | Schedule), a horizontal date pill row,
/// and a time-slot grid. Tapping "Confirm schedule" calls
/// [CheckoutNotifier.selectDeliverySlot] and closes the sheet.
class ScheduleDeliverySheet extends ConsumerStatefulWidget {
  const ScheduleDeliverySheet({super.key});

  @override
  ConsumerState<ScheduleDeliverySheet> createState() =>
      _ScheduleDeliverySheetState();
}

class _ScheduleDeliverySheetState
    extends ConsumerState<ScheduleDeliverySheet> {
  bool _isScheduled = false;
  int _selectedDayIndex = 0;
  DeliverySlotEntity? _selectedSlot;

  @override
  void initState() {
    super.initState();
    // Restore existing selection if user re-opens the sheet
    final existing = ref.read(checkoutProvider).selectedDeliverySlot;
    if (existing != null && existing.isScheduled) {
      _isScheduled = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(deliverySlotsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──────────────────────────────────────
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 10.h, bottom: 4.h),
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(99.r),
                  ),
                ),
              ),

              // ── Header ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 16.w, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule delivery',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: _kBlack,
                              fontFamily: 'Inter',
                            ),
                          ),
                          Gap(2.h),
                          Text(
                            'Choose when you want your groceries delivered',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: _kGrey,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: _kGrey,
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),

              Gap(12.h),

              // ── Mode cards ───────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    _ModeCard(
                      icon: Icons.bolt_rounded,
                      title: 'ASAP',
                      subtitle: 'Deliver in 6 mins',
                      selected: !_isScheduled,
                      onTap: () => setState(() {
                        _isScheduled = false;
                        _selectedSlot = null;
                      }),
                    ),
                    Gap(10.w),
                    _ModeCard(
                      icon: Icons.calendar_month_outlined,
                      title: 'Schedule',
                      subtitle: 'Choose a time slot',
                      selected: _isScheduled,
                      onTap: () => setState(() => _isScheduled = true),
                    ),
                  ],
                ),
              ),

              Gap(16.h),

              // ── Slot picker (only when SCHEDULED) ────────────────
              Expanded(
                child: _isScheduled
                    ? slotsAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: _kPurple,
                            strokeWidth: 2,
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: _kGrey,
                                size: 36.sp,
                              ),
                              Gap(8.h),
                              Text(
                                'Could not load slots',
                                style: TextStyle(
                                  color: _kGrey,
                                  fontSize: 14.sp,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              Gap(12.h),
                              TextButton(
                                onPressed: () =>
                                    ref.invalidate(deliverySlotsProvider),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                        data: (days) {
                          if (days.isEmpty) {
                            return Center(
                              child: Text(
                                'No slots available',
                                style: TextStyle(
                                  color: _kGrey,
                                  fontSize: 14.sp,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            );
                          }
                          return _SlotPickerContent(
                            days: days,
                            selectedDayIndex: _selectedDayIndex,
                            selectedSlot: _selectedSlot,
                            scrollController: scrollController,
                            onDaySelected: (i) =>
                                setState(() => _selectedDayIndex = i),
                            onSlotSelected: (slot) =>
                                setState(() => _selectedSlot = slot),
                          );
                        },
                      )
                    : _AsapContent(),
              ),

              // ── Bottom CTA ────────────────────────────────────────
              SafeArea(
                top: false,
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                  child: _ConfirmButton(
                    isScheduled: _isScheduled,
                    selectedSlot: _selectedSlot,
                    selectedDayLabel: (_isScheduled &&
                            ref
                                    .read(deliverySlotsProvider)
                                    .asData
                                    ?.value !=
                                null)
                        ? (ref
                                    .read(deliverySlotsProvider)
                                    .asData
                                    ?.value
                                    .length ??
                                0) >
                                _selectedDayIndex
                            ? ref
                                .read(deliverySlotsProvider)
                                .asData!
                                .value[_selectedDayIndex]
                                .label
                            : ''
                        : '',
                    onConfirm: (slot) {
                      final checkoutNotifier =
                          ref.read(checkoutProvider.notifier);
                      if (!_isScheduled) {
                        checkoutNotifier.selectDeliverySlot(
                            const SelectedDeliverySlot.asap());
                      } else if (slot != null) {
                        final days = ref
                            .read(deliverySlotsProvider)
                            .asData
                            ?.value;
                        final dayLabel = (days != null &&
                                days.length > _selectedDayIndex)
                            ? days[_selectedDayIndex].label
                            : '';
                        checkoutNotifier.selectDeliverySlot(
                          SelectedDeliverySlot.scheduled(
                            slot: slot,
                            dayLabel: dayLabel,
                          ),
                        );
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Mode card ────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: selected ? _kPurpleLight : _kGreyLight,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected ? _kPurple : const Color(0xFFE5E7EB),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? _kPurple : _kGrey,
                size: 20.sp,
              ),
              Gap(8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: selected ? _kPurple : _kBlack,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: selected ? _kPurple : _kGrey,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: _kPurple,
                  size: 16.sp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ASAP content placeholder ─────────────────────────────────────────────────

class _AsapContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining_rounded, color: _kGreen, size: 56.sp),
          Gap(16.h),
          Text(
            'Express delivery',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: _kBlack,
              fontFamily: 'Inter',
            ),
          ),
          Gap(6.h),
          Text(
            'Your order will be delivered in approximately 6 minutes after payment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: _kGrey,
              fontFamily: 'Inter',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slot picker content ──────────────────────────────────────────────────────

class _SlotPickerContent extends StatelessWidget {
  const _SlotPickerContent({
    required this.days,
    required this.selectedDayIndex,
    required this.selectedSlot,
    required this.scrollController,
    required this.onDaySelected,
    required this.onSlotSelected,
  });

  final List<DeliverySlotDayEntity> days;
  final int selectedDayIndex;
  final DeliverySlotEntity? selectedSlot;
  final ScrollController scrollController;
  final ValueChanged<int> onDaySelected;
  final ValueChanged<DeliverySlotEntity> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final currentDay = days[selectedDayIndex];
    final hasAvailable = currentDay.slots.any((s) => s.available);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // ── Day pills ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 8.h),
            child: SizedBox(
              height: 36.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (_, i) {
                  final selected = i == selectedDayIndex;
                  return GestureDetector(
                    onTap: () => onDaySelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: selected ? _kPurple : _kGreyLight,
                        borderRadius: BorderRadius.circular(99.r),
                        border: Border.all(
                          color:
                              selected ? _kPurple : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        days[i].label,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: selected ? _kWhite : _kBlack,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // ── Slot grid / empty state ───────────────────────────────
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          sliver: !hasAvailable
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.h),
                    child: Column(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          color: _kGrey,
                          size: 40.sp,
                        ),
                        Gap(10.h),
                        Text(
                          'No slots available ${currentDay.label.toLowerCase()}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: _kGrey,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Gap(4.h),
                        Text(
                          'Try selecting another day',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFF9CA3AF),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverList.separated(
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemCount: currentDay.slots.length,
                  itemBuilder: (_, i) {
                    final slot = currentDay.slots[i];
                    final isSelected = selectedSlot?.id == slot.id;
                    final disabled = !slot.available;

                    return GestureDetector(
                      onTap: disabled ? null : () => onSlotSelected(slot),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 14.h),
                        decoration: BoxDecoration(
                          color: disabled
                              ? const Color(0xFFF9FAFB)
                              : isSelected
                                  ? _kPurpleLight
                                  : _kWhite,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: disabled
                                ? const Color(0xFFE5E7EB)
                                : isSelected
                                    ? _kPurple
                                    : _kPurpleBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 18.sp,
                              color: disabled
                                  ? const Color(0xFFD1D5DB)
                                  : isSelected
                                      ? _kPurple
                                      : _kGrey,
                            ),
                            Gap(10.w),
                            Expanded(
                              child: Text(
                                slot.label,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: disabled
                                      ? const Color(0xFFD1D5DB)
                                      : isSelected
                                          ? _kPurple
                                          : _kBlack,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                            if (disabled)
                              Text(
                                slot.reason ?? 'Unavailable',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFFD1D5DB),
                                  fontFamily: 'Inter',
                                ),
                              )
                            else if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: _kPurple,
                                size: 18.sp,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        SliverToBoxAdapter(child: Gap(12.h)),
      ],
    );
  }
}

// ─── Confirm button ───────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.isScheduled,
    required this.selectedSlot,
    required this.selectedDayLabel,
    required this.onConfirm,
  });

  final bool isScheduled;
  final DeliverySlotEntity? selectedSlot;
  final String selectedDayLabel;
  final ValueChanged<DeliverySlotEntity?> onConfirm;

  @override
  Widget build(BuildContext context) {
    final canConfirm = !isScheduled || selectedSlot != null;
    final label = isScheduled && selectedSlot != null
        ? 'Deliver $selectedDayLabel, ${selectedSlot!.label}'
        : isScheduled
            ? 'Select a time slot'
            : 'Deliver in 6 mins';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isScheduled && selectedSlot != null) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: _kPurpleLight,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: _kPurpleBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: _kPurple, size: 16.sp),
                Gap(6.w),
                Expanded(
                  child: Text(
                    'Selected: $selectedDayLabel, ${selectedSlot!.label}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: _kPurple,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Gap(10.h),
        ],
        SizedBox(
          height: 50.h,
          child: ElevatedButton(
            onPressed: canConfirm ? () => onConfirm(selectedSlot) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canConfirm ? _kPurple : const Color(0xFFE5E7EB),
              foregroundColor: canConfirm ? _kWhite : _kGrey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 0,
            ),
            child: Text(
              isScheduled && selectedSlot != null
                  ? 'Confirm schedule'
                  : label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
