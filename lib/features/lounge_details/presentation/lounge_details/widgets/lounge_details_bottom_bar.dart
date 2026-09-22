import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class LoungeDetailsBottomBar extends StatelessWidget {
  final LoungeModel lounge;

  const LoungeDetailsBottomBar({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) =>
          previous.selectedRoomIds != current.selectedRoomIds ||
          previous.selectedExtras != current.selectedExtras ||
          previous.rooms != current.rooms ||
          previous.extras != current.extras ||
          previous.lounge != current.lounge,
      builder: (context, state) {
        final isRoomSelected = state.selectedRoomIds.isNotEmpty;
        final selectedCount = state.selectedRoomIds.length;
        final isOpen = lounge.isOpen;

        String buttonText;
        if (!isOpen) {
          buttonText = AppStrings.closed.tr().toUpperCase();
        } else if (!isRoomSelected) {
          buttonText = AppStrings.selectRoomsPrompt.tr();
        } else if (selectedCount == 1) {
          buttonText = AppStrings.bookARoom.tr();
        } else {
          buttonText = "${AppStrings.bookRoomsCount.tr()} ($selectedCount)";
        }

        return StickyBottomBar(
          child: AppButton(
            content: ButtonContent(
              body: AppText(
                fontFamily: 'Orbitron',
                textAlign: TextAlign.center,
                text: buttonText,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: (isRoomSelected && isOpen) ? AppColors.black : AppColors.white,
              ),
            ),
            behavior: ButtonBehavior.tap(
              isEnabled: isRoomSelected && isOpen,
              onTap: (isRoomSelected && isOpen)
                  ? () {
                      final selectedRooms = state.selectedRooms;
                      if (selectedRooms.isEmpty) return;

                      final selectedExtras =
                          state.selectedExtras.entries.map((entry) {
                        final extra =
                            state.extras.where((e) => e.id == entry.key).firstOrNull;
                        return {
                          'id': entry.key,
                          'name': extra?.name ?? 'Extra',
                          'price': extra?.price ?? 0.0,
                          'quantity': entry.value,
                        };
                      }).toList();

                      final firstRoom = selectedRooms.first;
                      final primaryPlayMode = state.roomPlayModes[firstRoom.id] ??
                          (firstRoom.isOpenArea ? 'single' : 'multi');
                      final primaryExtraControllers =
                          state.roomExtraControllers[firstRoom.id] ?? 0;

                      context.pushNamed(
                        RouterKeys.booking,
                        extra: BookingDetailsParams(
                          lounge: lounge,
                          rooms: selectedRooms,
                          selectedDate: state.selectedDate ?? DateTime.now(),
                          extras: selectedExtras,
                          playMode: primaryPlayMode,
                          extraControllers: primaryExtraControllers,
                          roomPlayModes: state.roomPlayModes,
                          roomExtraControllers: state.roomExtraControllers,
                        ),
                      );
                    }
                  : null,
            ),
            buttonConfig: ButtonConfig(
              gradient: (isRoomSelected && isOpen) ? AppColors.primaryGradient : null,
              glowColor: (isRoomSelected && isOpen) ? AppColors.neonBlueAlt : Colors.transparent,
              borderRadius: 15.r,
              width: 340.w,
              height: 50.h,
              backgroundColor: (isRoomSelected && isOpen)
                  ? AppColors.neonBlue
                  : AppColors.cardBackground,
              borderColor: (isRoomSelected && isOpen)
                  ? AppColors.neonBlue
                  : AppColors.borderDefault,
            ),
          ),
        );
      },
    );
  }
}
