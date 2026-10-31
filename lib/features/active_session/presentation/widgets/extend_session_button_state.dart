part of 'extend_session_button.dart';

class _ExtendSessionButtonState extends State<ExtendSessionButton> {
  bool _open = false;
  Future<void> _show() async {
    if (_open) return;
    final cubit = context.read<ActiveSessionCubit>();
    final session = cubit.state.session;
    if (session == null || session.isExtensionPending) return;
    _open = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.scaffoldBackground,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: ExtensionBottomSheet(bookingId: session.bookingId),
        ),
      );
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
        buildWhen: (previous, current) =>
            previous.session != current.session ||
            previous.extendStatus != current.extendStatus,
        builder: (context, state) => AppButton(
          content: ButtonContent(
            label: state.session?.isExtensionPending == true
                ? AppStrings.extensionPendingTitle.tr()
                : AppStrings.extendTime.tr(),
            icon: const Icon(Icons.add_alarm_rounded),
          ),
          buttonConfig: ButtonConfig(
            height: 52,
            backgroundColor: AppColors.cardBackground,
            borderColor: AppColors.neonBlue.withValues(alpha: 0.4),
            borderRadius: 14,
          ),
          behavior: ButtonBehavior.tap(
            isEnabled:
                state.session != null &&
                state.session?.isExtensionPending != true &&
                state.extendStatus != ActionStatus.loading,
            onTap: _show,
          ),
        ),
      );
}
