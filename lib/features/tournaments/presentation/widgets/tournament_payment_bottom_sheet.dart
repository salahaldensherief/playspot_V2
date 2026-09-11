import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';

class TournamentPaymentBottomSheet extends StatefulWidget {
  final double entryFee;
  final Function(String paymentMethod, File receiptFile) onSubmit;

  const TournamentPaymentBottomSheet({
    super.key,
    required this.entryFee,
    required this.onSubmit,
  });

  @override
  State<TournamentPaymentBottomSheet> createState() => _TournamentPaymentBottomSheetState();
}

class _TournamentPaymentBottomSheetState extends State<TournamentPaymentBottomSheet> {
  String _selectedMethod = 'InstaPay';
  File? _receiptFile;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (picked != null) {
        setState(() {
          _receiptFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errorPickingImage'.tr(args: ['$e']))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar Indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                const Icon(
                  TablerIcons.receipt_2,
                  color: AppColors.neonBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'paymentInstructions'.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Entry Fee Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mutedBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'entryFee'.tr(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${widget.entryFee.toStringAsFixed(0)} ${'egp'.tr()}',
                    style: const TextStyle(
                      color: AppColors.neonBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment Method Selector
            Text(
              'paymentMethod'.tr(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildMethodTile(
                    title: 'InstaPay',
                    subtitle: 'instapay@playspot',
                    isSelected: _selectedMethod == 'InstaPay',
                    icon: TablerIcons.device_mobile,
                    onTap: () => setState(() => _selectedMethod = 'InstaPay'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMethodTile(
                    title: 'Vodafone Cash',
                    subtitle: '01000000000',
                    isSelected: _selectedMethod == 'Vodafone Cash',
                    icon: TablerIcons.wallet,
                    onTap: () => setState(() => _selectedMethod = 'Vodafone Cash'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Upload Receipt Section
            Text(
              'uploadReceipt'.tr(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (_receiptFile != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _receiptFile!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.7),
                      radius: 16,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => setState(() => _receiptFile = null),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickReceipt(ImageSource.gallery),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: AppColors.mutedBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.borderDefault,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              TablerIcons.photo,
                              color: AppColors.neonBlue,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'selectReceiptImage'.tr(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickReceipt(ImageSource.camera),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: AppColors.mutedBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              TablerIcons.camera,
                              color: AppColors.neonPurple,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'camera'.tr(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // Submit Button
            AppButton(
              buttonConfig: ButtonConfig.gradient(
                gradient: AppColors.primaryGradient,
                glowColor: AppColors.neonBlueAlt,
                width: double.infinity,
              ),
              content: ButtonContent(label: 'submitPayment'.tr()),
              behavior: TapBehavior(
                isEnabled: _receiptFile != null,
                isLoading: _isUploading,
                onTap: () async {
                  if (_receiptFile == null) return;
                  setState(() => _isUploading = true);
                  await widget.onSubmit(_selectedMethod, _receiptFile!);
                  if (mounted) {
                    setState(() => _isUploading = false);
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue.withOpacity(0.1) : AppColors.mutedBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? AppColors.neonBlue : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
