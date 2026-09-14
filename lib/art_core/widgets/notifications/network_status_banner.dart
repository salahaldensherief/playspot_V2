import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/core/services/network_connectivity_service.dart';

class NetworkStatusWrapper extends StatefulWidget {
  final Widget child;

  const NetworkStatusWrapper({super.key, required this.child});

  @override
  State<NetworkStatusWrapper> createState() => _NetworkStatusWrapperState();
}

class _NetworkStatusWrapperState extends State<NetworkStatusWrapper> {
  bool _wasOffline = false;
  bool _showRestoredBanner = false;
  Timer? _restoredTimer;

  @override
  void initState() {
    super.initState();
    NetworkConnectivityService().isConnectedNotifier.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    NetworkConnectivityService().isConnectedNotifier.removeListener(_onConnectivityChanged);
    _restoredTimer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged() {
    final isConnected = NetworkConnectivityService().isConnectedNotifier.value;
    if (!isConnected) {
      setState(() {
        _wasOffline = true;
        _showRestoredBanner = false;
      });
      _restoredTimer?.cancel();
    } else if (_wasOffline) {
      setState(() {
        _wasOffline = false;
        _showRestoredBanner = true;
      });
      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showRestoredBanner = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkConnectivityService().isConnectedNotifier,
      builder: (context, isConnected, _) {
        final isOffline = !isConnected;
        final showBanner = isOffline || _showRestoredBanner;

        return Stack(
          children: [
            widget.child,
            if (showBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  elevation: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 6.h,
                      bottom: 8.h,
                      left: 16.w,
                      right: 16.w,
                    ),
                    decoration: BoxDecoration(
                      color: isOffline
                          ? AppColors.danger.withOpacity(0.92)
                          : AppColors.success.withOpacity(0.92),
                      boxShadow: [
                        BoxShadow(
                          color: (isOffline ? AppColors.danger : AppColors.success).withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOffline ? TablerIcons.wifi_off : TablerIcons.wifi,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          isOffline
                              ? 'noInternetConnection'.tr()
                              : 'internetRestored'.tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
