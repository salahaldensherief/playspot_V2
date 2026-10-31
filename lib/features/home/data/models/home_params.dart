import 'package:equatable/equatable.dart';
import 'package:playspot/core/models/geo_coordinates.dart';

class GetLoungesParams extends Equatable {
  final double? lat;
  final double? lng;
  final String? city;
  final String? searchQuery;
  final List<String>? categoryIds;
  final String sortType;
  final bool isOpenOnly;
  final int limit;
  final int offset;

  const GetLoungesParams({
    this.lat,
    this.lng,
    this.city,
    this.searchQuery,
    this.categoryIds,
    this.sortType = 'nearest',
    this.isOpenOnly = false,
    this.limit = 20,
    this.offset = 0,
  });

  Map<String, dynamic> toJson() {
    final point = GeoCoordinates.fromPair(lat, lng);
    return {
      'p_lat': point?.latitude,
      'p_lng': point?.longitude,
      'p_city': city,
      'p_search_query': searchQuery,
      'p_category_ids': categoryIds,
      'p_sort_type': sortType,
      'p_is_open_only': isOpenOnly,
      'p_limit': limit,
      'p_offset': offset,
    };
  }

  @override
  List<Object?> get props => [
    lat,
    lng,
    city,
    searchQuery,
    categoryIds,
    sortType,
    isOpenOnly,
    limit,
    offset,
  ];
}
