import 'dart:convert';
import '../models/sale.dart';

class OfflineCashEntry {
  final Sale sale;
  final String userId;
  final Map<String, dynamic> ticket;
  final DateTime occurredAt;
  final Map<String, dynamic>? receipt;
  const OfflineCashEntry({
    required this.sale,
    required this.userId,
    required this.ticket,
    required this.occurredAt,
    this.receipt,
  });
  String get requestId => sale.id;
  bool belongsTo(String user, String business, String member) =>
      userId == user &&
      sale.businessId == business &&
      sale.employeeId == member;
  Map<String, dynamic> toJson() => {
    'sale': sale.toJsonWithItems(),
    'user': userId,
    'ticket': ticket,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    if (receipt != null) 'receipt': receipt,
  };
  factory OfflineCashEntry.fromJson(Map<String, dynamic> value) =>
      OfflineCashEntry(
        sale: Sale.fromJson(Map<String, dynamic>.from(value['sale'] as Map)),
        userId: value['user'] as String,
        ticket: Map<String, dynamic>.from(value['ticket'] as Map),
        occurredAt: DateTime.parse(value['occurred_at'] as String),
        receipt: value['receipt'] == null
            ? null
            : Map<String, dynamic>.from(value['receipt'] as Map),
      );

  void validateCashScope(DateTime now) {
    final scope = Map<String, dynamic>.from(ticket['scope'] as Map);
    final issued = DateTime.parse(scope['issued_at'] as String);
    final expires = DateTime.parse(scope['expires_at'] as String);
    if (scope['version'] != 1 ||
        (ticket['signature'] as String?)?.isEmpty != false ||
        scope['user_id'] != userId ||
        scope['business_id'] != sale.businessId ||
        scope['membership_id'] != sale.employeeId ||
        scope['branch_id'] != sale.branchId ||
        now.isBefore(issued) ||
        !now.isBefore(expires) ||
        occurredAt.isBefore(issued) ||
        !occurredAt.isBefore(expires) ||
        occurredAt.isAfter(now) ||
        sale.paymentMethod.toLowerCase() != 'cash' ||
        sale.items.isEmpty ||
        !sale.total.isFinite ||
        sale.total < 0) {
      throw StateError(
        'A current signed cash scope for this employee and device is required.',
      );
    }
    final products = {
      for (final p in (scope['products'] as List)) (p as Map)['id']: p,
    };
    final seen = <String>{};
    var cents = 0;
    for (final item in sale.items) {
      final product = products[item.productId];
      if (product == null ||
          !seen.add(item.productId) ||
          item.discount != 0 ||
          item.unitPrice != (product['price'] as num).toDouble() ||
          !item.quantity.isFinite ||
          item.quantity <= 0 ||
          (item.quantity * 1000 - (item.quantity * 1000).round()).abs() >
              0.000001) {
        throw StateError(
          'Offline items must match the signed catalog without discounts or overrides.',
        );
      }
      if (!const {
            'kg',
            'g',
            'litre',
            'ml',
            'metre',
            'cm',
          }.contains(product['unit']) &&
          item.quantity != item.quantity.truncate()) {
        throw StateError('This product requires whole quantities.');
      }
      final quantity = (item.quantity * 1000).round();
      final price = (item.unitPrice * 100).round();
      cents += (quantity * price + 500) ~/ 1000;
    }
    if (cents != (sale.total * 100).round())
      throw StateError('Offline cash total differs from items.');
  }
}

abstract class OfflineCashStore {
  Future<Map<String, dynamic>> readState();
  Future<T> mutate<T>(T Function(Map<String, dynamic>) change);
}

class OfflineCashQueue {
  final OfflineCashStore store;
  OfflineCashQueue(this.store);
  Future<List<OfflineCashEntry>> entries() async =>
      ((await store.readState())['entries'] as List? ?? const [])
          .map(
            (x) =>
                OfflineCashEntry.fromJson(Map<String, dynamic>.from(x as Map)),
          )
          .toList();
  Future<void> cacheTicket(
    Map<String, dynamic> ticket,
    DateTime now, {
    Map<String, dynamic>? authContext,
  }) => store.mutate((state) {
    state['ticket'] = ticket;
    if (authContext != null) {
      state['auth_context'] = authContext;
    } else {
      state.remove('auth_context');
    }
    state['last_seen'] = now.toUtc().toIso8601String();
  });
  Future<Map<String, dynamic>?> ticket() async {
    final value = (await store.readState())['ticket'];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<void> enqueue(OfflineCashEntry entry, DateTime now) => store.mutate((
    state,
  ) {
    final last = DateTime.tryParse(state['last_seen']?.toString() ?? '');
    if (last != null && now.isBefore(last))
      throw StateError(
        'Device clock moved backwards. Reconnect before recording cash.',
      );
    entry.validateCashScope(now);
    final entries = List<dynamic>.from(state['entries'] as List? ?? const []);
    final existing = entries.where(
      (x) => (x as Map)['sale']['id'] == entry.requestId,
    );
    if (existing.isNotEmpty) {
      if (jsonEncode(existing.single) != jsonEncode(entry.toJson()))
        throw StateError('Offline request identity conflict.');
      return;
    }
    entries.add(entry.toJson());
    state['entries'] = entries;
    state['last_seen'] = now.toUtc().toIso8601String();
  });
  Future<Map<String, dynamic>> synchronize(
    OfflineCashEntry entry,
    Future<Map<String, dynamic>> Function(OfflineCashEntry) send,
  ) async {
    if (entry.receipt != null) return entry.receipt!;
    final receipt = await send(entry);
    if (receipt['id'] == null ||
        receipt['business_id'] != entry.sale.businessId ||
        receipt['employee_id'] != entry.sale.employeeId) {
      throw StateError(
        'Server receipt does not match the original cash context.',
      );
    }
    await store.mutate((state) {
      final entries = List<dynamic>.from(state['entries'] as List? ?? const []);
      final index = entries.indexWhere(
        (x) => (x as Map)['sale']['id'] == entry.requestId,
      );
      if (index < 0) throw StateError('Queued cash request is missing.');
      entries[index] = {
        ...Map<String, dynamic>.from(entries[index] as Map),
        'receipt': receipt,
      };
      state['entries'] = entries;
    });
    return receipt;
  }

  Future<void> acknowledge(String requestId) => store.mutate((state) {
    final entries = List<dynamic>.from(state['entries'] as List? ?? const []);
    final index = entries.indexWhere(
      (x) => (x as Map)['sale']['id'] == requestId,
    );
    if (index < 0) return;
    if ((entries[index] as Map)['receipt'] == null)
      throw StateError('Unverified cash cannot be removed.');
    entries.removeAt(index);
    state['entries'] = entries;
  });
}
