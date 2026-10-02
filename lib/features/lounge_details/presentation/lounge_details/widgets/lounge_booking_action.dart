import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'lounge_details_bottom_bar.dart';

class LoungeBookingAction extends StatelessWidget {
  final LoungeModel? initialLounge;
  const LoungeBookingAction({super.key, this.initialLounge});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) => a.lounge != b.lounge,
        builder: (context, state) {
          final lounge = state.lounge ?? initialLounge;
          return lounge == null
              ? const SizedBox.shrink()
              : LoungeDetailsBottomBar(lounge: lounge);
        },
      );
}
