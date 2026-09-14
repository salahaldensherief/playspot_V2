import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/features/profile/presentation/edit_profile/edit_profile_state.dart';
import '../edit_profile_cubit.dart';

class EditProfileForm extends StatelessWidget {
  final EditProfileCubit cubit;

  const EditProfileForm({super.key, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: cubit.formKey,
      child: Column(
        children: [
          AppTextField(
            controller: cubit.nameController,
            label: AppStrings.name.tr(),
            hint: AppStrings.name.tr(),
            isRequired: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppStrings.pleaseEnterUsername.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 20.h),
          AppTextField(
            controller: cubit.emailController,
            label: AppStrings.email.tr(),
            hint: AppStrings.email.tr(),
            isRequired: true,
            textInputType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppStrings.pleaseEnterEmail.tr();
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return AppStrings.pleaseEnterValidEmail.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 20.h),
          AppTextField(
            controller: cubit.phoneController,
            label: AppStrings.phone.tr(),
            hint: AppStrings.phone.tr(),
            isRequired: true,
            textInputType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppStrings.pleaseEnterPhoneNum.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 20.h),
          BlocBuilder<EditProfileCubit, EditProfileState>(
            bloc: cubit,
            buildWhen: (prev, curr) => prev.cities != curr.cities || prev.selectedCityId != curr.selectedCityId,
            builder: (context, state) {
              if (state.cities.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'city'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  DropdownButtonFormField<String>(
                    initialValue: state.cities.any((c) => c['id']?.toString() == state.selectedCityId)
                        ? state.selectedCityId
                        : null,
                    dropdownColor: const Color(0xFF1E1E28),
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1A1A24),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Color(0xFF2E2E3E)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Color(0xFF2E2E3E)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                      ),
                    ),
                    hint: Text(
                      'selectCity'.tr(),
                      style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                    ),
                    items: state.cities.map((city) {
                      final id = city['id']?.toString() ?? '';
                      final cityName = city['name']?.toString() ??
                          city['name_ar']?.toString() ??
                          city['name_en']?.toString() ??
                          city['city']?.toString() ??
                          'City';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(cityName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      cubit.selectCity(val);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
