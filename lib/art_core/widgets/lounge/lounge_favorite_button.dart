import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../features/favorites/presentation/favorites_cubit.dart';
import '../../../features/favorites/presentation/favorites_state.dart';
import '../../theme/app_colors.dart';

class LoungeFavoriteButton extends StatelessWidget {
  final String loungeId;
  const LoungeFavoriteButton({super.key, required this.loungeId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, state) {
        final isFavorite = context.read<FavoritesCubit>().isFavorite(loungeId);
        return GestureDetector(
          onTap: () => context.read<FavoritesCubit>().toggleFavorite(loungeId),
          child: Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? AppColors.danger : AppColors.white,
              size: 18.sp,
            ),
          ),
        );
      },
    );
  }
}
