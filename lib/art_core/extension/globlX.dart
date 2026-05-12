// part of 'extensions.dart';

extension GlopalX on dynamic {
  bool get isNotNullOrEmptyX {
    if (this == null) return false;
    if (this == "Null" || this == "null") return false;
    if (this is String) return (this as String).isNotEmpty;
    if (this is List) return (this as List).isNotEmpty;
    if (this is Map) return (this as Map).isNotEmpty;

    return true;
  }

  bool get isValidMap {
    return this != null && this is Map && (this as Map).isNotEmpty;
  }
}
