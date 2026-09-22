import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/images/app_images.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../../domain/entities/order_item.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import '../../../lounge_details/data/models/extra_model.dart';

class MenuBottomSheet extends StatefulWidget {
  final ActiveSessionCubit cubit;
  const MenuBottomSheet({super.key, required this.cubit});

  @override
  State<MenuBottomSheet> createState() => _MenuBottomSheetState();
}

class _MenuBottomSheetState extends State<MenuBottomSheet> {
  final Map<String, int> _quantities = {};
  String? _note;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.8.sh,
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
        bloc: widget.cubit,
        builder: (context, state) {
          if (state.menu.isEmpty) {
            return Center(child: AppText(text: AppStrings.noExtrasAvailable.tr()));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              AppText(
                text: AppStrings.orderExtras.tr(),
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: ListView.separated(
                  itemCount: state.menu.length,
                  separatorBuilder: (context, index) => const Divider(color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final item = state.menu[index];
                    final qty = _quantities[item.id] ?? 0;
                    return _buildMenuItem(item, qty);
                  },
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                onChanged: (val) => _note = val,
                decoration: InputDecoration(
                  hintText: AppStrings.addNote.tr(),
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.borderDefault),
                  ),
                ),
                style: const TextStyle(color: AppColors.white),
              ),
              SizedBox(height: 16.h),
              AppButton(
                content: ButtonContent(label: AppStrings.placeOrder.tr()),
                behavior: ButtonBehavior.tap(
                  onTap: () => _placeOrder(context, state.menu),
                ),
                buttonConfig: ButtonConfig(
                  height: 48.h,
                  backgroundColor: AppColors.neonBlue,
                  borderRadius: 12.r,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(ExtraModel item, int qty) {
    final displayName = item.name.isNotEmpty ? item.name : 'Item';
    final icon = item.icon?.trim();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          if (icon != null && icon.isNotEmpty) ...[
            AppImage(
              urlImg: icon,
              width: 40.w,
              height: 40.h,
              fit: BoxFit.cover,
              borderRadius: 8.r,
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: displayName,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
                SizedBox(height: 4.h),
                AppText(
                  text: "${item.price.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}",
                  fontSize: 13.sp,
                  color: AppColors.neonBlue,
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (qty > 0) ...[
                _buildQtyBtn(Icons.remove, () {
                  setState(() {
                    _quantities[item.id] = qty - 1;
                  });
                }),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: AppText(
                    text: '$qty',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
              _buildQtyBtn(Icons.add, () {
                setState(() {
                  _quantities[item.id] = qty + 1;
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderDefault),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Icon(icon, size: 16.sp, color: AppColors.white),
      ),
    );
  }

  void _placeOrder(BuildContext context, List<ExtraModel> menu) {
    final List<OrderItem> items = [];
    _quantities.forEach((id, qty) {
      if (qty > 0) {
        final item = menu.firstWhere((m) => m.id == id);
        items.add(OrderItem(
          id: item.id,
          name: item.name,
          nameAr: item.nameAr,
          nameEn: item.nameEn,
          price: item.price,
          quantity: qty,
          note: _note,
        ));
      }
    });

    if (items.isNotEmpty) {
      widget.cubit.placeOrder(items).then((_) {
        if (context.mounted && widget.cubit.state.orderStatus == ActionStatus.success) {
          Navigator.pop(context);
        }
      });
    }
  }
}
