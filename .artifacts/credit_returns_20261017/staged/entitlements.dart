import 'package:supabase_flutter/supabase_flutter.dart';
import 'operations_client.dart';

class BusinessEntitlements {
  final Map<String, dynamic> data;
  const BusinessEntitlements(this.data);
  bool get configured => data['configured'] == true;
  String? get plan => data['plan']?.toString();
  bool get enforced => data['enforced'] == true;
  bool allows(String feature) =>
      !enforced || (data['features'] as Map?)?[feature] == true;
  String get status => data['status']?.toString() ?? 'unavailable';
  static Future<BusinessEntitlements> load(OperationsClient api) async {
    try {
      return BusinessEntitlements(
        Map<String, dynamic>.from(
          await api.call('get_trexven_entitlements', {
                'p_business_id': api.businessId,
              })
              as Map,
        ),
      );
    } on PostgrestException catch (e) {
      // Earlier approved backends have no subscriptions; never reinterpret an
      // authorization/network failure as an entitlement grant.
      if (e.code == 'PGRST202')
        return const BusinessEntitlements({
          'enforced': false,
          'status': 'not configured',
          'features': {},
        });
      rethrow;
    }
  }
}
