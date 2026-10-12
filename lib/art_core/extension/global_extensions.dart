extension StringNullOrEmptyX on String? {
  bool get isNotNullOrEmptyX {
    if (this == null) return false;
    if (this == "Null" || this == "null") return false;
    return this!.trim().isNotEmpty;
  }
}

extension ListNullOrEmptyX<T> on List<T>? {
  bool get isNotNullOrEmptyX {
    return this != null && this!.isNotEmpty;
  }
}

extension MapNullOrEmptyX<K, V> on Map<K, V>? {
  bool get isNotNullOrEmptyX {
    return this != null && this!.isNotEmpty;
  }

  bool get isValidMap => isNotNullOrEmptyX;
}

extension IterableFirstWhereOrNullX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
