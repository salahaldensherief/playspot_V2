import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/features/booking/presentation/widgets/date_selector.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class DateSelectionSection extends StatelessWidget {
  const DateSelectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
        buildWhen: (previous, current) => previous.selectedDate != current.selectedDate,
        builder: (context, state) {
          return DateSelector(
            selectedDate: state.selectedDate ?? DateTime.now(),
            onDateSelected: (date) =>
                context.read<LoungeDetailsCubit>().selectDate(date),
          );
        },
      ),
    );
  }
}
