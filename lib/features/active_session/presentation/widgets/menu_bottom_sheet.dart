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
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import '../../data/models/order_item_model.dart';
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
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: ListView.separated(
                  itemCount: state.menu.length,
                  separatorBuilder: (_, _) => Divider(color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final item = state.menu[index];
                    final qty = _quantities[item.id] ?? 0;
                    return _buildMenuItem(item, qty);
                  },
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                onChanged: (v) => _note = v,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: AppStrings.addNote.tr(),
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              AppButton(
                content: ButtonContent(
                  label: AppStrings.placeOrder.tr(),
                ),
                buttonConfig: ButtonConfig(
                  width: double.infinity,
                  backgroundColor: AppColors.primary,
                ),
                behavior: TapBehavior(
                  isEnabled: _quantities.values.any((q) => q > 0),
                  isLoading: state.orderStatus == ActionStatus.loading,
                  onTap: () => _placeOrder(context, state.menu),
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          if (item.icon != null && item.icon!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.network(
                item.icon!,
                width: 40.w,
                height: 40.h,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
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
                  text: "${item.price} ${AppStrings.egpSymbol.tr()}",
                  fontSize: 12.sp,
                  color: AppColors.neonPurple,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildQtyBtn(Icons.remove, () {
                if (qty > 0) {
                  setState(() => _quantities[item.id] = qty - 1);
                }
              }),
              SizedBox(width: 12.w),
              AppText(
                text: qty.toString(),
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              SizedBox(width: 12.w),
              _buildQtyBtn(Icons.add, () {
                setState(() => _quantities[item.id] = qty + 1);
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
    final List<OrderItemModel> items = [];
    _quantities.forEach((id, qty) {
      if (qty > 0) {
        final item = menu.firstWhere((m) => m.id == id);
        items.add(OrderItemModel(
          id: item.id,
          name: item.name,
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
