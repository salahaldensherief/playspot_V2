class LoungeDistance {
  static double fromJson(Map<String, dynamic> json) {
    for (final key in [
      'distance_km',
      'distance_in_km',
      'distance',
      'distance_meters',
    ]) {
      if (!json.containsKey(key)) continue;
      final raw = json[key];
      final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (value == null || !value.isFinite || value < 0) return double.infinity;
      return key == 'distance_meters' ? value / 1000 : value;
    }
    return double.infinity;
  }

  static String format(double kilometers, {required bool isArabic}) {
    if (!kilometers.isFinite || kilometers < 0) return '';
    if (kilometers >= 1) {
      return '${kilometers.toStringAsFixed(1)} ${isArabic ? 'كم' : 'km'}';
    }
    return '${(kilometers * 1000).round()} ${isArabic ? 'م' : 'm'}';
  }
}
