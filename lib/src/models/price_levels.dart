class PriceLevels {
  final String? id;
  final String? productId;

  final double budget;
  final double standard;
  final double premium;
  final double market;

  final String? marketContext;

  const PriceLevels({
    this.id,
    this.productId,
    required this.budget,
    required this.standard,
    required this.premium,
    required this.market,
    this.marketContext,
  });

  factory PriceLevels.fromJson(
      Map<String, dynamic> json,
      ) {
    return PriceLevels(
      id: _nullableString(json['id']),
      productId: _nullableString(
        json['product_id'],
      ),
      budget: _toDouble(json['budget']),
      standard: _toDouble(json['standard']),
      premium: _toDouble(json['premium']),
      market: _toDouble(json['market']),
      marketContext: _nullableString(
        json['market_context'],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;

    final string = value.toString().trim();

    return string.isEmpty ? null : string;
  }

  PriceLevels copyWith({
    String? id,
    String? productId,
    double? budget,
    double? standard,
    double? premium,
    double? market,
    String? marketContext,
  }) {
    return PriceLevels(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      budget: budget ?? this.budget,
      standard: standard ?? this.standard,
      premium: premium ?? this.premium,
      market: market ?? this.market,
      marketContext:
      marketContext ?? this.marketContext,
    );
  }

  double get lowestPrice {
    return [
      budget,
      standard,
      premium,
      market,
    ].reduce(
          (a, b) => a < b ? a : b,
    );
  }

  double get highestPrice {
    return [
      budget,
      standard,
      premium,
      market,
    ].reduce(
          (a, b) => a > b ? a : b,
    );
  }

  double priceFor(String level) {
    switch (level.toLowerCase()) {
      case 'budget':
        return budget;

      case 'standard':
        return standard;

      case 'premium':
        return premium;

      case 'market':
        return market;

      default:
        return standard;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (productId != null)
        'product_id': productId,
      'budget': budget,
      'standard': standard,
      'premium': premium,
      'market': market,
      'market_context': marketContext,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PriceLevels &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            productId == other.productId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
  );
}