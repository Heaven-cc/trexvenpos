import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import 'sales_repository.dart';
import '../../models/sale.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(
    ref.watch(supabaseProvider),
  );
});

final recentSalesProvider =
FutureProvider.family<List<Sale>, String>(
      (ref, employeeId) async {
    if (employeeId.trim().isEmpty) {
      return const [];
    }

    final auth = ref.watch(authStateProvider);
    if (auth.employee?.membershipId != employeeId || auth.activeBusiness == null) return const [];
    final branch = ref.watch(branchContextProvider);
    if (auth.activeBusiness!.branchesEnabled && branch == null) return const [];
    // The POS history is operational (last seven local calendar days).
    // Permissions and branch visibility remain enforced by Supabase RLS.
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    return ref
        .watch(salesRepositoryProvider)
        .getAuthorizedBusinessSales(auth.activeBusiness!.id,
          since: firstDay,
          branchId: auth.activeBusiness!.branchesEnabled ? branch!.id : null);
  },
);
