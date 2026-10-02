import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import '../lounge_comparison_facts.dart';
import 'room_card/room_feature_item.dart';
import 'room_card/room_detail_chip.dart';

class LoungeRoomComparison extends StatelessWidget {
  const LoungeRoomComparison({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) => a.rooms != b.rooms,
        builder: (context, state) {
          if (state.rooms.isEmpty) return const SizedBox.shrink();
          final facts = LoungeComparisonFacts.fromRooms(
            state.rooms,
            isArabic: context.locale.languageCode == 'ar',
          );
          final rate = facts.minimumBaseRate;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 24, color: Colors.white12),
              Text(
                'lounge_comparison_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    'lounge_comparison_rooms'.tr(
                      namedArgs: {'count': '${facts.roomCount}'},
                    ),
                  ),
                  if (facts.maxCapacity > 0)
                    Text(
                      'lounge_comparison_capacity'.tr(
                        namedArgs: {'count': '${facts.maxCapacity}'},
                      ),
                    ),
                ],
              ),
              if (rate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'lounge_comparison_from'.tr(
                      namedArgs: {
                        'price': NumberFormat(
                          '#,##0.##',
                          context.locale.toLanguageTag(),
                        ).format(rate),
                      },
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              if (facts.activities.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: facts.activities
                        .map(
                          (a) =>
                              RoomDetailChip(label: a, themeColor: Colors.cyan),
                        )
                        .toList(),
                  ),
                ),
              if (facts.features.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: facts.features
                        .map((f) => RoomFeatureItem(feature: f))
                        .toList(),
                  ),
                ),
            ],
          );
        },
      );
}
