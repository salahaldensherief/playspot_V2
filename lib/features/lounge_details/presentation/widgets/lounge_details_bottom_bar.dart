import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/router/router_keys.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../art_core/widgets/layout/sticky_bottom_bar.dart';
import '../../../home/data/models/lounge_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class LoungeDetailsBottomBar extends StatelessWidget {
  final LoungeModel lounge;

  const LoungeDetailsBottomBar({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) =>
          previous.selectedRoomId != current.selectedRoomId ||
          previous.selectedExtras != current.selectedExtras ||
          previous.rooms != current.rooms ||
          previous.extras != current.extras ||
          previous.lounge != current.lounge,
      builder: (context, state) {
        final isRoomSelected = state.selectedRoomId != null;
        final isOpen = lounge.isOpen;

        return StickyBottomBar(
          child: AppButton(
            content: ButtonContent(
              body: AppText(
                fontFamily: 'Orbitron',
                textAlign: TextAlign.center,
                text: isOpen ? AppStrings.bookARoom.tr() : AppStrings.closed.tr().toUpperCase(),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: (isRoomSelected && isOpen) ? AppColors.black : AppColors.white,
              ),
            ),
            behavior: ButtonBehavior.tap(
              isEnabled: isRoomSelected && isOpen,
              onTap: (isRoomSelected && isOpen)
                  ? () {
                      final selectedRoom = state.rooms.firstWhere(
                        (r) => r.id == state.selectedRoomId,
                      );
                      final selectedExtras =
                          state.selectedExtras.entries.map((entry) {
                        final extra =
                            state.extras.firstWhere((e) => e.id == entry.key);
                        return {
                          'id': extra.id,
                          'name': extra.name,
                          'price': extra.price,
                          'quantity': entry.value,
                        };
                      }).toList();

                      context.pushNamed(
                        RouterKeys.booking,
                        extra: {
                          'lounge': lounge,
                          'room': selectedRoom,
                          'selectedDate': state.selectedDate ?? DateTime.now(),
                          'extras': selectedExtras,
                        },
                      );
                    }
                  : null,
            ),
            buttonConfig: ButtonConfig(
              gradient: isOpen ? const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF9B59B6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ) : null,
              glowColor: isOpen ? const Color(0xFF00D4FF) : Colors.transparent,
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
