import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
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
              final isLoading = state.status == EditProfileStatus.loading;

              final currentCity = state.user?.getCityName(isArabic);
              if (currentCity != null && currentCity.isNotEmpty) {
                cubit.locationController.text = currentCity;
              }

              return AppTextField(
                controller: cubit.locationController,
                label: isArabic ? 'المدينة (تلقائي عبر GPS)' : 'City (Auto via GPS)',
                hint: isArabic ? 'اضغط تحديث موقعي...' : 'Tap update location...',
                readOnly: true,
                suffixIcon: Container(
                  margin: EdgeInsets.only(left: 8.w, right: 8.w, top: 4.h, bottom: 4.h),
                  child: AppButton(
                    buttonConfig: ButtonConfig(
                      backgroundColor: const Color(0xFF00E5FF),
                      textStyle: TextStyle(color: Colors.black, fontSize: 11.sp, fontWeight: FontWeight.bold),
                      borderRadius: 8.r,
                      height: 32.h,
                    ),
                    content: ButtonContent(
                      label: isArabic ? 'تحديث' : 'Update',
                      icon: isLoading ? null : const Icon(Icons.my_location, size: 14, color: Colors.black),
                      body: isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: AppLoader(size: 14, strokeWidth: 2, color: Colors.black),
                            )
                          : null,
                    ),
                    behavior: TapBehavior(
                      isEnabled: !isLoading,
                      onTap: isLoading ? null : () => cubit.updateLocation(),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
