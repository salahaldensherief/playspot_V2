import 'package:flutter/material.dart';
import '../assets_manager.dart';

class CategoryHelper {
  static IconData getIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('ps') || lower.contains('console')) {
      return Icons.videogame_asset_outlined;
    }
    if (lower.contains('sim') || lower.contains('racing')) {
      return Icons.speed;
    }
    if (lower.contains('pc') || lower.contains('comput')) {
      return Icons.computer;
    }
    if (lower.contains('vip')) {
      return Icons.star;
    }
    return Icons.category_outlined;
  }

  static String? getSvgPath(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('bill') || lower.contains('pool')) {
      return AssetsManager.billiard;
    }
    if (lower.contains('vr') || lower.contains('virtual')) {
      return AssetsManager.vr;
    }
    return null;
  }
}
