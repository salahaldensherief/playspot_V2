import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../home_cubit.dart';
import '../home_state.dart';
import 'promo_card.dart';

class PromoCarousel extends StatelessWidget {
  const PromoCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) => previous.promotions != current.promotions,
      builder: (context, state) {
        if (state.promotions.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 160.h,
          child: PageView.builder(
            itemCount: state.promotions.length,
            controller: PageController(viewportFraction: 0.9),
            itemBuilder: (context, index) {
              return PromoCard(promo: state.promotions[index]);
            },
          ),
        );
      },
    );
  }
}
