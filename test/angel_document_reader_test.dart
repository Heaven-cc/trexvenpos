import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/src/features/inventory/angel_scan_client.dart';
import '../lib/src/features/inventory/angel_document_reader.dart';

class MatchingScan extends AngelScanClient {
  MatchingScan({bool inventory = true})
    : super(
        SupabaseClient(
          'https://example.test',
          'key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        businessId: 'business',
        inventoryMode: inventory,
      );
  @override
  void checkSession() {}
  @override
  Future<List<Map<String, dynamic>>> matchItems(
    List<Map<String, dynamic>> items,
  ) async => items;
}

void main() {
  test(
    'PDF rejects selling access, invalid signatures and oversized documents before opening native PDF',
    () async {
      await expectLater(
        AngelDocumentReader.readPdf(
          MatchingScan(inventory: false),
          Uint8List.fromList(utf8.encode('%PDF-1.4')),
        ),
        throwsStateError,
      );
      await expectLater(
        AngelDocumentReader.readPdf(
          MatchingScan(),
          Uint8List.fromList([1, 2, 3]),
        ),
        throwsStateError,
      );
      await expectLater(
        AngelDocumentReader.readPdf(MatchingScan(), Uint8List(20000001)),
        throwsStateError,
      );
    },
  );
  test(
    'spreadsheet file adapter preserves identifiers, quantity, source and rejects unsupported columns',
    () async {
      final bytes = Uint8List.fromList(
        utf8.encode('Name,SKU,Barcode,Initial quantity\nBolt,0001,000123,4'),
      );
      final result = await AngelDocumentReader.readSpreadsheet(
        MatchingScan(),
        bytes,
        'stock.csv',
      );
      final row = (result['items'] as List).single as Map;
      expect(row['sku'], '0001');
      expect(row['barcode'], '000123');
      expect(row['quantity'], 4);
      expect(result['type'], 'document');
      expect(result['source_label'], 'CSV imported');
      expect(result['document_hash'], hasLength(64));
      await expectLater(
        AngelDocumentReader.readSpreadsheet(
          MatchingScan(),
          Uint8List.fromList(utf8.encode('Name,Unsupported\nBolt,4')),
          'stock.csv',
        ),
        throwsFormatException,
      );
    },
  );
}
