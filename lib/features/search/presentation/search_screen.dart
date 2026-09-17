import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/widgets/svg_icon/svg_icon_widget.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/cards/search_lounge_card.dart';
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

  bool _isOpenNowFilter = false;
  int _sortFilterIndex = 0; // 0: None, 1: Highest Rated, 2: Nearest

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

  void _resetAllFilters() {
    setState(() {
      _isOpenNowFilter = false;
      _sortFilterIndex = 0;
      _searchController.clear();
      _searchQuery = "";
    });
  }

  bool get _hasActiveFilters =>
      _isOpenNowFilter || _sortFilterIndex != 0 || _searchQuery.isNotEmpty;

  List<LoungeModel> _filterAndSortLounges(List<LoungeModel> allLounges) {
    var result = allLounges.where((lounge) {
      if (_searchQuery.isNotEmpty) {
        final nameMatches = lounge.name.toLowerCase().contains(_searchQuery);
        final cityMatches = (lounge.city ?? '').toLowerCase().contains(_searchQuery);
        final addressMatches = (lounge.location ?? '').toLowerCase().contains(_searchQuery);
        if (!nameMatches && !cityMatches && !addressMatches) return false;
      }
      if (_isOpenNowFilter && !lounge.isOpen) {
        return false;
      }
      return true;
    }).toList();

    if (_sortFilterIndex == 1) {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortFilterIndex == 2) {
      result.sort((a, b) => a.distance.compareTo(b.distance));
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
                    return const AppLoader(size: 40);
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
          const BackButtonWidget(),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                return AppTextField(
                  controller: _searchController,
                  hint: AppStrings.searchLoungesHint.tr(),
                  borderRadius: 25.r,
                  onChanged: _onSearchChanged,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                );
              },
            ),
          ),
          SizedBox(width: 8.w),
          InkWell(
            onTap: _resetAllFilters,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: _hasActiveFilters
                    ? AppColors.neonBlue.withValues(alpha: 0.15)
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: _hasActiveFilters ? AppColors.neonBlue : AppColors.borderDefault,
                ),
              ),
              child: SvgIconWidget(
                path: AssetsManager.filter,
                color: _hasActiveFilters ? AppColors.neonBlue : AppColors.white,
                width: 20.w,
                height: 20.h,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final filters = [
      {'label': AppStrings.all.tr(), 'isAll': true},
      {'label': AppStrings.openNow.tr(), 'isOpenNow': true},
      {'label': AppStrings.highestRated.tr(), 'sortIndex': 1},
      {'label': AppStrings.nearest.tr(), 'sortIndex': 2},
    ];

    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final String label = filter['label'] as String;

          bool isSelected = false;
          if (filter['isAll'] == true) {
            isSelected = !_isOpenNowFilter && _sortFilterIndex == 0;
          } else if (filter['isOpenNow'] == true) {
            isSelected = _isOpenNowFilter;
          } else if (filter['sortIndex'] != null) {
            isSelected = _sortFilterIndex == filter['sortIndex'];
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                if (filter['isAll'] == true) {
                  _isOpenNowFilter = false;
                  _sortFilterIndex = 0;
                } else if (filter['isOpenNow'] == true) {
                  _isOpenNowFilter = !_isOpenNowFilter;
                } else if (filter['sortIndex'] != null) {
                  final sortIdx = filter['sortIndex'] as int;
                  _sortFilterIndex = _sortFilterIndex == sortIdx ? 0 : sortIdx;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.neonBlue.withValues(alpha: 0.15) : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
                  width: isSelected ? 1.2 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.neonBlue.withValues(alpha: 0.2),
                          blurRadius: 4.r,
                          spreadRadius: 1.r,
                        )
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: AppText(
                text: label,
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
