class Business {
  final String id;
  final String ownerId;
  final String name;
  final bool branchesEnabled;

  final String? businessType;
  final String? address;
  final String? phone;
  final String? country;
  final String? currency;
  final String? logoUrl;

  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    this.branchesEnabled = false,
    this.businessType,
    this.address,
    this.phone,
    this.country,
    this.currency,
    this.logoUrl,
  });

  factory Business.fromJson(
      Map<String, dynamic> json,
      ) {
    return Business(
      id: json['id']?.toString() ?? '',
      branchesEnabled: json['branches_enabled'] == true,
      ownerId:
      json['owner_id']?.toString() ?? '',
      name:
      json['business_name']?.toString() ?? '',
      businessType: _nullableString(
        json['business_type'],
      ),
      address: _nullableString(
        json['address'],
      ),
      phone: _nullableString(
        json['phone'],
      ),
      country: _nullableString(
        json['country'],
      ),
      currency: _nullableString(
        json['currency'],
      ),
      logoUrl: _nullableString(
        json['logo_url'],
      ),
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;

    final string = value.toString().trim();

    return string.isEmpty ? null : string;
  }

  Business copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? businessType,
    String? address,
    String? phone,
    String? country,
    String? currency,
    String? logoUrl,
  }) {
    return Business(
      id: id ?? this.id,
      branchesEnabled: branchesEnabled,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      businessType:
      businessType ?? this.businessType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      currency: currency ?? this.currency,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (branchesEnabled) 'branches_enabled': true,
      'owner_id': ownerId,
      'business_name': name.trim(),
      'business_type': businessType,
      'address': address,
      'phone': phone,
      'country': country,
      'currency': currency,
      'logo_url': logoUrl,
    };
  }

  String get displayCurrency {
    if (currency == null || currency!.isEmpty) {
      return 'NGN';
    }

    return currency!;
  }

  bool get hasLogo =>
      logoUrl != null && logoUrl!.isNotEmpty;

  bool get hasAddress =>
      address != null && address!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Business &&
            runtimeType == other.runtimeType &&
            id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
