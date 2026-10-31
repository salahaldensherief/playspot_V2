/// Matches a reverse-geocoded address to the exact city value accepted by
/// the lounge discovery RPC. An unmatched address leaves discovery unfiltered.
class HomeCityMatcher {
  const HomeCityMatcher._();

  static const _aliases = <String, List<String>>{
    'alexandria': ['الاسكندريه', 'اسكندريه', 'alexandria'],
    'cairo': ['القاهره', 'قاهره', 'cairo'],
    'giza': ['الجيزه', 'جيزه', 'giza'],
    'mansoura': ['المنصوره', 'منصوره', 'mansoura'],
    'al hamul': ['الحامول', 'hamul', 'al hamul'],
  };

  static String? match(String address, Iterable<String> availableCities) {
    final cities = availableCities.where((city) => city.trim().isNotEmpty);
    final parts = address.split(RegExp(r'[,،]')).reversed;
    for (final part in parts) {
      final place = _normalize(part);
      if (place.isEmpty) continue;
      for (final city in cities) {
        final cityName = _normalize(city);
        final names = {cityName, ...?_aliases[cityName]};
        if (names.any(
          (name) =>
              place == name ||
              place.startsWith('$name ') ||
              place.endsWith(' $name'),
        )) {
          return city;
        }
      }
    }
    return null;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\bgovernorate\b|محافظه'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
