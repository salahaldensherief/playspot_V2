import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import '../home_cubit.dart';
import '../home_state.dart';
import 'promo_card.dart';
import 'tournament_promo_card.dart';

class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.isPromosLoading != current.isPromosLoading ||
          previous.promotions != current.promotions ||
          previous.nearbyTournament != current.nearbyTournament ||
          previous.activeRegisteredTournament !=
              current.activeRegisteredTournament ||
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
            height: totalCount > 1 ? 180.h : 160.h,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    itemCount: totalCount,
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      if (hasTournament && index == 0) {
                        final tournament = state.nearbyTournament;
                        if (tournament == null) return const SizedBox.shrink();
                        final isRegistered =
                            state.activeRegisteredTournament?.id ==
                            tournament.id;
                        final participant = isRegistered
                            ? state.activeUserParticipant
                            : null;
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
                          final roomId = promo.roomId;
                          if (roomId != null && roomId.isNotEmpty) {
                            context.pushNamed(
                              RouterKeys.roomDetails,
                              pathParameters: {'roomId': roomId},
                            );
                          } else if (promo.deepLink != null &&
                              promo.deepLink!.contains('/room/')) {
                            final parts = promo.deepLink!.split('/room/');
                            if (parts.length > 1 &&
                                parts[1].trim().isNotEmpty) {
                              context.pushNamed(
                                RouterKeys.roomDetails,
                                pathParameters: {'roomId': parts[1].trim()},
                              );
                            }
                          } else if (promo.deepLink == 'tournaments' ||
                              promo.id == 'tournaments') {
                            context.pushNamed(RouterKeys.tournaments);
                          } else if (promo.loungeId != null &&
                              promo.loungeId!.isNotEmpty) {
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
                if (totalCount > 1) ...[
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      totalCount,
                      (index) => Container(
                        width: index == _currentPage.clamp(0, totalCount - 1)
                            ? 16.w
                            : 6.w,
                        height: 6.h,
                        margin: EdgeInsets.symmetric(horizontal: 3.w),
                        decoration: BoxDecoration(
                          color: index == _currentPage.clamp(0, totalCount - 1)
                              ? AppColors.neonBlue
                              : AppColors.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
