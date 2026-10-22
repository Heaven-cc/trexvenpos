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
FutureProvider.family<List<Sale>, ({String employeeId, String filter, String? startDate, String? endDate})>(
      (ref, request) async {
    final employeeId = request.employeeId;
    if (employeeId.trim().isEmpty) {
      return const [];
    }

    final auth = ref.watch(authStateProvider);
    if (auth.employee?.membershipId != employeeId || auth.activeBusiness == null) return const [];
    final branch = ref.watch(branchContextProvider);
    if (auth.activeBusiness!.branchesEnabled && branch == null) return const [];
    // The backend enforces BUSINESS-LOCAL date filtering and the active member/
    // branch receipt scope. Do not substitute raw sales for an unauthorized RPC.
    return ref
        .watch(salesRepositoryProvider)
        .getPosRecentSales(auth.activeBusiness!.id,
          branchId: auth.activeBusiness!.branchesEnabled ? branch!.id : null,
          filter: request.filter,
          startDate: request.startDate,
          endDate: request.endDate);
  },
);
