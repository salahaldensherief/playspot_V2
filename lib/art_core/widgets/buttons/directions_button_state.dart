import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:playspot/core/models/geo_coordinates.dart';
import 'package:playspot/core/services/directions_service.dart';
import '../notifications/game_hud_toast.dart';
import 'directions_button.dart';
import 'directions_button_content.dart';

class DirectionsButtonState extends State<DirectionsButton> {
  bool _launching = false;

  @override
  Widget build(BuildContext context) => DirectionsButtonContent(
    button: widget,
    launching: _launching,
    onTap: _open,
  );

  Future<void> _open() async {
    if (_launching) return;
    final point = GeoCoordinates.fromPair(widget.lat, widget.lng);
    if (point == null) {
      _error('directions_coordinates_unavailable');
      return;
    }
    setState(() => _launching = true);
    try {
      widget.onBeforeLaunch?.call();
      final success = await GetIt.instance<DirectionsService>().openDirections(
        lat: point.latitude,
        lng: point.longitude,
      );
      if (!success) _error('directions_open_failed');
    } catch (_) {
      _error('directions_open_failed');
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _error(String key) {
    if (mounted) GameHudToast.show(context, key.tr(), type: ToastType.error);
  }
}
