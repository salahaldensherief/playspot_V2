import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'extras_list.dart';

class LoungeExtrasSection extends StatelessWidget {
  const LoungeExtrasSection({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) => a.extras != b.extras || a.status != b.status,
        builder: (context, state) =>
            state.extras.isEmpty && state.status != LoungeDetailsStatus.loading
            ? const SliverToBoxAdapter(child: SizedBox.shrink())
            : const SliverMainAxisGroup(
                slivers: [
                  SliverSectionHeader(title: AppStrings.extras, compact: true),
                  ExtrasList(),
                ],
              ),
      );
}
