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
    return ref
        .watch(salesRepositoryProvider)
        .getAuthorizedBusinessSales(auth.activeBusiness!.id,
          branchId: auth.activeBusiness!.branchesEnabled ? branch!.id : null);
  },
);
