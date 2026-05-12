
import 'package:flutter/material.dart';


abstract class ButtonBehavior {
  void handleTap(BuildContext context);
  bool get isEnabled;
  bool get isLoading;
  bool get checkLogin;

  factory ButtonBehavior.tap({
    bool isEnabled = true,
    bool isLoading = false,
    bool checkLogin = false,
    VoidCallback? onTap,
  }) {
    return TapBehavior(
      isEnabled: isEnabled,
      isLoading: isLoading,
      checkLogin: checkLogin,
      onTap: onTap,
    );
  }

  factory ButtonBehavior.confirm({
    bool isEnabled = true,
    bool isLoading = false,
    bool checkLogin = false,
    required VoidCallback onConfirm,
    String message = 'Are you sure?',
  }) {
    return ConfirmBehavior(
      isEnabled: isEnabled,
      isLoading: isLoading,
      onConfirm: onConfirm,
      checkLogin: checkLogin,
      message: message,
    );
  }

}

class TapBehavior implements ButtonBehavior {
  @override
  final bool isEnabled;
  @override
  final bool isLoading;
  final VoidCallback? onTap;
  @override
  final bool checkLogin;
  const TapBehavior({
    this.isEnabled = true,
    this.isLoading = false,
    this.checkLogin = false,
    this.onTap,
  }) : assert(onTap != null || !isEnabled, 'onTap must be provided if enabled');


  @override
  void handleTap(BuildContext context) {
    // if (isEnabled && !isLoading) onTap?.call();
    if (!isEnabled || isLoading) return;
    // if (checkLogin && AppConfig.isGuestUser) {
    //   CheckLoginView.show();
    //   return;
    // }
    onTap?.call();
  }
}


class ConfirmBehavior implements ButtonBehavior {
  @override
  final bool isEnabled;
  @override
  final bool isLoading;
  final VoidCallback onConfirm;
  final String message;
  @override
  final bool checkLogin;

  const ConfirmBehavior({
    this.isEnabled = true,
    this.isLoading = false,
    this.checkLogin = false,
    required this.onConfirm,
    this.message = 'Are you sure?',
  });

  @override
  void handleTap(BuildContext context) {
    if (!isEnabled || isLoading) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
