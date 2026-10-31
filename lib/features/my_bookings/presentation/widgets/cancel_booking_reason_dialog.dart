import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class CancelBookingReasonDialog extends StatefulWidget {
  const CancelBookingReasonDialog({super.key});

  @override
  State<CancelBookingReasonDialog> createState() =>
      _CancelBookingReasonDialogState();
}

class _CancelBookingReasonDialogState extends State<CancelBookingReasonDialog> {
  final _detailsController = TextEditingController();
  String? _selectedReason;
  bool _showError = false;

  static const _reasons = [
    AppStrings.cancelReasonEmergency,
    AppStrings.cancelReasonCannotArrive,
    AppStrings.cancelReasonPlansChanged,
    AppStrings.cancelReasonOther,
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    final details = _detailsController.text.trim();
    final reason = _selectedReason == AppStrings.cancelReasonOther
        ? details
        : _selectedReason?.tr();
    if (reason == null || reason.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final otherSelected = _selectedReason == AppStrings.cancelReasonOther;
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                text: AppStrings.cancelBookingTitle.tr(),
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              AppText(
                text: AppStrings.cancelReasonPrompt.tr(),
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              const SizedBox(height: 16),
              for (final reason in _reasons) ...[
                _reasonOption(reason),
                const SizedBox(height: 8),
              ],
              if (otherSelected) ...[
                TextField(
                  controller: _detailsController,
                  autofocus: true,
                  maxLength: 300,
                  maxLines: 3,
                  minLines: 2,
                  style: const TextStyle(color: AppColors.white),
                  onChanged: (_) {
                    if (_showError) setState(() => _showError = false);
                  },
                  decoration: InputDecoration(
                    hintText: AppStrings.cancelReasonDetailsHint.tr(),
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              if (_showError) ...[
                const SizedBox(height: 4),
                AppText(
                  text: AppStrings.cancelReasonRequired.tr(),
                  color: AppColors.danger,
                  fontSize: 12,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: AppText(
                        text: AppStrings.keepBooking.tr(),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: AppText(
                        text: AppStrings.yesCancel.tr(),
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reasonOption(String reason) {
    final selected = _selectedReason == reason;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey(reason),
        onTap: () => setState(() {
          _selectedReason = reason;
          _showError = false;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.danger.withValues(alpha: 0.12)
                : AppColors.scaffoldBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.danger : AppColors.borderDefault,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected ? AppColors.danger : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  text: reason.tr(),
                  color: AppColors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
