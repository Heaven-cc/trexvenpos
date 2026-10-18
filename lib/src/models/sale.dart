class Sale {
  final String id;
  final String businessId;
  final String? branchId;
  final String employeeId;
  final double total;
  final String paymentMethod;
  final DateTime timestamp;
  final List<SaleItem> items;
  final List<Map<String,dynamic>>? payments;
  final Map<String,dynamic>? credit;
  final String? shiftId;

  const Sale({
    required this.id,
    required this.businessId,
    this.branchId,
    required this.employeeId,
    required this.total,
    required this.paymentMethod,
    required this.timestamp,
    this.items = const [],
    this.payments, this.credit, this.shiftId,
  });

  factory Sale.fromJson(Map<String, dynamic> json, {List<SaleItem>? items}) {
    final rawItems = items ?? _parseItems(json['sale_items'] ?? json['items']);

    return Sale(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      employeeId: json['employee_id']?.toString() ?? '',
      total: _toDouble(json['total']),
      paymentMethod: (json['payment_kind'] ?? json['payment_method'])?.toString() ?? 'cash',
      payments: json['payments'] is List ? (json['payments'] as List).map((p)=>Map<String,dynamic>.from(p as Map)).toList() : null,
      credit: json['credit'] is Map ? Map<String,dynamic>.from(json['credit'] as Map) : null,
      shiftId: json['shift_id']?.toString(),
      timestamp: _toDateTime(json['created_at'] ?? json['sold_at']),
      items: rawItems,
    );
  }

  static List<SaleItem> _parseItems(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) => SaleItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  Sale copyWith({
    String? id,
    String? businessId,
    String? employeeId,
    double? total,
    String? paymentMethod,
    DateTime? timestamp,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      branchId: branchId,
      employeeId: employeeId ?? this.employeeId,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      timestamp: timestamp ?? this.timestamp,
      items: items ?? this.items,
      payments: payments, credit: credit, shiftId: shiftId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      if (branchId != null) 'branch_id': branchId,
      'employee_id': employeeId,
      'total': total,
      'payment_method': paymentMethod,
      if(payments!=null)'payments':payments,
      if(credit!=null)'credit':credit,
      if(shiftId!=null)'shift_id':shiftId,
      'created_at': timestamp.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonWithItems() {
    return {...toJson(), 'items': items.map((item) => item.toJson()).toList()};
  }

  num get itemCount {
    final units = items.fold<int>(0,(sum,item) => sum + (item.quantity * 1000).round());
    return units % 1000 == 0 ? units ~/ 1000 : units / 1000;
  }

  double get subtotal {
    return items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
  }

  double get totalDiscount {
    return items.fold<double>(0.0, (sum, item) => sum + item.discount);
  }

  bool get isEmpty => items.isEmpty;

  bool get hasItems => items.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Sale && runtimeType == other.runtimeType && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

class SaleItem {
  final String productName;
  final String productId;
  final num quantity;
  final double unitPrice;
  final double discount;
  final double total;
  final String priceLevel;

  const SaleItem({
    this.productName = '',
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
    required this.total,
    required this.priceLevel,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productName: json['product_name']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      quantity: _toQuantity(json['quantity']),
      unitPrice: _toDouble(json['unit_price']),
      discount: _toDouble(json['discount']),
      total: _toDouble(json['total']),
      priceLevel: json['price_level']?.toString() ?? 'standard',
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  static num _toQuantity(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value;
    }

    return num.tryParse(value.toString()) ?? 0;
  }

  SaleItem copyWith({
    String? productName,
    String? productId,
    num? quantity,
    double? unitPrice,
    double? discount,
    double? total,
    String? priceLevel,
  }) {
    return SaleItem(
      productName: productName ?? this.productName,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      priceLevel: priceLevel ?? this.priceLevel,
    );
  }

  double get subtotal => quantity * unitPrice;

  double get calculatedTotal {
    return subtotal - discount;
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'total': total,
      'price_level': priceLevel,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SaleItem &&
            runtimeType == other.runtimeType &&
            productId == other.productId &&
            priceLevel == other.priceLevel;
  }

  @override
  int get hashCode => Object.hash(productId, priceLevel);
}
