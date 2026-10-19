import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../lounge_details/data/models/extra_model.dart';
import '../../domain/entities/canteen_combo.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/out_of_stock_item.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'canteen/canteen_category_bar.dart';
import 'canteen/canteen_combos_section.dart';
import 'canteen/canteen_dock_bar.dart';
import 'canteen/canteen_extras_section.dart';
import 'canteen/canteen_header.dart';
import 'canteen/canteen_note_field.dart';
import 'canteen/canteen_stock_warning.dart';

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
    if (session != null && session.loungeId.isNotEmpty) {
      widget.cubit.loadMenu(session.loungeId, forceRefresh: true);
    }
  }

  int _getExtraQty(String id) => _extraQuantities[id] ?? 0;
  int _getComboQty(String id) => _comboQuantities[id] ?? 0;

  ({Map<String, int> extras, Map<String, int> combos}) _effectiveCart(
    List<ExtraModel> extras,
    List<CanteenCombo> combos,
    List<OutOfStockItem> unavailable,
  ) {
    final remaining = <String, int>{
      for (final item in unavailable)
        item.id: item.available > 0 ? item.available : 0,
    };
    final selectedExtras = <String, int>{};
    final selectedCombos = <String, int>{};

    for (final item in extras) {
      if (!item.isAvailable) continue;
      final requested = _getExtraQty(item.id);
      if (requested <= 0) continue;
      final stock = remaining[item.id];
      final qty = stock != null && stock < requested ? stock : requested;
      if (qty <= 0) continue;
      selectedExtras[item.id] = qty;
      if (stock != null) remaining[item.id] = stock - qty;
    }

    for (final offer in combos) {
      if (!offer.isAvailable) continue;
      var qty = _getComboQty(offer.id);
      if (qty <= 0) continue;
      final offerStock = remaining[offer.id];
      if (offerStock != null && offerStock < qty) qty = offerStock;

      final requirements = <String, int>{};
      for (final component in offer.items) {
        if (component.quantity <= 0) continue;
        requirements.update(
          component.extraId,
          (current) => current + component.quantity,
          ifAbsent: () => component.quantity,
        );
      }
      for (final requirement in requirements.entries) {
        final stock = remaining[requirement.key];
        if (stock != null) {
          final capacity = stock ~/ requirement.value;
          if (capacity < qty) qty = capacity;
        }
      }
      if (qty <= 0) continue;
      selectedCombos[offer.id] = qty;
      if (offerStock != null) remaining[offer.id] = offerStock - qty;
      for (final requirement in requirements.entries) {
        final stock = remaining[requirement.key];
        if (stock != null) {
          remaining[requirement.key] = stock - qty * requirement.value;
        }
      }
    }

    return (extras: selectedExtras, combos: selectedCombos);
  }

  double _calculateTotal(
    List<ExtraModel> extras,
    List<CanteenCombo> combos,
    Map<String, int> extraQuantities,
    Map<String, int> comboQuantities,
  ) {
    double total = 0.0;
    extraQuantities.forEach((id, qty) {
      if (qty > 0) {
        final match = extras.where((e) => e.id == id);
        if (match.isNotEmpty && match.first.isAvailable) {
          total += match.first.price * qty;
        }
      }
    });
    comboQuantities.forEach((id, qty) {
      if (qty > 0) {
        final match = combos.where((c) => c.id == id);
        if (match.isNotEmpty && match.first.isAvailable) {
          total += match.first.price * qty;
        }
      }
    });
    return total;
  }

  int _totalItemCount(
    List<ExtraModel> extras,
    List<CanteenCombo> combos,
    Map<String, int> extraQuantities,
    Map<String, int> comboQuantities,
  ) {
    int count = 0;
    extraQuantities.forEach((id, qty) {
      if (extras.any((item) => item.id == id && item.isAvailable)) count += qty;
    });
    comboQuantities.forEach((id, qty) {
      if (combos.any((combo) => combo.id == id && combo.isAvailable)) {
        count += qty;
      }
    });
    return count;
  }

  OutOfStockItem? _findUnavailableExtra(
    List<OutOfStockItem> unavailable,
    String extraId,
  ) {
    for (final item in unavailable) {
      if (item.id == extraId) return item;
    }
    return null;
  }

  OutOfStockItem? _findUnavailableCombo(
    List<OutOfStockItem> unavailable,
    CanteenCombo combo,
  ) {
    for (final comp in combo.items) {
      for (final item in unavailable) {
        if (item.id == comp.extraId) return item;
      }
    }
    return null;
  }

  void _placeOrder(
    List<ExtraModel> extras,
    List<CanteenCombo> combos,
    Map<String, int> extraQuantities,
    Map<String, int> comboQuantities,
  ) {
    final List<OrderItem> items = [];
    extraQuantities.forEach((id, qty) {
      if (qty > 0) {
        final match = extras.where((e) => e.id == id);
        if (match.isNotEmpty && match.first.isAvailable) {
          final item = match.first;
          items.add(
            OrderItem(
              id: item.id,
              name: item.name,
              nameAr: item.nameAr,
              nameEn: item.nameEn,
              price: item.price,
              quantity: qty,
              note: _note,
              isCombo: false,
            ),
          );
        }
      }
    });

    comboQuantities.forEach((id, qty) {
      if (qty > 0) {
        final match = combos.where((c) => c.id == id);
        if (match.isNotEmpty && match.first.isAvailable) {
          final combo = match.first;
          items.add(
            OrderItem(
              id: combo.id,
              name: combo.nameAr,
              nameAr: combo.nameAr,
              nameEn: combo.nameEn,
              price: combo.price,
              quantity: qty,
              note: _note,
              isCombo: true,
            ),
          );
        }
      }
    });

    if (items.isNotEmpty) widget.cubit.placeOrder(items);
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
        final cart = _effectiveCart(extras, combos, unavailable);
        final total = _calculateTotal(extras, combos, cart.extras, cart.combos);
        final totalCount = _totalItemCount(
          extras,
          combos,
          cart.extras,
          cart.combos,
        );
        final isLoading = state.orderStatus == ActionStatus.loading;
        final session = state.session;

        final distinctCategories = <String>{};
        for (final extra in extras) {
          if (extra.category.trim().isNotEmpty) {
            distinctCategories.add(extra.category.trim());
          }
        }

        final filteredExtras =
            _selectedCategory == 'all' || _selectedCategory == 'combos'
            ? extras
            : extras
                  .where((e) => e.category.trim() == _selectedCategory)
                  .toList();

        final showCombos =
            (_selectedCategory == 'all' || _selectedCategory == 'combos') &&
            combos.isNotEmpty;
        final showExtras =
            _selectedCategory != 'combos' && filteredExtras.isNotEmpty;

        final stationSubtitle = session != null
            ? "${session.loungeName} • ${session.roomName}"
            : null;

        return Container(
          height: 0.90.sh,
          decoration: BoxDecoration(
            color: const Color(0xFF0C0E17),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            border: Border(
              top: BorderSide(
                color: AppColors.neonPurple.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonPurple.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CanteenHeader(
                stationSubtitle: stationSubtitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              SizedBox(height: 12.h),
              CanteenCategoryBar(
                selectedCategory: _selectedCategory,
                hasCombos: combos.isNotEmpty,
                categories: distinctCategories,
                onSelectCategory: (cat) =>
                    setState(() => _selectedCategory = cat),
              ),
              if (unavailable.isNotEmpty) ...[
                SizedBox(height: 10.h),
                const CanteenStockWarning(),
              ],
              SizedBox(height: 10.h),
              Expanded(
                child: ListView(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
                  children: [
                    if (showCombos)
                      CanteenCombosSection(
                        combos: combos,
                        unavailable: unavailable,
                        isArabic: isArabic,
                        getQty: (id) => cart.combos[id] ?? 0,
                        findUnavailable: _findUnavailableCombo,
                        onAdd: (combo) {
                          if (!combo.isAvailable) return;
                          setState(
                            () => _comboQuantities[combo.id] =
                                (cart.combos[combo.id] ?? 0) + 1,
                          );
                        },
                        onRemove: (combo) {
                          setState(
                            () => _comboQuantities[combo.id] =
                                ((cart.combos[combo.id] ?? 0) - 1).clamp(0, 99),
                          );
                        },
                      ),
                    if (showExtras)
                      CanteenExtrasSection(
                        extras: filteredExtras,
                        unavailable: unavailable,
                        isArabic: isArabic,
                        getQty: (id) => cart.extras[id] ?? 0,
                        findUnavailable: _findUnavailableExtra,
                        onAdd: (item) {
                          if (!item.isAvailable) return;
                          setState(
                            () => _extraQuantities[item.id] =
                                (cart.extras[item.id] ?? 0) + 1,
                          );
                        },
                        onRemove: (item) {
                          setState(
                            () => _extraQuantities[item.id] =
                                ((cart.extras[item.id] ?? 0) - 1).clamp(0, 99),
                          );
                        },
                      ),
                    CanteenNoteField(onChanged: (val) => _note = val),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
              CanteenDockBar(
                totalCount: totalCount,
                total: total,
                isLoading: isLoading,
                onOrder: () =>
                    _placeOrder(extras, combos, cart.extras, cart.combos),
              ),
            ],
          ),
        );
      },
    );
  }
}
