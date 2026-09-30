import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text/price_widget.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import '../../../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../../../art_core/widgets/buttons/res/button_style_config.dart';

class RoomActionArea extends StatelessWidget {
  final RoomModel room;
  final bool isAvailable;
  final bool isSelected;
  final Color themeColor;

  const RoomActionArea({
    super.key,
    required this.room,
    required this.isAvailable,
    required this.isSelected,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) return const SizedBox.shrink();
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (prev, curr) =>
          prev.roomPlayModes[room.id] != curr.roomPlayModes[room.id] ||
          prev.roomExtraControllers[room.id] !=
              curr.roomExtraControllers[room.id] ||
          prev.lounge != curr.lounge,
      builder: (context, state) {
        final playMode = state.roomPlayModes[room.id] ?? 'single';
        final extraControllers = state.roomExtraControllers[room.id] ?? 0;
        final lounge = state.lounge;
        final double loungeDiscount =
            (lounge != null && lounge.isDiscountActive)
            ? lounge.discountPercentage.toDouble()
            : 0.0;
        final bool hasOffer =
            (room.hasActivePromo && room.promoDiscountValue > 0) ||
            loungeDiscount > 0;

        final double finalEffectivePrice = room.calculateEffectiveRate(
          playMode: playMode,
          extraControllers: extraControllers,
          loungeDiscountPercentage: loungeDiscount,
        );
        final double finalOriginalPrice = room.calculateOriginalRate(
          playMode: playMode,
          extraControllers: extraControllers,
        );

        return Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final price = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasOffer)
                    AppText(
                      text:
                          '${finalOriginalPrice.toInt()} ${AppStrings.egp.tr()}',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      textDecoration: TextDecoration.lineThrough,
                    ),
                  PriceWidget(
                    price: finalEffectivePrice,
                    fontSize: 18,
                    color: hasOffer ? AppColors.success : themeColor,
                  ),
                  AppText(
                    text: AppStrings.perHour.tr(),
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ],
              );
              final select = Semantics(
                selected: isSelected,
                child: AppButton(
                  content: ButtonContent(
                    label: (isSelected ? 'room_selected' : 'room_select').tr(),
                    icon: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      color: isSelected ? AppColors.black : themeColor,
                    ),
                  ),
                  buttonConfig: ButtonConfig(
                    height: 48,
                    borderRadius: 12,
                    backgroundColor: isSelected
                        ? themeColor
                        : themeColor.withValues(alpha: 0.12),
                    borderColor: themeColor,
                    textStyle: TextStyle(
                      color: isSelected ? AppColors.black : themeColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  behavior: ButtonBehavior.tap(
                    onTap: () => context
                        .read<LoungeDetailsCubit>()
                        .toggleRoomSelection(room.id),
                  ),
                ),
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [price, const SizedBox(height: 12), select],
                );
              return Row(
                children: [
                  Expanded(child: price),
                  const SizedBox(width: 16),
                  Expanded(child: select),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
