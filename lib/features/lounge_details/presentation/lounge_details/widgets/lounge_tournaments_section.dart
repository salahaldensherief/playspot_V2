import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/layout/sliver_section_header.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'lounge_tournament_banner.dart';

class LoungeTournamentsSection extends StatelessWidget {
  const LoungeTournamentsSection({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) => a.tournaments != b.tournaments,
        builder: (context, state) => state.tournaments.isEmpty
            ? const SliverToBoxAdapter(child: SizedBox.shrink())
            : SliverMainAxisGroup(
                slivers: [
                  const SliverSectionHeader(title: AppStrings.tournaments),
                  LoungeTournamentBanner(tournament: state.tournaments.first),
                ],
              ),
      );
}
