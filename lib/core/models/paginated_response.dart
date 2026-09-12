import 'package:equatable/equatable.dart';

/// Represents a standardized paginated RPC response from Supabase.
///
/// Each item returned by the RPC is expected to contain:
/// - `data`: JSON object containing the actual record fields
/// - `total_count`: Total number of matching items in the database
/// - `page`: Requested page number (1-indexed)
/// - `page_size`: Requested page size (default 20, max 100)
class PaginatedResponse<T> extends Equatable {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const PaginatedResponse({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => page * pageSize < totalCount;

  factory PaginatedResponse.fromRpc({
    required dynamic response,
    required T Function(Map<String, dynamic> json) fromJson,
    int requestedPage = 1,
    int requestedPageSize = 20,
  }) {
    if (response is! List || response.isEmpty) {
      return PaginatedResponse(
        items: const [],
        totalCount: 0,
        page: requestedPage,
        pageSize: requestedPageSize,
      );
    }

    final List list = response;
    final firstRow = Map<String, dynamic>.from(list.first as Map);

    final totalCount = (firstRow['total_count'] as num?)?.toInt() ?? 0;
    final page = (firstRow['page'] as num?)?.toInt() ?? requestedPage;
    final pageSize = (firstRow['page_size'] as num?)?.toInt() ?? requestedPageSize;

    final items = list.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final dataJson = map['data'];
      if (dataJson is Map) {
        return fromJson(Map<String, dynamic>.from(dataJson));
      }
      return fromJson(map);
    }).toList();

    return PaginatedResponse(
      items: items,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  List<Object?> get props => [items, totalCount, page, pageSize];
}
