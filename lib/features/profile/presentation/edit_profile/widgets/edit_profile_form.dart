import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
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
        ],
      ),
    );
  }
}
