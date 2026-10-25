import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only Angel Scan recognition. Backend verifies owner/employee permissions.
/// A match is a suggestion until the user reviews the correct inventory record.
class AngelScanClient {
  final SupabaseClient client;
  const AngelScanClient(this.client);

  Future<Map<String, dynamic>> recognize({
    required String businessId,
    required List<int> imageBytes,
    required String mimeType,
    required bool inventoryMode,
    bool document = false,
  }) async {
    if (businessId.isEmpty || imageBytes.isEmpty || imageBytes.length > 4000000) {
      throw ArgumentError('A business and an image under 4 MB are required.');
    }
    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw ArgumentError('Use a JPEG, PNG or WebP image.');
    }
    final response = await client.functions.invoke(
      'angel-scan',
      body: {
        'business_id': businessId,
        'purpose': inventoryMode ? 'inventory' : 'sale',
        'document': document,
        'mime_type': mimeType,
        'image_base64': base64Encode(imageBytes),
      },
    );
    if (response.status != 200 || response.data is! Map) {
      throw StateError('Angel Scan is not available. Use barcode or inventory search.');
    }
    final result = Map<String, dynamic>.from(response.data as Map);
    if (result['success'] != true || result['items'] is! List) {
      throw StateError('Product recognition could not be confirmed.');
    }
    return result;
  }

  Future<String> submitManagerInventoryRequest({
    required String businessId,
    required List<Map<String, dynamic>> reviewedItems,
    String? branchId,
  }) async {
    if (reviewedItems.isEmpty || reviewedItems.length > 80) {
      throw ArgumentError('Review between 1 and 80 products before submitting.');
    }
    final result = await client.rpc('submit_angel_inventory_approval', params: {
      'p_business_id': businessId,
      'p_branch_id': branchId,
      'p_items': reviewedItems,
    });
    return result.toString();
  }

  Future<String> decideInventoryRequest({
    required String businessId,
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    return (await client.rpc('decide_angel_inventory_approval', params: {
      'p_business_id': businessId,
      'p_request_id': requestId,
      'p_approve': approve,
      'p_note': note,
    })).toString();
  }
}
