import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/widgets/layout/app_divider.dart';
import '../../../../art_core/widgets/layout/section_header.dart';
import '../../../booking/presentation/widgets/date_selector.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class DateSelectionSection extends StatelessWidget {
  const DateSelectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: AppStrings.selectDate),
          BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
            builder: (context, state) {
              return DateSelector(
                selectedDate: state.selectedDate ?? DateTime.now(),
                onDateSelected: (date) =>
                    context.read<LoungeDetailsCubit>().selectDate(date),
              );
            },
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: const AppDivider(verticalPadding: 0),
          ),
        ],
      ),
    );
  }
}
