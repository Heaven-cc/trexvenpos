import 'dart:typed_data';
import 'dart:convert';
import 'catalog_import.dart';
import 'package:pdfx/pdfx.dart';
import 'angel_scan_client.dart';

/// Stages the entire PDF before returning. A failed page never leaves a partial import.
class AngelDocumentReader {
  static Future<Map<String, dynamic>> readSpreadsheet(
    AngelScanClient api,
    Uint8List bytes,
    String name,
  ) async {
    if (!api.inventoryMode) {
      throw StateError('Inventory import access required.');
    }
    if (bytes.isEmpty || bytes.length > 20000000) {
      throw StateError('Choose a file smaller than 20 MB.');
    }
    final excel = name.toLowerCase().endsWith('.xlsx');
    final rows = excel
        ? CatalogImport.parseExcel(bytes)
        : CatalogImport.parse(utf8.decode(bytes));
    if (rows.length > 500) {
      throw StateError('Review up to 500 products at a time.');
    }
    final items = rows
        .map(
          (row) => <String, dynamic>{
            for (final key in [
              'name',
              'brand',
              'sku',
              'barcode',
              'category',
              'unit',
              'selling_price',
            ])
              if (row[key] != null) key: row[key],
            'quantity': row['initial_quantity'] ?? row['stock_delta'],
            'uncertain': false,
          },
        )
        .toList();
    return {
      'items': await api.matchItems(items),
      'type': 'document',
      'source_label': excel ? 'Excel imported' : 'CSV imported',
      'source_name': name,
      'document_hash': await AngelScanClient.fingerprint(bytes),
    };
  }

  static Future<Map<String, dynamic>> readPdf(
    AngelScanClient api,
    Uint8List bytes, {
    bool Function()? contextIsCurrent,
    void Function(int page, int total)? onProgress,
  }) async {
    if (!api.inventoryMode) {
      throw StateError('PDF import requires inventory access.');
    }
    if (bytes.isEmpty || bytes.length > 20000000) {
      throw StateError('Choose a PDF smaller than 20 MB.');
    }
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw StateError('This file is not a valid PDF.');
    }
    void check() {
      api.checkSession();
      if (contextIsCurrent?.call() == false) {
        throw StateError('Business or branch changed. Reopen the import.');
      }
    }

    check();
    final pdf = await PdfDocument.openData(bytes);
    final items = <Map<String, dynamic>>[];
    final documents = <Map<String, dynamic>>[];
    try {
      if (pdf.pagesCount < 1 || pdf.pagesCount > 20) {
        throw StateError('Choose a PDF with 1 to 20 pages.');
      }
      for (var n = 1; n <= pdf.pagesCount; n++) {
        check();
        onProgress?.call(n, pdf.pagesCount);
        final page = await pdf.getPage(n);
        try {
          if (page.width <= 0 || page.height <= 0) {
            throw StateError('Invalid PDF page.');
          }
          final ratio =
              2200 / (page.width > page.height ? page.width : page.height);
          final image = await page.render(
            width: page.width * ratio,
            height: page.height * ratio,
            format: PdfPageImageFormat.jpeg,
            quality: 88,
            backgroundColor: '#FFFFFF',
          );
          if (image == null) throw StateError('Page $n could not be read.');
          final result = await api.recognize(image.bytes, document: true);
          check();
          items.addAll(
            (result['items'] as List).map(
              (i) => Map<String, dynamic>.from(i as Map),
            ),
          );
          if (items.length > 500) {
            throw StateError('Review up to 500 product lines at a time.');
          }
          documents.add({
            'supplier': result['supplier'],
            'document_number': result['document_number'],
          });
        } finally {
          await page.close();
        }
      }
      if (items.isEmpty) {
        throw StateError('No product lines found in this PDF.');
      }
      return {
        'items': items,
        'documents': documents,
        'document_hash': await AngelScanClient.fingerprint(bytes),
        'type': 'document',
        'source_label': 'PDF imported',
      };
    } finally {
      await pdf.close();
    }
  }
}
