import 'package:flutter/material.dart';

class LoungeHelper {
  static IconData getIconFromKey(String key) {
    switch (key.toLowerCase()) {
      case 'sports_esports':
      case 'ps5':
      case 'ps4':
      case 'xbox':
        return Icons.sports_esports_outlined;
      case 'computer':
      case 'pc':
        return Icons.computer_outlined;
      case 'view_in_ar':
      case 'vr':
        return Icons.view_in_ar_outlined;
      case 'sports_motorsports':
      case 'simulator':
        return Icons.sports_motorsports_outlined;
      case 'fastfood':
      case 'food':
        return Icons.fastfood_outlined;
      default:
        return Icons.videogame_asset_outlined;
    }
  }
}
