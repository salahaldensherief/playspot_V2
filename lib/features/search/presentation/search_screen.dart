import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/svg_icon/svg_icon_widget.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/art_core/widgets/shimmer/search_lounge_card_shimmer.dart';
import 'package:playspot/art_core/widgets/cards/search_lounge_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_state.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = "";
  int _selectedFilterIndex = 0;

  List<String> get _filterOptions => [
        AppStrings.all.tr(),
        AppStrings.openNow.tr(),
        AppStrings.highestRated.tr(),
        AppStrings.nearest.tr(),
      ];

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
        });
      }
    });
  }

  List<LoungeModel> _filterAndSortLounges(List<LoungeModel> allLounges) {
    var result = allLounges.where((lounge) {
      if (_searchQuery.isEmpty) return true;
      final nameMatches = lounge.name.toLowerCase().contains(_searchQuery);
      final cityMatches = (lounge.city ?? '').toLowerCase().contains(_searchQuery);
      final addressMatches = (lounge.location ?? '').toLowerCase().contains(_searchQuery);
      return nameMatches || cityMatches || addressMatches;
    }).toList();

    switch (_selectedFilterIndex) {
      case 1: // Open Now
        result = result.where((l) => l.isOpen).toList();
        break;
      case 2: // Highest Rated
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 3: // Nearest
        result.sort((a, b) => a.distance.compareTo(b.distance));
        break;
      case 0:
      default:
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            SizedBox(height: 8.h),
            _buildCategories(),
            SizedBox(height: 12.h),
            Expanded(
              child: BlocBuilder<HomeCubit, HomeState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status ||
                    previous.nearestLounges != current.nearestLounges,
                builder: (context, state) {
                  if (state.status == HomeStatus.loading) {
                    return ListView.separated(
                      padding: EdgeInsets.all(16.w),
                      itemCount: 5,
                      separatorBuilder: (context, index) => SizedBox(height: 16.h),
                      itemBuilder: (context, index) => const SearchLoungeCardShimmer(),
                    );
                  }

                  final lounges = _filterAndSortLounges(state.nearestLounges);

                  if (lounges.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_outlined,
                              size: 64.sp,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 16.h),
                            AppText(
                              text: AppStrings.noLoungesFound.tr(),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: lounges.length + 1,
                    separatorBuilder: (context, index) => SizedBox(height: 16.h),
                    itemBuilder: (context, index) {
                      if (index == lounges.length) {
                        return const SafeBottomSpacer();
                      }
                      return SearchLoungeCard(lounge: lounges[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
          ),
          Expanded(
            child: AppTextField(
              controller: _searchController,
              hint: AppStrings.searchLoungesHint.tr(),
              borderRadius: 25.r,
              onChanged: _onSearchChanged,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: SvgIconWidget(
              path: AssetsManager.filter,
              color: AppColors.white,
              width: 20.w,
              height: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final filterName = _filterOptions[index];
          final isSelected = _selectedFilterIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilterIndex = index),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.transparent : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
                  width: .8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.neonBlue.withValues(alpha: 0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: AppText(
                text: filterName,
                fontSize: 13.sp,
                color: isSelected ? AppColors.neonBlue : AppColors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}
