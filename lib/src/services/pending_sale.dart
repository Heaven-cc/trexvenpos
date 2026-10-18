import 'dart:convert';
import '../models/sale.dart';

/// One interrupted online submission, not an offline sale queue.
class PendingSale {
  final String userId;
  final Sale sale;
  const PendingSale(this.userId, this.sale);
  Map<String, dynamic> toJson() => {
    'version': 1,
    'user_id': userId,
    'sale': sale.toJsonWithItems(),
  };
  factory PendingSale.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['version'] != 1 || json['user_id'] is! String) {
      throw const FormatException('Unsupported pending sale.');
    }
    final sale = Sale.fromJson(Map<String, dynamic>.from(json['sale']));
    if (sale.id.isEmpty ||
        sale.businessId.isEmpty ||
        sale.employeeId.isEmpty ||
        sale.items.isEmpty) {
      throw const FormatException('Invalid pending sale.');
    }
    return PendingSale(json['user_id'] as String, sale);
  }
  bool belongsTo(String user, String business, String membership) =>
      userId == user &&
      sale.businessId == business &&
      sale.employeeId == membership;
}

abstract interface class PendingSaleStore {
  Future<PendingSale?> read();
  Future<void> save(PendingSale pending);
  Future<void> acknowledge(String requestId);
}

abstract interface class LegacyPaymentUpgradeStore {
  Future<void> upgradePayment(PendingSale original, PendingSale verified);
}

class PendingSaleSubmission {
  final PendingSaleStore store;
  PendingSaleSubmission(this.store);

  /// Enrich a legacy journal only after checking its original receipt and
  /// explicitly verifying the original payment. Identity/cart remain immutable.
  Future<Sale> confirmLegacyPayment(
    PendingSale original,
    List<Map<String, dynamic>> payments,
    String? shiftId,
  ) async {
    final current = await store.read();
    if (current == null ||
        jsonEncode(current.toJson()) != jsonEncode(original.toJson()) ||
        original.sale.payments != null) {
      throw StateError('The original legacy request must still be pending.');
    }
    final sale = Sale.fromJson({
      ...original.sale.toJsonWithItems(),
      'payments': payments,
      if (shiftId != null) 'shift_id': shiftId,
    });
    final durable = store;
    if (durable is! LegacyPaymentUpgradeStore)
      throw StateError(
        'This storage cannot safely enrich the original journal. Keep it for recovery.',
      );
    await (durable as LegacyPaymentUpgradeStore).upgradePayment(
      original,
      PendingSale(original.userId, sale),
    );
    return sale;
  }

  Future<Sale> submit({
    required String userId,
    required Sale sale,
    required Future<Sale> Function(Sale) send,
  }) async {
    final existing = await store.read();
    Map<String, dynamic> payload(Sale value) =>
        value.toJsonWithItems()..remove('created_at');
    if (existing != null &&
        (!existing.belongsTo(userId, sale.businessId, sale.employeeId) ||
            jsonEncode(payload(existing.sale)) != jsonEncode(payload(sale)))) {
      throw StateError(
        'Recover the original pending sale before submitting another sale.',
      );
    }
    if (existing == null) await store.save(PendingSale(userId, sale));
    // Always call the server, including receipt recovery. Current database
    // permissions and branch assignments, rather than cached state, authorize it.
    // Payment may already have moved before submission. A server rejection does
    // not prove that it is safe to forget the money or reuse this request key.
    // Only a verified receipt or an explicit no-money-moved recovery may clear it.
    return await send(existing?.sale ?? sale);
  }
}
