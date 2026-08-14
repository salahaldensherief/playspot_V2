/// Parameters for fetching lounges from the repository
class GetLoungesParams {
  final double? lat;
  final double? lng;
  final String? city;
  final List<String>? categoryIds;
  final String sortType;
  final int limit;
  final int offset;

  GetLoungesParams({
    this.lat,
    this.lng,
    this.city,
    this.categoryIds,
    this.sortType = 'nearest',
    this.limit = 20,
    this.offset = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'p_lat': lat,
      'p_lng': lng,
      'p_city': city,
      'p_category_ids': categoryIds,
      'p_sort_type': sortType,
      'p_limit': limit,
      'p_offset': offset,
    };
  }
}
