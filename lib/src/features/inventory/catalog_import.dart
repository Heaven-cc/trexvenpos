import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// A reviewed CSV import. Barcodes remain text, including leading zeroes.
class CatalogImport {
  static const _aliases = <String, String>{
    'product_name': 'name',
    'product_names': 'name',
    'names': 'name',
    'item': 'name',
    'item_name': 'name',
    'product': 'name',
    'product_title': 'name',
    'item_description': 'description',
    'product_description': 'description',
    'brand_name': 'brand',
    'part_number': 'sku',
    'part_no': 'sku',
    'product_code': 'sku',
    'item_code': 'sku',
    'stock_keeping_unit': 'sku',
    'bar_code': 'barcode',
    'barcode_number': 'barcode',
    'product_barcode': 'barcode',
    'price': 'selling_price',
    'sale_price': 'selling_price',
    'sales_price': 'selling_price',
    'retail_price': 'selling_price',
    'sellingprice': 'selling_price',
    'qty': 'initial_quantity',
    'quantity': 'initial_quantity',
    'stock': 'initial_quantity',
    'stock_quantity': 'initial_quantity',
    'opening_stock': 'initial_quantity',
    'opening_quantity': 'initial_quantity',
    'initial_stock': 'initial_quantity',
    'low_stock': 'low_stock_threshold',
    'reorder_level': 'low_stock_threshold',
    'min_stock': 'low_stock_threshold',
    'minimum_stock': 'low_stock_threshold',
    'measurement_unit': 'unit',
    'unit_of_measure': 'unit',
    'uom': 'unit',
    'image': 'image_url',
    'image_link': 'image_url',
    'product_image': 'image_url',
    'is_active': 'active',
    'product_group': 'group_name',
    'group': 'group_name',
    'colour': 'color',
    'stock_change': 'stock_delta',
    'stock_change_reason': 'stock_reason',
  };

