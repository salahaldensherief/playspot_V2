import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_state.dart';
import 'package:playspot/features/home/presentation/widgets/home_header.dart';

class HomeSliverAppBar extends StatelessWidget {
  final String userName;
  final String currentLocation;

  const HomeSliverAppBar({
    super.key,
    required this.userName,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.availableCities != current.availableCities ||
          previous.selectedCity != current.selectedCity ||
          previous.currentAddress != current.currentAddress ||
          previous.pointsBalance != current.pointsBalance ||
          (previous.status == HomeStatus.initial &&
              current.status == HomeStatus.loading),
      builder: (context, state) {
        final hasCities = state.availableCities.isNotEmpty;
        return SliverAppBar(
          backgroundColor: Colors.transparent,
          expandedHeight: hasCities ? 165.h : 120.h,
          pinned: true,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: HomeHeader(
              userName: userName,
              currentLocation: state.currentAddress ?? currentLocation,
              cities: state.availableCities,
              selectedCity: state.selectedCity,
              pointsBalance: state.pointsBalance,
              onCitySelected: (city) =>
                  context.read<HomeCubit>().selectCity(city),
            ),
          ),
        );
      },
    );
  }
}
