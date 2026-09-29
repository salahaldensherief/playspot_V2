import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/images/app_images.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../lounge_details/data/models/extra_model.dart';
import '../../domain/entities/canteen_combo.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/out_of_stock_item.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';

class MenuBottomSheet extends StatefulWidget {
  final ActiveSessionCubit cubit;
  const MenuBottomSheet({super.key, required this.cubit});

  @override
  State<MenuBottomSheet> createState() => _MenuBottomSheetState();
}

class _MenuBottomSheetState extends State<MenuBottomSheet> {
  final Map<String, int> _extraQuantities = {};
  final Map<String, int> _comboQuantities = {};
  String? _note;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    final session = widget.cubit.state.session;
    if (widget.cubit.state.menu.isEmpty && session != null && session.loungeId.isNotEmpty) {
      widget.cubit.loadMenu(session.loungeId);
    }
  }

  int _getExtraQty(String id) => _extraQuantities[id] ?? 0;
  int _getComboQty(String id) => _comboQuantities[id] ?? 0;

  double _calculateTotal(List<ExtraModel> extras, List<CanteenCombo> combos) {
    double total = 0.0;
    _extraQuantities.forEach((id, qty) {
      if (qty > 0) {
        final match = extras.where((e) => e.id == id);
        if (match.isNotEmpty) {
          total += match.first.price * qty;
        }
      }
    });
    _comboQuantities.forEach((id, qty) {
      if (qty > 0) {
        final match = combos.where((c) => c.id == id);
        if (match.isNotEmpty) {
          total += match.first.price * qty;
        }
      }
    });
    return total;
  }

  int _totalItemCount() {
    int count = 0;
    _extraQuantities.forEach((_, qty) => count += qty);
    _comboQuantities.forEach((_, qty) => count += qty);
    return count;
  }

  OutOfStockItem? _findUnavailableExtra(List<OutOfStockItem> unavailable, String extraId) {
    for (final item in unavailable) {
      if (item.id == extraId) return item;
    }
    return null;
  }

  OutOfStockItem? _findUnavailableCombo(List<OutOfStockItem> unavailable, CanteenCombo combo) {
    for (final comp in combo.items) {
      for (final item in unavailable) {
        if (item.id == comp.extraId) return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return BlocConsumer<ActiveSessionCubit, ActiveSessionState>(
      bloc: widget.cubit,
      listenWhen: (prev, curr) => prev.orderStatus != curr.orderStatus,
      listener: (context, state) {
        if (state.orderStatus == ActionStatus.success) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final extras = state.menu;
        final combos = state.combos;
        final unavailable = state.unavailableItems;
        final total = _calculateTotal(extras, combos);
        final totalCount = _totalItemCount();
        final isLoading = state.orderStatus == ActionStatus.loading;

        final categories = {'all'};
        for (final extra in extras) {
          if (extra.category.trim().isNotEmpty) {
            categories.add(extra.category.trim());
          }
        }

        final filteredExtras = _selectedCategory == 'all'
            ? extras
            : extras.where((e) => e.category.trim() == _selectedCategory).toList();

        return Container(
          height: 0.88.sh,
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu_rounded, color: AppColors.neonPurple, size: 22.sp),
                      SizedBox(width: 8.w),
                      AppText(
                        text: AppStrings.canteenMenu.tr(),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22.sp),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              // Stock Warning Banner if out of stock
              if (unavailable.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsetsDirectional.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: AppText(
                          text: AppStrings.outOfStockError.tr(),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 10.h),

              // Menu Content (Combos first, then single items)
              Expanded(
                child: ListView(
                  children: [
                    // Section 1: Combos
                    if (combos.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 18.sp),
                          SizedBox(width: 6.w),
                          AppText(
                            text: AppStrings.combosAndOffers.tr(),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      ...combos.map((combo) {
                        final qty = _getComboQty(combo.id);
                        final unavail = _findUnavailableCombo(unavailable, combo);
                        return _buildComboCard(combo, qty, unavail, isArabic);
                      }),
                      SizedBox(height: 16.h),
                    ],

                    // Section 2: Categories & Single Items
                    if (extras.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.fastfood_rounded, color: AppColors.neonBlue, size: 18.sp),
                          SizedBox(width: 6.w),
                          AppText(
                            text: AppStrings.singleItems.tr(),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),

                      // Category Chips
                      if (categories.length > 2) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              final label = cat == 'all' ? AppStrings.all.tr() : cat;
                              return Padding(
                                padding: EdgeInsetsDirectional.only(end: 8.w),
                                child: ChoiceChip(
                                  label: Text(label),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() => _selectedCategory = cat),
                                  selectedColor: AppColors.neonBlue.withValues(alpha: 0.25),
                                  backgroundColor: AppColors.cardBackground,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
                                    fontSize: 12.sp,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    side: BorderSide(
                                      color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(height: 10.h),
                      ],

                      ...filteredExtras.map((item) {
                        final qty = _getExtraQty(item.id);
                        final unavail = _findUnavailableExtra(unavailable, item.id);
                        return _buildExtraItem(item, qty, unavail, isArabic);
                      }),
                    ],
                  ],
                ),
              ),

              // Note Field
              SizedBox(height: 10.h),
              TextField(
                onChanged: (val) => _note = val,
                decoration: InputDecoration(
                  hintText: AppStrings.orderNoteHint.tr(),
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  contentPadding: EdgeInsetsDirectional.symmetric(horizontal: 14.w, vertical: 10.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: const BorderSide(color: AppColors.borderDefault),
                  ),
                ),
                style: TextStyle(color: AppColors.white, fontSize: 13.sp),
              ),
              SizedBox(height: 12.h),

              // Bottom Order Button with Total
              AppButton(
                content: ButtonContent(
                  label: totalCount > 0
                      ? "${AppStrings.confirmOrder.tr()} • ${total.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}"
                      : AppStrings.cartEmpty.tr(),
                ),
                behavior: TapBehavior(
                  isEnabled: totalCount > 0 && !isLoading,
                  isLoading: isLoading,
                  onTap: () => _placeOrder(extras, combos),
                ),
                buttonConfig: ButtonConfig(
                  height: 48.h,
                  backgroundColor: totalCount > 0 ? AppColors.neonBlue : AppColors.borderDefault,
                  borderRadius: 12.r,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComboCard(
    CanteenCombo combo,
    int qty,
    OutOfStockItem? unavailableItem,
    bool isArabic,
  ) {
    final title = combo.getName(isArabic);
    final componentsSummary = combo.items
        .map((c) => "${c.quantity}x ${c.getName(isArabic)}")
        .join(" + ");
    final hasSavings = combo.savings > 0;
    final imageUrl = combo.imageUrl;

    return Container(
      margin: EdgeInsetsDirectional.only(bottom: 10.h),
      padding: EdgeInsetsDirectional.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: unavailableItem != null
              ? AppColors.danger
              : (qty > 0 ? AppColors.neonPurple : AppColors.borderDefault),
          width: qty > 0 ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                AppImage(
                  urlImg: imageUrl,
                  width: 50.w,
                  height: 50.w,
                  fit: BoxFit.cover,
                  borderRadius: 10.r,
                ),
                SizedBox(width: 12.w),
              ] else ...[
                Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.fastfood_rounded, color: AppColors.neonPurple, size: 24.sp),
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            text: title,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                        if (hasSavings) ...[
                          Container(
                            padding: EdgeInsetsDirectional.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: AppText(
                              text: "${AppStrings.saveAmount.tr()} ${combo.savings.toStringAsFixed(0)} ${AppStrings.egpSymbol.tr()}",
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (componentsSummary.isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      AppText(
                        text: componentsSummary,
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        AppText(
                          text: "${combo.price.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}",
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonBlue,
                        ),
                        if (combo.separateItemsPrice > combo.price) ...[
                          SizedBox(width: 8.w),
                          Text(
                            "${combo.separateItemsPrice.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}",
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _buildQtyControls(
                qty: qty,
                onAdd: () {
                  widget.cubit.clearUnavailableItems();
                  setState(() => _comboQuantities[combo.id] = qty + 1);
                },
                onRemove: () {
                  widget.cubit.clearUnavailableItems();
                  setState(() => _comboQuantities[combo.id] = (qty - 1).clamp(0, 99));
                },
              ),
            ],
          ),
          if (unavailableItem != null) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsetsDirectional.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: AppText(
                text: AppStrings.remainingQuantity.tr(args: [unavailableItem.available.toString()]),
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExtraItem(
    ExtraModel item,
    int qty,
    OutOfStockItem? unavailableItem,
    bool isArabic,
  ) {
    final displayName = isArabic
        ? (item.nameAr.isNotEmpty ? item.nameAr : item.name)
        : (item.nameEn.isNotEmpty ? item.nameEn : item.name);
    final icon = item.icon?.trim();

    return Container(
      margin: EdgeInsetsDirectional.only(bottom: 8.h),
      padding: EdgeInsetsDirectional.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: unavailableItem != null
              ? AppColors.danger
              : (qty > 0 ? AppColors.neonBlue : AppColors.borderDefault),
          width: qty > 0 ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null && icon.isNotEmpty) ...[
                AppImage(
                  urlImg: icon,
                  width: 42.w,
                  height: 42.w,
                  fit: BoxFit.cover,
                  borderRadius: 8.r,
                ),
                SizedBox(width: 10.w),
              ] else ...[
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Icon(Icons.local_cafe_rounded, color: AppColors.neonBlue, size: 20.sp),
                ),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: displayName,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    SizedBox(height: 3.h),
                    AppText(
                      text: "${item.price.toStringAsFixed(2)} ${AppStrings.egpSymbol.tr()}",
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neonBlue,
                    ),
                  ],
                ),
              ),
              _buildQtyControls(
                qty: qty,
                onAdd: () {
                  widget.cubit.clearUnavailableItems();
                  setState(() => _extraQuantities[item.id] = qty + 1);
                },
                onRemove: () {
                  widget.cubit.clearUnavailableItems();
                  setState(() => _extraQuantities[item.id] = (qty - 1).clamp(0, 99));
                },
              ),
            ],
          ),
          if (unavailableItem != null) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsetsDirectional.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: AppText(
                text: AppStrings.remainingQuantity.tr(args: [unavailableItem.available.toString()]),
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQtyControls({
    required int qty,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (qty > 0) ...[
          InkWell(
            onTap: onRemove,
            child: Container(
              padding: EdgeInsetsDirectional.all(6.w),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderDefault),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(Icons.remove, size: 14.sp, color: AppColors.white),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: 10.w),
            child: AppText(
              text: '$qty',
              fontSize: 13.5.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
        ],
        InkWell(
          onTap: onAdd,
          child: Container(
            padding: EdgeInsetsDirectional.all(6.w),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.2),
              border: Border.all(color: AppColors.neonBlue),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Icon(Icons.add, size: 14.sp, color: AppColors.white),
          ),
        ),
      ],
    );
  }

  void _placeOrder(List<ExtraModel> extras, List<CanteenCombo> combos) {
    final List<OrderItem> items = [];

    _extraQuantities.forEach((id, qty) {
      if (qty > 0) {
        final match = extras.where((e) => e.id == id);
        if (match.isNotEmpty) {
          final item = match.first;
          items.add(OrderItem(
            id: item.id,
            name: item.name,
            nameAr: item.nameAr,
            nameEn: item.nameEn,
            price: item.price,
            quantity: qty,
            note: _note,
            isCombo: false,
          ));
        }
      }
    });

    _comboQuantities.forEach((id, qty) {
      if (qty > 0) {
        final match = combos.where((c) => c.id == id);
        if (match.isNotEmpty) {
          final combo = match.first;
          items.add(OrderItem(
            id: combo.id,
            name: combo.nameAr,
            nameAr: combo.nameAr,
            nameEn: combo.nameEn,
            price: combo.price,
            quantity: qty,
            note: _note,
            isCombo: true,
          ));
        }
      }
    });

    if (items.isNotEmpty) {
      widget.cubit.placeOrder(items);
    }
  }
}
