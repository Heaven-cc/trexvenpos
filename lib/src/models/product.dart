enum ProductStatus {
  active,
  pending,
  inactive,
}

class Product {
  final String id;
  final String name;
  final String? barcode;
  final String? partNumber;
  final String? brand;
  final String? category;
  final String? imageUrl;
  final ProductStatus status;
  final String businessId;
  final num stock;
  final num lowStockThreshold;
  final String? description;
  final double? sellingPrice;
  final String unit;
  final String? catalogGroupId;
  final Map<String,dynamic> variantAttributes;

  const Product({
    required this.id,
    required this.name,
    this.barcode,
    this.partNumber,
    this.brand,
    this.category,
    this.imageUrl,
    this.status = ProductStatus.pending,
    required this.businessId,
    this.stock = 0,this.lowStockThreshold = 5,this.description,this.sellingPrice, this.unit = 'piece', this.catalogGroupId, this.variantAttributes = const {},
  });

  factory Product.fromJson(
      Map<String, dynamic> json,
      ) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      barcode: _nullableString(json['barcode']),
      partNumber: _nullableString(
        json['sku'],
      ),
      brand: _nullableString(json['brand']),
      category: _nullableString(
        json['category'],
      ),
      imageUrl: _nullableString(
        json['image_url'],
      ),
      stock:(json['quantity'] as num?) ?? 0,lowStockThreshold:(json['low_stock_threshold'] as num?) ?? 5,description:json['description'],
      sellingPrice:(json['selling_price'] as num?)?.toDouble(),
      unit: json['unit'] ?? 'piece', catalogGroupId: json['catalog_group_id'],
      variantAttributes: Map<String,dynamic>.from(json['variant_attributes'] ?? {}),
      status: (json.containsKey('selling_price') && json['selling_price'] == null)
          ? ProductStatus.pending : (json['is_active'] == false || json['active'] == false)
          ? ProductStatus.inactive : ProductStatus.active,
      businessId:
      json['business_id']?.toString() ?? '',
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;

    final string = value.toString().trim();

    return string.isEmpty ? null : string;
  }

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    String? partNumber,
    String? brand,
    String? category,
    String? imageUrl,
    ProductStatus? status,
    String? businessId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      partNumber: partNumber ?? this.partNumber,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      businessId: businessId ?? this.businessId,
      stock:stock,lowStockThreshold:lowStockThreshold,description:description,sellingPrice:sellingPrice, unit: unit, catalogGroupId: catalogGroupId, variantAttributes: variantAttributes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name.trim(),
      'barcode': barcode,
      'sku': partNumber,
      'brand': brand,
      'category': category,
      'image_url': imageUrl,
      'is_active': status == ProductStatus.active,
      'active': status == ProductStatus.active,
      'business_id': businessId,
      'unit':unit,
      if(catalogGroupId != null) 'catalog_group_id':catalogGroupId,
      if(variantAttributes.isNotEmpty) 'variant_attributes':variantAttributes,
    };
  }

  bool get supportsFractionalQuantity => const {'kg','g','litre','ml','metre','cm'}.contains(unit.trim().toLowerCase());

  bool get isActive =>
      status == ProductStatus.active;

  bool get isPending =>
      status == ProductStatus.pending;

  bool get isInactive =>
      status == ProductStatus.inactive;

  bool get hasBarcode =>
      barcode != null && barcode!.isNotEmpty;

  bool get hasImage =>
      imageUrl != null && imageUrl!.isNotEmpty;

  String get displayBrand {
    return brand?.isNotEmpty == true
        ? brand!
        : 'Unknown Brand';
  }

  String get displayPartNumber {
    return partNumber?.isNotEmpty == true
        ? partNumber!
        : 'No part number';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Product &&
            runtimeType == other.runtimeType &&
            id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
