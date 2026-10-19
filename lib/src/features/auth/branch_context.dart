import 'package:shared_preferences/shared_preferences.dart';
import '../../ui/trexven_ui.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pos/cart_provider.dart';
import '../pos/pending_sale_provider.dart';
import 'permission_service.dart';
import 'auth_provider.dart';

class AuthorizedBranch {
  final String id;
  final String businessId;
  final String name;
  const AuthorizedBranch({
    required this.id,
    required this.businessId,
    required this.name,
  });
}

class BranchContext extends StateNotifier<AuthorizedBranch?> {
  final String businessId;
  bool restoreAttempted = false;
  BranchContext(this.businessId) : super(null);

  void select(
    AuthorizedBranch branch,
    List<AuthorizedBranch> available, {
    required bool hasCart,
    bool hasPendingSale = false,
    bool canSwitch = true,
  }) {
    if (state != null && state!.id != branch.id && !canSwitch) {
      throw StateError('Only managers and owners can switch branches.');
    }
    if (hasPendingSale) {
      throw StateError('Recover the retained sale before switching branches.');
    }
    if (hasCart)
      throw StateError(
        'Finish or clear the current cart before switching branches.',
      );
    if (branch.businessId != businessId ||
        !available.any(
          (b) => b.id == branch.id && b.businessId == businessId,
        )) {
      throw StateError('Select an authorized branch.');
    }
    state = branch;
  }

  void clear({required bool hasCart, bool hasPendingSale = false, bool canSwitch = true}) {
    if (!canSwitch) throw StateError('Only managers and owners can switch branches.');
    if (hasPendingSale) throw StateError('Recover the retained sale before switching branches.');
    if (hasCart)
      throw StateError(
        'Finish or clear the current cart before switching branches.',
      );
    state = null;
  }
}

final branchContextProvider =
    StateNotifierProvider<BranchContext, AuthorizedBranch?>((ref) {
      ref.watch(
        authStateProvider.select(
          (s) => '${s.employee?.userId}:${s.activeBusiness?.id}',
        ),
      );
      return BranchContext(
        ref.read(authStateProvider).activeBusiness?.id ?? '',
      );
    });

final authorizedBranchesProvider = FutureProvider<List<AuthorizedBranch>>((
  ref,
) async {
  final business = ref.watch(authStateProvider).activeBusiness;
  if (business == null || !business.branchesEnabled) return [];
  // RLS supplies the authoritative assignment list. Cached UI context is never
  // sent as proof of authority; every RPC checks assignments again.
  final rows = await ref
      .watch(supabaseProvider)
      .from('branches')
      .select('id,business_id,name')
      .eq('business_id', business.id)
      .eq('is_active', true)
      .order('name');
  final available = rows
      .map(
        (r) => AuthorizedBranch(
          id: r['id'].toString(),
          businessId: r['business_id'].toString(),
          name: r['name'].toString(),
        ),
      )
      .toList();
  final user = ref.read(authStateProvider).employee?.userId;
  SharedPreferences? prefs;
  try { prefs = await SharedPreferences.getInstance(); } catch (_) {}
  final branchState = ref.read(branchContextProvider.notifier);
  final canRestore = !branchState.restoreAttempted;
  branchState.restoreAttempted = true;
  if (canRestore && user != null && ref.read(authStateProvider).activeBusiness?.id == business.id &&
      ref.read(branchContextProvider) == null && available.isNotEmpty) {
    final hint = prefs?.getString('pos_branch_$user:${business.id}');
    final matches = available.where((b) => b.id == hint);
    final restore = matches.isNotEmpty ? matches.first : available.length == 1 ? available.single : null;
    if (restore != null) {
      final pending = await (await ref.read(pendingSaleStoreProvider.future)).read();
      if (pending == null && ref.read(authStateProvider).employee?.userId == user &&
          ref.read(authStateProvider).activeBusiness?.id == business.id) {
        ref.read(branchContextProvider.notifier).select(restore, available,
          hasCart: ref.read(cartProvider).isNotEmpty);
      }
    }
  }
  return available;
});

bool canSwitchPosBranch(PermissionService access) =>
    access.isActive && (access.isOwner || access.isManager);

Future<void> selectPosBranch(
  WidgetRef ref,
  AuthorizedBranch branch,
  List<AuthorizedBranch> available,
) async {
  final pending = await (await ref.read(pendingSaleStoreProvider.future)).read();
  ref.read(branchContextProvider.notifier).select(
    branch, available,
    hasCart: ref.read(cartProvider).isNotEmpty,
    hasPendingSale: pending != null,
    canSwitch: canSwitchPosBranch(ref.read(permissionServiceProvider)),
  );
  final user = ref.read(authStateProvider).employee?.userId;
  if (user != null) {
    try { await (await SharedPreferences.getInstance()).setString('pos_branch_$user:${branch.businessId}', branch.id); } catch (_) {}
  }
}

class BranchGate extends ConsumerWidget {
  final Widget child;
  const BranchGate({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(authStateProvider).activeBusiness;
    if (business == null || !business.branchesEnabled) return child;
    final selected = ref.watch(branchContextProvider);
    return ref.watch(authorizedBranchesProvider).when(
      loading: () => const Scaffold(body: Center(child: TrexvenLoading(message: 'Checking branch access…'))),
      error: (_, _) => Scaffold(appBar: AppBar(title: const Text('Select Branch')),
        body: PosStateView(title: 'Unable to verify branch assignments', message: 'Check your connection and try again.',
          icon: Icons.cloud_off_outlined, action: FilledButton.icon(
            onPressed: () => ref.invalidate(authorizedBranchesProvider), icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')))),
      data: (available) {
        if (selected != null && available.any((b) => b.id == selected.id && b.businessId == business.id)) return child;
        return Scaffold(appBar: AppBar(title: const Text('Select Branch')),
          body: available.isEmpty
            ? const PosStateView(title: 'No active branch assignments', message: 'Contact your business owner for branch access.',
                icon: Icons.storefront_outlined)
            : ListView(padding: PosSpace.page, children: [
                Text(business.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                PosSurface(padding: EdgeInsets.zero, child: Column(children: [
                  for (final branch in available) ...[
                    PosActionRow(icon: Icons.storefront_outlined, title: branch.name, subtitle: 'Operate in this branch', onTap: () async {
                      try {
                        await selectPosBranch(ref, branch, available);
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is StateError ? error.message : 'Unable to verify branch selection. Please retry.')));
                      }
                    }),
                    const Divider(indent: 64),
                  ],
                ])),
              ]));
      });
  }
}
