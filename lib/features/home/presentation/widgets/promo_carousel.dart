import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import '../home_cubit.dart';
import '../home_state.dart';
import 'promo_card.dart';
import 'tournament_promo_card.dart';

class PromoCarousel extends StatelessWidget {
  const PromoCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) => 
        previous.isPromosLoading != current.isPromosLoading ||
        previous.promotions != current.promotions ||
        previous.nearbyTournament != current.nearbyTournament ||
        previous.activeRegisteredTournament != current.activeRegisteredTournament ||
        previous.activeUserParticipant != current.activeUserParticipant,
      builder: (context, state) {
        final hasTournament = state.nearbyTournament != null;
        final totalCount = (hasTournament ? 1 : 0) + state.promotions.length;

        if (totalCount == 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: SizedBox(
            height: 160.h,
            child: PageView.builder(
              itemCount: totalCount,
              controller: PageController(viewportFraction: 0.9),
              itemBuilder: (context, index) {
                if (hasTournament && index == 0) {
                  final tournament = state.nearbyTournament!;
                  final isRegistered = state.activeRegisteredTournament?.id == tournament.id;
                  final participant = isRegistered ? state.activeUserParticipant : null;
                  return TournamentPromoCard(
                    tournament: tournament,
                    isRegistered: isRegistered,
                    participant: participant,
                    onTap: () {
                      context.pushNamed(
                        RouterKeys.tournamentDetails,
                        pathParameters: {'id': tournament.id},
                      );
                    },
                  );
                }

                final promoIndex = hasTournament ? index - 1 : index;
                final promo = state.promotions[promoIndex];
                return PromoCard(
                  promo: promo,
                  onTap: () {
                    if (promo.roomId != null && promo.roomId!.isNotEmpty) {
                      context.pushNamed(
                        RouterKeys.roomDetails,
                        pathParameters: {'roomId': promo.roomId!},
                      );
                    } else if (promo.deepLink != null && promo.deepLink!.contains('/room/')) {
                      final parts = promo.deepLink!.split('/room/');
                      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
                        context.pushNamed(
                          RouterKeys.roomDetails,
                          pathParameters: {'roomId': parts[1].trim()},
                        );
                      }
                    } else if (promo.deepLink == 'tournaments' || promo.id == 'tournaments') {
                      context.pushNamed(RouterKeys.tournaments);
                    } else if (promo.loungeId != null && promo.loungeId!.isNotEmpty) {
                      context.pushNamed(
                        RouterKeys.loungeDetails,
                        extra: {'loungeId': promo.loungeId},
                      );
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
