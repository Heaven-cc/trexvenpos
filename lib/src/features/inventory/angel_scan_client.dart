import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AngelScanClient {
  final SupabaseClient client;
  final String businessId;
  final String? branchId;
  final bool inventoryMode;
  final String? _user;
  AngelScanClient(
    this.client, {
    required this.businessId,
    this.branchId,
    required this.inventoryMode,
  }) : _user = client.auth.currentUser?.id;

  void checkSession() {
    if (_user == null || client.auth.currentUser?.id != _user) {
      throw StateError('Your account changed. Reopen Angel Scan.');
    }
  }

  static Future<String> fingerprint(List<int> bytes) async =>
      (await Sha256().hash(
        bytes,
      )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  static String imageType(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216) {
      return 'image/jpeg';
    }
    if (bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80) {
      return 'image/png';
    }
    if (bytes.length > 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    throw StateError('Use a JPEG, PNG or WebP image.');
  }

  Future<Map<String, dynamic>> recognize(
    Uint8List bytes, {
    bool document = false,
    bool autoDetect = false,
    bool research = false,
  }) async {
    checkSession();
    if (bytes.isEmpty || bytes.length > 4000000) {
      throw StateError('Choose an image smaller than 4 MB.');
    }
    final response = await client.functions.invoke(
      'angel-scan',
      body: {
        'business_id': businessId,
        'branch_id': branchId,
        'purpose': inventoryMode ? 'inventory' : 'sale',
        'document': document,
        'auto_detect': autoDetect,
        'research': research,
        'mime_type': imageType(bytes),
        'image_base64': base64Encode(bytes),
      },
    );
    checkSession();
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['success'] != true) {
      throw StateError(
        'Angel Scan could not finish. Check your connection and current access.',
      );
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> researchProduct(
    Map<String, dynamic> item,
  ) async {
    checkSession();
    final response = await client.functions.invoke(
      'angel-scan',
      body: {
        'business_id': businessId,
        'branch_id': branchId,
        'purpose': inventoryMode ? 'inventory' : 'sale',
        'action': 'research',
        'item': {
          for (final key in ['name', 'brand', 'sku', 'barcode']) key: item[key],
        },
      },
    );
    checkSession();
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['success'] != true) {
      throw StateError('Public research is unavailable. Try again later.');
    }
    return Map<String, dynamic>.from(response.data['research'] as Map);
  }

  Future<List<Map<String, dynamic>>> matchItems(
    List<Map<String, dynamic>> items,
  ) async {
    checkSession();
    final matched = <Map<String, dynamic>>[];
    for (var offset = 0; offset < items.length; offset += 80) {
      final end = offset + 80 < items.length ? offset + 80 : items.length;
      final result = await client.rpc(
        'match_angel_scan_items',
        params: {
          'p_business_id': businessId,
          'p_branch_id': branchId,
          'p_purpose': inventoryMode ? 'inventory' : 'sale',
          'p_items': items.sublist(offset, end),
        },
      );
      checkSession();
      matched.addAll(
        (result as List).map((i) => Map<String, dynamic>.from(i as Map)),
      );
    }
    return matched;
  }

  Future<List<Map<String, dynamic>>> search(String name) async {
    checkSession();
    final result = await client.rpc(
      'match_angel_scan_items',
      params: {
        'p_business_id': businessId,
        'p_branch_id': branchId,
        'p_purpose': inventoryMode ? 'inventory' : 'sale',
        'p_items': [
          {'name': name, 'sku': name, 'barcode': name},
        ],
      },
    );
    checkSession();
    final items = result as List;
    return items.isEmpty
        ? []
        : (items.first['matches'] as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();
  }

  Future<Map<String, dynamic>> submit({
    required String requestId,
    required String documentHash,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> metadata,
  }) async {
    checkSession();
    final result = await client.rpc(
      'submit_angel_inventory_approval',
      params: {
        'p_business_id': businessId,
        'p_branch_id': branchId,
        'p_request_id': requestId,
        'p_document_hash': documentHash,
        'p_items': items,
        'p_document_metadata': metadata,
      },
    );
    checkSession();
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> decide(String requestId, bool approve) async {
    checkSession();
    final result = await client.rpc(
      'decide_angel_inventory_approval',
      params: {
        'p_business_id': businessId,
        'p_request_id': requestId,
        'p_approve': approve,
      },
    );
    checkSession();
    return Map<String, dynamic>.from(result as Map);
  }
}
