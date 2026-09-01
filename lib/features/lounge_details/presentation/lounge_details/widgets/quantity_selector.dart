import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class QuantitySelector extends StatelessWidget {
  final String extraId;
  const QuantitySelector({super.key, required this.extraId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      builder: (context, state) {
        final qty = state.selectedExtras[extraId] ?? 0;
        return Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20.sp),
              onPressed: () => context.read<LoungeDetailsCubit>().updateExtraQuantity(extraId, -1),
            ),
            AppText(text: "$qty", fontSize: 16.sp, color: AppColors.white, fontWeight: FontWeight.bold),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: AppColors.neonPurple, size: 20.sp),
              onPressed: () => context.read<LoungeDetailsCubit>().updateExtraQuantity(extraId, 1),
            ),
          ],
        );
      },
    );
  }
}
