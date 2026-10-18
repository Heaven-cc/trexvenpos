import '../models/business.dart';
import '../models/employee.dart';
import 'offline_cash_queue.dart';
import 'offline_cash_unsupported.dart'
    if (dart.library.io) 'offline_cash_file.dart'
    as storage;

Future<Map<String, dynamic>?> loadOfflineCashContext(String userId) async {
  final queue = await storage.createOfflineCashQueue();
  return resumeOfflineCashContext(queue.store, userId, DateTime.now());
}

/// Reads only authenticated native encrypted state. The signature is rechecked
/// by the server during synchronization; offline use never grants online access.
Future<Map<String, dynamic>?> resumeOfflineCashContext(
  OfflineCashStore store,
  String userId,
  DateTime now,
) => store.mutate((state) {
  if (state['ticket'] is! Map || state['auth_context'] is! Map) return null;
  final ticket = state['ticket'] as Map;
  if (ticket['scope'] is! Map) return null;
  final scope = ticket['scope'] as Map;
  final context = Map<String, dynamic>.from(state['auth_context'] as Map);
  final employee = Employee.fromJson(
    Map<String, dynamic>.from(context['employee'] as Map),
  );
  final business = Business.fromJson(
    Map<String, dynamic>.from(context['business'] as Map),
  );
  final issued = DateTime.tryParse(scope['issued_at']?.toString() ?? '');
  final expires = DateTime.tryParse(scope['expires_at']?.toString() ?? '');
  final lastSeen = DateTime.tryParse(state['last_seen']?.toString() ?? '');
  if (scope['version'] != 1 ||
      ticket['signature'] is! String ||
      (ticket['signature'] as String).isEmpty ||
      scope['device_id'] == null ||
      scope['device_id'] != state['device_id'] ||
      scope['user_id'] != userId ||
      employee.userId != userId ||
      scope['business_id'] != business.id ||
      employee.businessId != business.id ||
      scope['membership_id'] != employee.membershipId ||
      employee.membershipId.isEmpty ||
      employee.id.isEmpty ||
      !employee.isActive ||
      !employee.hasPermission('complete_sales') ||
      !employee.hasPermission('pos_access') ||
      business.branchesEnabled ||
      scope['branch_id'] != null ||
      issued == null ||
      expires == null ||
      lastSeen == null ||
      expires.difference(issued) > const Duration(hours: 24) ||
      now.isBefore(issued) ||
      now.isBefore(lastSeen) ||
      !now.isBefore(expires) ||
      scope['products'] is! List)
    return null;
  state['last_seen'] = now.toUtc().toIso8601String();
  return context;
});
