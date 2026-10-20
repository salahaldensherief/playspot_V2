import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/sticky_bottom_bar.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

import '../lounge_booking_selection.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'booking_canteen_offer_dialog.dart';

class LoungeDetailsBottomBar extends StatefulWidget {
  final LoungeModel lounge;
  const LoungeDetailsBottomBar({super.key, required this.lounge});

  @override
  State<LoungeDetailsBottomBar> createState() => _LoungeDetailsBottomBarState();
}

class _LoungeDetailsBottomBarState extends State<LoungeDetailsBottomBar> {
  bool _checkingMenu = false;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) =>
            a.selectedRoomIds != b.selectedRoomIds ||
            a.rooms != b.rooms ||
            a.lounge != b.lounge ||
            a.operatingStatus != b.operatingStatus ||
            a.isDateLoading != b.isDateLoading ||
            a.status != b.status ||
            a.availabilityLoadFailed != b.availabilityLoadFailed ||
            a.bookedRoomIds != b.bookedRoomIds,
        builder: (context, state) {
          final selection = LoungeBookingSelection(
            state,
            state.lounge ?? widget.lounge,
          );
          return StickyBottomBar(
            child: AppButton(
              content: ButtonContent(
                body: AppText(
                  text: _checkingMenu
                      ? AppStrings.bookingCanteenCheckingMenu.tr()
                      : _label(state),
                  textAlign: TextAlign.center,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: selection.isEnabled && !_checkingMenu
                      ? AppColors.black
                      : AppColors.textSecondary,
                ),
              ),
              behavior: ButtonBehavior.tap(
                isEnabled: selection.isEnabled && !_checkingMenu,
                onTap: () => _book(context),
              ),
              buttonConfig: ButtonConfig(
                width: double.infinity,
                height: 56 * MediaQuery.textScalerOf(context).scale(1),
                borderRadius: 15,
                gradient: AppColors.primaryGradient,
                glowColor: AppColors.neonBlueAlt,
                backgroundColor: AppColors.neonBlue,
                borderColor: AppColors.neonBlue,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      );

  String _label(LoungeDetailsState state) {
    if (state.operatingStatus == null ||
        state.operatingStatus?.status == 'unavailable') {
      return AppStrings.operatingStatusUnavailable.tr();
    }
    if (state.operatingStatus?.canBookOnline == false &&
        state.operatingStatus?.canBookOnDate(state.selectedDate) != true &&
        state.operatingStatus?.status != 'closed') {
      return AppStrings.technicalIssue.tr();
    }
    if (state.operatingStatus?.isOpen == false &&
        state.operatingStatus?.canBookOnDate(state.selectedDate) != true) {
      return AppStrings.closed.tr();
    }
    if (state.availabilityLoadFailed) {
      return AppStrings.roomAvailabilityUnavailable.tr();
    }
    if (state.selectedRooms.isEmpty) return AppStrings.selectRoomsPrompt.tr();
    if (state.selectedRooms.length == 1) return AppStrings.bookARoom.tr();
    return '${AppStrings.bookRoomsCount.tr()} (${state.selectedRooms.length})';
  }

  Future<void> _book(BuildContext context) async {
    if (_checkingMenu) return;
    final cubit = context.read<LoungeDetailsCubit>();
    final state = cubit.state;
    final lounge = state.lounge ?? widget.lounge;
    if (LoungeBookingSelection(state, lounge).params == null) {
      return;
    }
    setState(() => _checkingMenu = true);
    try {
      final hasCanteen = await cubit.refreshBookingCanteen(lounge.id);
      if (!context.mounted) return;
      if (hasCanteen == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(text: AppStrings.canteenRefreshError.tr())),
        );
        return;
      }
      if (hasCanteen) {
        final keepExtras = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 600),
          backgroundColor: Colors.transparent,
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: const BookingCanteenOfferDialog(),
          ),
        );
        if (!context.mounted || keepExtras == null) return;
        if (!keepExtras) cubit.clearSelectedExtras();
      }

      final currentState = cubit.state;
      final params = LoungeBookingSelection(
        currentState,
        currentState.lounge ?? widget.lounge,
      ).params;
      if (params != null && context.mounted) {
        context.pushNamed(RouterKeys.booking, extra: params);
      }
    } finally {
      if (mounted) setState(() => _checkingMenu = false);
    }
  }
}
