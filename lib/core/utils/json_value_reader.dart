class JsonValueReader {
  static String? firstNonBlank(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null &&
          value.isNotEmpty &&
          value != 'null' &&
          value != 'undefined') {
        return value;
      }
    }
    return null;
  }
}
