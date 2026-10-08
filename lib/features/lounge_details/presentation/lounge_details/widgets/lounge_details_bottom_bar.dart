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

class LoungeDetailsBottomBar extends StatelessWidget {
  final LoungeModel lounge;
  const LoungeDetailsBottomBar({super.key, required this.lounge});

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
            a.bookedRoomIds != b.bookedRoomIds,
        builder: (context, state) {
          final selection = LoungeBookingSelection(
            state,
            state.lounge ?? lounge,
          );
          return StickyBottomBar(
            child: AppButton(
              content: ButtonContent(
                body: AppText(
                  text: _label(state),
                  textAlign: TextAlign.center,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: selection.isEnabled
                      ? AppColors.black
                      : AppColors.textSecondary,
                ),
              ),
              behavior: ButtonBehavior.tap(
                isEnabled: selection.isEnabled,
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
      return 'operating_status_unavailable'.tr();
    }
    if (state.operatingStatus?.canBookOnline == false &&
        state.operatingStatus?.status != 'closed') {
      return AppStrings.technicalIssue.tr();
    }
    if (state.operatingStatus?.isOpen == false) {
      return AppStrings.closed.tr();
    }
    if (state.selectedRooms.isEmpty) return AppStrings.selectRoomsPrompt.tr();
    if (state.selectedRooms.length == 1) return AppStrings.bookARoom.tr();
    return '${AppStrings.bookRoomsCount.tr()} (${state.selectedRooms.length})';
  }

  void _book(BuildContext context) {
    final state = context.read<LoungeDetailsCubit>().state;
    final params = LoungeBookingSelection(state, state.lounge ?? lounge).params;
    if (params != null) context.pushNamed(RouterKeys.booking, extra: params);
  }
}
