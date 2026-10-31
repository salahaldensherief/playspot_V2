class BookingItemsDecoder {
  static List<Map<String, dynamic>> decode(Map<String, dynamic> json) {
    final bookingItems = json['items'] ?? json['booking_items'];
    final orders = json['canteen_orders'];
    return [
      if (bookingItems is List)
        for (final item in bookingItems.whereType<Map>()) _item(item),
      if (orders is List)
        for (final order in orders.whereType<Map>())
          for (final item in _orderItems(order)) _item(item),
    ];
  }

  static Iterable<Map> _orderItems(Map order) {
    final items = order['items'] ?? order['canteen_order_items'];
    return items is List ? items.whereType<Map>() : const [];
  }

  static Map<String, dynamic> _item(Map item) {
    final extra = item['extras'] is Map ? item['extras'] as Map : const {};
    final name =
        item['name_ar'] ??
        item['name_en'] ??
        item['name'] ??
        item['product_name'] ??
        item['extra_name'] ??
        extra['name_ar'] ??
        extra['name_en'] ??
        extra['name'] ??
        item['item_name'] ??
        item['title'];
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final total = ((item['total_price'] ?? item['total']) as num?)?.toDouble();
    var unitPrice =
        ((item['unit_price'] ?? item['price'] ?? extra['price']) as num?)
            ?.toDouble() ??
        0;
    if (unitPrice == 0 && total != null && total > 0) {
      unitPrice = total / (quantity > 0 ? quantity : 1);
    }
    return {
      'id':
          (item['extra_id'] ??
                  item['id'] ??
                  item['addon_id'] ??
                  item['product_id'] ??
                  extra['id'] ??
                  '')
              .toString(),
      'name': name?.toString().trim() ?? '',
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': total ?? unitPrice * quantity,
    };
  }
}
