import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class LoungeHeaderTitle extends StatelessWidget {
  final LoungeModel? initialLounge;
  const LoungeHeaderTitle({super.key, this.initialLounge});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (a, b) => a.lounge != b.lounge,
        builder: (context, state) => Text(
          (state.lounge ?? initialLounge)?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      );
}
