class VersionUtils {
  VersionUtils._();

  /// Compares [currentVersion] with [targetVersion].
  /// Returns -1 if current < target
  /// Returns 0 if current == target
  /// Returns 1 if current > target
  static int compare(String currentVersion, String targetVersion) {
    try {
      final v1 = _parseVersion(currentVersion);
      final v2 = _parseVersion(targetVersion);

      for (var i = 0; i < 3; i++) {
        if (v1[i] < v2[i]) return -1;
        if (v1[i] > v2[i]) return 1;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static bool isLowerThan(String currentVersion, String targetVersion) {
    return compare(currentVersion, targetVersion) < 0;
  }

  static List<int> _parseVersion(String version) {
    final clean = version.split('+').first.split('-').first.trim();
    final parts = clean.split('.');
    final major = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final patch = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return [major, minor, patch];
  }
}
