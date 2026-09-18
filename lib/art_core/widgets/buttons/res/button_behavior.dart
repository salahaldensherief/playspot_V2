import 'package:flutter/material.dart';

/// Strategy Pattern interface for Button interaction behaviors.
/// Encapsulates different tap policies (direct tap, confirmation dialog, debounced double-click protection).
abstract class ButtonBehavior {
  void handleTap(BuildContext context);
  bool get isEnabled;
  bool get isLoading;
  bool get checkLogin;

  /// Factory constructor for direct tap strategy
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

  /// Factory constructor for confirmation dialog strategy
  factory ButtonBehavior.confirm({
    bool isEnabled = true,
    bool isLoading = false,
    bool checkLogin = false,
    required VoidCallback onConfirm,
    String message = 'Are you sure?',
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) {
    return ConfirmBehavior(
      isEnabled: isEnabled,
      isLoading: isLoading,
      onConfirm: onConfirm,
      checkLogin: checkLogin,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }

  /// Factory constructor for debounced tap strategy (prevents rapid double-clicks)
  factory ButtonBehavior.debounced({
    bool isEnabled = true,
    bool isLoading = false,
    bool checkLogin = false,
    required VoidCallback onTap,
    Duration debounceDuration = const Duration(milliseconds: 500),
  }) {
    return DebouncedTapBehavior(
      isEnabled: isEnabled,
      isLoading: isLoading,
      checkLogin: checkLogin,
      onTap: onTap,
      debounceDuration: debounceDuration,
    );
  }
}

/// Standard direct tap strategy implementation
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
    if (!isEnabled || isLoading) return;
    onTap?.call();
  }
}

/// Confirmation dialog strategy before triggering action
class ConfirmBehavior implements ButtonBehavior {
  @override
  final bool isEnabled;
  @override
  final bool isLoading;
  final VoidCallback onConfirm;
  final String message;
  final String confirmText;
  final String cancelText;
  @override
  final bool checkLogin;

  const ConfirmBehavior({
    this.isEnabled = true,
    this.isLoading = false,
    this.checkLogin = false,
    required this.onConfirm,
    this.message = 'Are you sure?',
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
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
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

/// Debounced tap strategy to prevent accidental double taps (Performance Optimization)
class DebouncedTapBehavior implements ButtonBehavior {
  @override
  final bool isEnabled;
  @override
  final bool isLoading;
  final VoidCallback onTap;
  final Duration debounceDuration;
  @override
  final bool checkLogin;

  static DateTime? _lastTapTime;

  const DebouncedTapBehavior({
    this.isEnabled = true,
    this.isLoading = false,
    this.checkLogin = false,
    required this.onTap,
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  @override
  void handleTap(BuildContext context) {
    if (!isEnabled || isLoading) return;

    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) < debounceDuration) {
      return; // Suppress rapid click
    }
    _lastTapTime = now;
    onTap();
  }
}
