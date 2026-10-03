part of 'time_slot_grid.dart';

class _TimeSlotGridState extends State<TimeSlotGrid> {
  int _shiftFilter = 0;
  final Set<String> _waitlistedSlotKeys = {};
  bool _waitlistBusy = false;

  String _slotKey(DateTime date, TimeOfDay slot) =>
      "${date.year}-${date.month}-${date.day}_${slot.hour}:${slot.minute}";

  void _updateWaitlist(VoidCallback change) {
    if (mounted) setState(change);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.bookedTimeSlots != current.bookedTimeSlots ||
          previous.slotPrices != current.slotPrices ||
          previous.startTime != current.startTime ||
          previous.durationMinutes != current.durationMinutes ||
          previous.selectedDate != current.selectedDate,
      builder: (context, state) {
        if (state.status == BookingStatus.loading &&
            state.bookedTimeSlots.isEmpty) {
          return SizedBox(height: 100.h, child: const AppLoader(size: 30));
        }

        // Generate future slots
        final slots = _generateFutureSlots(
          widget.lounge.openingTime,
          widget.lounge.closingTime,
          state,
        );

        if (slots.isEmpty) {
          return _buildFullyBookedOrPastBanner(context);
        }

        final hasMorning = slots.any((s) => s.hour >= 6 && s.hour < 16);
        final hasAfternoon = slots.any((s) => s.hour >= 16 && s.hour < 22);
        final hasNight = slots.any((s) => s.hour >= 22 || s.hour < 6);

        if (_shiftFilter == 1 && !hasMorning) _shiftFilter = 0;
        if (_shiftFilter == 2 && !hasAfternoon) _shiftFilter = 0;
        if (_shiftFilter == 3 && !hasNight) _shiftFilter = 0;

        final availableShiftCount =
            (hasMorning ? 1 : 0) + (hasAfternoon ? 1 : 0) + (hasNight ? 1 : 0);

        List<TimeOfDay> filteredSlots = slots;
        if (_shiftFilter == 1 && hasMorning) {
          filteredSlots = slots
              .where((s) => s.hour >= 6 && s.hour < 16)
              .toList();
        } else if (_shiftFilter == 2 && hasAfternoon) {
          filteredSlots = slots
              .where((s) => s.hour >= 16 && s.hour < 22)
              .toList();
        } else if (_shiftFilter == 3 && hasNight) {
          filteredSlots = slots
              .where((s) => s.hour >= 22 || s.hour < 6)
              .toList();
        }
        if (filteredSlots.isEmpty) filteredSlots = slots;

        final selectedStart = state.startTime;
        final maxFreeHours = selectedStart != null
            ? _calculateMaxContinuousFreeHours(selectedStart, slots, state)
            : 0.0;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppColors.neonBlue.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.05),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (availableShiftCount > 1) ...[
                Row(
                  children: [
                    _buildShiftFilterChip(0, AppStrings.all.tr()),
                    if (hasMorning) ...[
                      SizedBox(width: 6.w),
                      _buildShiftFilterChip(1, "☀️ ${'morning'.tr()}"),
                    ],
                    if (hasAfternoon) ...[
                      SizedBox(width: 6.w),
                      _buildShiftFilterChip(2, "🌆 ${'afternoon'.tr()}"),
                    ],
                    if (hasNight) ...[
                      SizedBox(width: 6.w),
                      _buildShiftFilterChip(3, "🌙 ${'evening'.tr()}"),
                    ],
                  ],
                ),
                SizedBox(height: 14.h),
              ],

              AppText(
                text: 'choose_slot_hint'.tr(),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 12),
              // Time Slot Ribbon with Price and Peak Tag
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(152),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredSlots.length,
                  separatorBuilder: (_, _) => SizedBox(width: 8.w),
                  itemBuilder: (context, index) {
                    final slot = filteredSlots[index];
                    final isBooked = _isSlotBooked(slot, state);
                    final slotPrice = state.getSlotPrice(slot);
                    final isPeak = slotPrice?.isPeak ?? false;
                    final rateVal = slotPrice?.hourlyRate;

                    final isSelectedStart =
                        state.startTime?.hour == slot.hour &&
                        state.startTime?.minute == slot.minute;
                    final isInSelectionSpan = _isPartOfCurrentSelection(
                      slot,
                      state,
                    );
                    final slotKey = _slotKey(state.selectedDate, slot);
                    final isWaitlisted = _waitlistedSlotKeys.contains(slotKey);

                    return TimeSlotTile(
                      key: ValueKey(slotKey),
                      timeLabel: _formatTime(slot),
                      booked: isBooked,
                      selected: isSelectedStart,
                      inRange: isInSelectionSpan,
                      peak: isPeak,
                      waitlisted: isWaitlisted,
                      hourlyRate: rateVal,
                      onTap: () {
                        if (isBooked) {
                          _requestWaitlist(context, slot);
                        } else {
                          context.read<BookingCubit>().selectStartTime(slot);
                        }
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 14.h),

              if (selectedStart != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.neonBlue.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              text:
                                  "${AppStrings.startTime.tr()}: ${_formatTime(selectedStart)}",
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                            SizedBox(height: 2.h),
                            AppText(
                              text:
                                  "${AppStrings.available.tr()} ${maxFreeHours.toStringAsFixed(1)} ${AppStrings.hour_plural.tr()}",
                              fontSize: 10.sp,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildShiftFilterChip(int index, String label) {
    final isSelected = _shiftFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _shiftFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 6.h),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.neonBlue.withValues(alpha: 0.2)
                : Colors.black26,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: AppText(
              text: label,
              fontSize: 10.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullyBookedOrPastBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: AppText(
              text: AppStrings.allSlotsBookedOrPast.tr(),
              fontSize: 12.sp,
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
