class StockCountBatch {
  final Map<String, Map<String, dynamic>> lines = {};
  Map<String, dynamic> resolve(
    String barcode,
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> counts,
  ) {
    final matches = products
        .where((p) => p['barcode'] == barcode.trim())
        .toList();
    if (matches.length != 1)
      throw StateError('Barcode is missing or ambiguous.');
    final count = counts
        .where((c) => c['product_id'] == matches.single['id'])
        .toList();
    if (count.length != 1)
      throw StateError('Product is not in this count session.');
    return {...count.single, 'name': matches.single['name']};
  }

  void set(Map<String, dynamic> count, String input, {bool add = false}) {
    if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(input.trim())) {
      throw const FormatException(
        'Enter a nonnegative quantity with at most three decimal places.',
      );
    }
    final quantity = num.parse(input.trim());
    if (!quantity.isFinite)
      throw const FormatException('Quantity must be finite.');
    final id = count['product_id'] as String;
    final existing = lines[id];
    lines[id] = {
      'product_id': id,
      'version': count['version'],
      'quantity': add && existing != null
          ? (((existing['quantity'] as num) * 1000).round() +
                    (quantity * 1000).round()) /
                1000
          : quantity,
    };
  }
}
