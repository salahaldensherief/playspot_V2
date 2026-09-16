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
              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
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
            buildWhen: (prev, curr) => prev.user != curr.user || prev.status != curr.status,
            builder: (context, state) {
              final isArabic = context.locale.languageCode == 'ar';
              final cityName = state.user?.getCityName(isArabic) ?? 'غير محدد';
              final isLoading = state.status == EditProfileStatus.loading;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'المدينة (تلقائي عبر GPS)' : 'City (Auto via GPS)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFF2E2E3E)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            cityName,
                            style: TextStyle(
                              color: cityName == 'غير محدد' ? Colors.white54 : Colors.white,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : () => cubit.updateLocation(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          icon: isLoading
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.my_location, size: 16),
                          label: Text(
                            isArabic ? 'تحديث موقعي' : 'Update Location',
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
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
