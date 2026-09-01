import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/shimmer/promo_shimmer.dart';
import '../home_cubit.dart';
import '../home_state.dart';
import 'promo_card.dart';

class PromoCarousel extends StatelessWidget {
  const PromoCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) => 
        previous.promotions != current.promotions || 
        (current.status == HomeStatus.loading && current.promotions.isEmpty),
      builder: (context, state) {
        if (state.status == HomeStatus.loading && state.promotions.isEmpty) {
          return const PromoShimmer();
        }

        if (state.promotions.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 160.h,
          child: PageView.builder(
            itemCount: state.promotions.length,
            controller: PageController(viewportFraction: 0.9),
            itemBuilder: (context, index) {
              final promo = state.promotions[index];
              return PromoCard(
                promo: promo,
                onTap: () {
                  if (promo.isRoomSpecific && promo.roomId != null) {
                    context.pushNamed(
                      RouterKeys.roomDetails,
                      pathParameters: {'roomId': promo.roomId!},
                    );
                  } else if (promo.loungeId != null) {
                    context.pushNamed(
                      RouterKeys.loungeDetails,
                      extra: {'loungeId': promo.loungeId},
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}
