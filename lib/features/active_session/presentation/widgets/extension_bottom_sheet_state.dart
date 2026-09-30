part of 'extension_bottom_sheet.dart';

class _ExtensionBottomSheetState extends State<ExtensionBottomSheet> {
  int? _minutes;
  bool _submitted = false;
  Future<void> _confirm() async {
    final cubit = context.read<ActiveSessionCubit>();
    final minutes = _minutes;
    if (_submitted ||
        minutes == null ||
        cubit.state.session?.bookingId != widget.bookingId ||
        cubit.state.session?.isExtensionPending == true)
      return;
    setState(() => _submitted = true);
    await cubit.requestExtension(minutes);
    if (!mounted) return;
    if (cubit.state.extendStatus == ActionStatus.success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _submitted = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
    buildWhen: (previous, current) =>
        previous.session != current.session ||
        previous.extendStatus != current.extendStatus,
    builder: (context, state) {
      final valid =
          state.session?.bookingId == widget.bookingId &&
          state.session?.isExtensionPending != true;
      final labels = {
        15: AppStrings.min15.tr(),
        30: AppStrings.min30.tr(),
        60: AppStrings.hr1.tr(),
      };
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppText(
                  text: AppStrings.confirmExtensionTitle.tr(),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 16),
                for (final minutes in labels.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppButton(
                      key: ValueKey('extension-option-$minutes'),
                      content: ButtonContent(
                        label:
                            '${labels[minutes]}${_minutes == minutes ? ' ✓' : ''}',
                      ),
                      buttonConfig: ButtonConfig(
                        height: 52,
                        backgroundColor: _minutes == minutes
                            ? AppColors.neonBlue
                            : AppColors.cardBackground,
                      ),
                      behavior: ButtonBehavior.tap(
                        isEnabled: valid && !_submitted,
                        onTap: () => setState(() => _minutes = minutes),
                      ),
                    ),
                  ),
                if (_minutes != null)
                  AppText(
                    text: AppStrings.confirmExtensionSubtitle.tr(
                      args: [
                        labels[_minutes] ?? '',
                        context
                            .read<ActiveSessionCubit>()
                            .calculateExtensionCost(_minutes ?? 0)
                            .toInt()
                            .toString(),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (!valid)
                  AppText(text: AppStrings.extensionPendingTitle.tr()),
                const SizedBox(height: 16),
                AppButton(
                  key: const ValueKey('extension-confirm'),
                  content: ButtonContent(label: AppStrings.next.tr()),
                  buttonConfig: ButtonConfig(
                    height: 52,
                    backgroundColor: AppColors.neonBlue,
                  ),
                  behavior: ButtonBehavior.tap(
                    isEnabled: valid && _minutes != null && !_submitted,
                    isLoading: _submitted,
                    onTap: _confirm,
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  content: ButtonContent(label: AppStrings.cancel.tr()),
                  buttonConfig: ButtonConfig(
                    height: 48,
                    backgroundColor: Colors.transparent,
                  ),
                  behavior: ButtonBehavior.tap(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
