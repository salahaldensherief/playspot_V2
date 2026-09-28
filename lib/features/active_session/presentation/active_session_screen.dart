import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'active_session_cubit.dart';
import 'active_session_state.dart';
import 'widgets/active_session_body.dart';
import 'widgets/extension_prompt_card.dart';

class ActiveSessionScreen extends StatefulWidget {
  final String? bookingId;
  final int? extensionMinutes;
  const ActiveSessionScreen({super.key, this.bookingId, this.extensionMinutes});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  bool _showExtensionBanner = false;
  int _extensionBannerMinutes = 30;

  @override
  void initState() {
    super.initState();
    final minutes = widget.extensionMinutes;
    if (minutes != null) {
      _extensionBannerMinutes = minutes;
      _showExtensionBanner = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ActiveSessionCubit>().loadActiveSession(bookingId: widget.bookingId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: SafeArea(
        child: BlocListener<ActiveSessionCubit, ActiveSessionState>(
          listenWhen: (prev, curr) =>
              prev.extendStatus != curr.extendStatus ||
              prev.orderStatus != curr.orderStatus ||
              prev.staffRequestStatus != curr.staffRequestStatus ||
              prev.session?.extensionStatus != curr.session?.extensionStatus ||
              prev.session?.endTime != curr.session?.endTime ||
              (prev.status != curr.status &&
                  (curr.status == ActiveSessionStatus.empty || curr.status == ActiveSessionStatus.loaded)),
          listener: (context, state) {
            final session = state.session;
            if (state.status == ActiveSessionStatus.loaded &&
                session != null &&
                session.isExpiringSoon &&
                !_showExtensionBanner &&
                !session.isExtensionPending) {
              setState(() {
                _showExtensionBanner = true;
              });
            }

            if (state.extendStatus == ActionStatus.success) {
              GameHudToast.show(
                context,
                AppStrings.extensionSentMsg.tr(),
                type: ToastType.info,
              );
            }
            if (session != null) {
              if (session.extensionStatus == 'approved') {
                GameHudToast.show(
                  context,
                  AppStrings.extensionApprovedMsg.tr(),
                  type: ToastType.success,
                );
              } else if (session.extensionStatus == 'rejected') {
                GameHudToast.show(
                  context,
                  AppStrings.extensionDeclinedMsg.tr(),
                  type: ToastType.warning,
                );
              }
            }
            if (state.orderStatus == ActionStatus.success) {
              GameHudToast.show(
                context,
                AppStrings.orderPlacedSuccess.tr(),
                type: ToastType.success,
              );
            }
            if (state.staffRequestStatus == ActionStatus.success) {
              GameHudToast.show(
                context,
                AppStrings.staffNotifiedSuccess.tr(),
                type: ToastType.success,
              );
            }
            final errorMsg = state.errorMessage;
            if (errorMsg != null &&
                (state.extendStatus == ActionStatus.error ||
                    state.orderStatus == ActionStatus.error ||
                    state.staffRequestStatus == ActionStatus.error)) {
              GameHudToast.show(
                context,
                errorMsg,
                type: ToastType.error,
              );
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: AppText(
                text: AppStrings.activeSession.tr(),
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: const BackButtonWidget(),
            ),
            body: Stack(
              children: [
                const ActiveSessionBody(),
                if (_showExtensionBanner)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ExtensionPromptCard(
                      initialMinutes: _extensionBannerMinutes,
                      onDismiss: () {
                        setState(() {
                          _showExtensionBanner = false;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