  static String _header(String value) {
    final normalized = value
        .replaceAll(String.fromCharCode(0xfeff), '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return _aliases[normalized] ?? normalized;
  }

  static bool _isHeader(List<String> values) {
    final headers = values.map(_header).toList();
    return headers.contains('name');
  }

  static List<Map<String, dynamic>> parseExcel(
    List<int> bytes, {
    String? sheetName,
  }) {
    final workbook = Excel.decodeBytes(bytes);
    final candidates = workbook.tables.values.where((sheet) =>
        sheet.rows.any((row) => _isHeader(row
            .map((cell) => switch (cell?.value) {
              TextCellValue v => v.value.toString(),
              null => '',
              final v => v.toString(),
            })
            .toList()))).toList();
    final sheet = sheetName != null
        ? workbook.tables[sheetName]
        : candidates.length == 1
            ? candidates.single
            : null;
    if (sheet == null) {
      if (sheetName != null) {
        throw FormatException('Worksheet "$sheetName" not found.');
      }
      if (candidates.isEmpty) {
        throw const FormatException(
          'No worksheet has a supported product header. Include Product name or Name.',
        );
      }
      throw const FormatException(
        'Multiple product worksheets found. Keep one product worksheet per file.',
      );
    }
    final grid = <List<String>>[];
    List<String>? headers;
    for (final source in sheet.rows) {
      if (source.every((cell) => cell?.value == null)) continue;
      final row = <String>[];
      for (var i = 0; i < source.length; i++) {
        final value = source[i]?.value;
        if (headers != null &&
            i < headers.length &&
            ['barcode', 'sku'].contains(headers[i]) &&
            value != null &&
            value is! TextCellValue) {
          throw const FormatException(
            'Barcode and SKU cells must be text to preserve leading zeroes.',
          );
        }
        row.add(switch (value) {
          null => '',
          TextCellValue() => value.value.toString(),
          IntCellValue() => value.value.toString(),
          DoubleCellValue() => value.value.toString(),
          BoolCellValue() => value.value.toString(),
          _ => throw const FormatException(
            'Formulas and date cells are not product values.',
          ),
        });
      }
      if (headers == null) {
        if (!_isHeader(row)) continue;
        headers = row.map(_header).toList();
      } else {
        while (row.length < headers.length) {
          row.add('');
        }
      }
      grid.add(row);
    }
    return parse(const ListToCsvConverter().convert(grid));
  }

  static const columns = {
    'name',
    'barcode',
    'sku',
    'category',
    'description',
    'brand',
    'image_url',
    'unit',
    'selling_price',
    'low_stock_threshold',
    'initial_quantity',
    'active',
    'group_name',
    'size',
    'color',
    'material',
    'stock_delta',
    'stock_reason',
  };

  static List<Map<String, dynamic>> parse(String text) {
    if (text.startsWith('\ufeff')) text = text.substring(1);
    final cells = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'), eol: '\n');
    if (cells.length < 2) {
      throw const FormatException('Include a header and at least one product.');
    }
    final headers = cells.first.map((v) => _header(v.toString())).toList();
    final duplicates = <String>{};
    final seen = <String>{};
    for (final header in headers) {
      if (!seen.add(header)) duplicates.add(header);
    }
    if (duplicates.isNotEmpty) {
      throw FormatException(
        'Duplicate product columns: ${duplicates.join(', ')}. Keep only one of each.',
      );
    }
    if (!headers.contains('name')) {
      throw const FormatException(
        'Missing product name column. Use Name, Product name, or Names.',
      );
    }
    final unsupported = headers.where((h) => !columns.contains(h)).toList();
    if (unsupported.isNotEmpty) {
      throw FormatException(
        'Unsupported columns: ${unsupported.join(', ')}. '
        'Supported: ${columns.join(', ')}.',
      );
    }
    final rows = <Map<String, dynamic>>[];
    final barcodes = <String>{};
    final skus = <String>{};
    for (var i = 1; i < cells.length; i++) {
      if (cells[i].every((v) => v.toString().trim().isEmpty)) continue;
      if (cells[i].length != headers.length) {
        throw FormatException('Row ${i + 1}: column count differs.');
      }
      final row = <String, dynamic>{};
      for (var c = 0; c < headers.length; c++) {
        final key = headers[c];
        final value = cells[i][c].toString().trim();
        if (value.isEmpty) continue;
        if ([
          'selling_price',
          'low_stock_threshold',
          'initial_quantity',
          'stock_delta',
        ].contains(key)) {
          final number = num.tryParse(value);
          if (number == null ||
              !number.isFinite ||
              (number < 0 && key != 'stock_delta') ||
              (number * 1000 - (number * 1000).round()).abs() > 0.0000001) {
            throw FormatException('Row ${i + 1}: invalid $key.');
          }
          if (key == 'selling_price' &&
              (number * 100 - (number * 100).round()).abs() > 0.0000001) {
            throw FormatException(
              'Row ${i + 1}: price supports two decimal places.',
            );
          }
          row[key] = number;
        } else if (key == 'active') {
          if (!['true', 'false'].contains(value.toLowerCase())) {
            throw FormatException(
              'Row ${i + 1}: active must be true or false.',
            );
          }
          row[key] = value.toLowerCase() == 'true';
        } else {
          row[key] = value;
        }
      }
      if ((row['name'] ?? '').toString().isEmpty) {
        throw FormatException('Row ${i + 1}: name is required.');
      }
      for (final key in ['barcode', 'sku']) {
        final value = row[key] as String?;
        if (value != null && !(key == 'barcode' ? barcodes : skus).add(value)) {
          throw FormatException('Row ${i + 1}: duplicate $key.');
        }
      }
      if (!const {
        'piece',
        'kg',
        'g',
        'litre',
        'ml',
        'metre',
        'cm',
      }.contains(row['unit'] ?? 'piece')) {
        throw FormatException('Row ${i + 1}: unsupported unit.');
      }
      if (!const {
            'kg',
            'g',
            'litre',
            'ml',
            'metre',
            'cm',
          }.contains(row['unit'] ?? 'piece') &&
          (row['initial_quantity'] as num? ?? 0) % 1 != 0) {
        throw FormatException('Row ${i + 1}: pieces require whole quantities.');
      }
      if (row.containsKey('stock_delta') &&
          row['stock_delta'] != 0 &&
          (row['stock_reason'] ?? '').toString().trim().isEmpty) {
        throw FormatException('Row ${i + 1}: stock change requires a reason.');
      }
      rows.add(row);
    }
    if (rows.isEmpty) throw const FormatException('No product rows found.');
    return rows;
  }
}
