import '../../ui/trexven_ui.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/permission_service.dart';
import '../inventory/product_search_screen.dart';
import 'dashboard_screen.dart';
import 'operations_screen.dart';
import 'cart_provider.dart';
import 'pending_sale_provider.dart';
import '../auth/branch_context.dart';
import 'employee_settings_screen.dart';
import 'help_safe_recovery_screen.dart';
import 'credit_returns_screen.dart';
import 'operation_history_screen.dart';
import 'package:trexven_operations/trexven_operations.dart';

/// Tabs retain the existing repositories and checkout. Auth, pending-sale and
/// authorized-branch gates remain outside this shell.
class PosShell extends ConsumerStatefulWidget {
  const PosShell({super.key});
  @override
  ConsumerState<PosShell> createState() => _PosShellState();
}

class _PosShellState extends ConsumerState<PosShell> {
  String selected = 'Home';
  final Set<String> visited = {'Home'};
  @override
  Widget build(BuildContext context) {
    final access = ref.watch(permissionServiceProvider);
    final auth = ref.watch(authStateProvider);
    final tabs = <({String label, IconData icon, Widget screen})>[
      (label: 'Home', icon: Icons.home_outlined, screen: DashboardScreen()),
      if (access.hasPermission('view_inventory'))
        (
          label: 'Inventory',
          icon: Icons.inventory_2_outlined,
          screen: ProductSearchScreen(),
        ),
      (label: 'More', icon: Icons.more_horiz, screen: const _MoreScreen()),
    ];
    final selectedIndex = tabs.indexWhere((tab) => tab.label == selected);
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: tabs
            .map(
              (tab) => visited.contains(tab.label)
                  ? KeyedSubtree(
                      key: ValueKey(
                        '${auth.activeBusiness?.id}:${auth.employee?.membershipId}:${tab.label}',
                      ),
                      child: tab.screen,
                    )
                  : SizedBox.shrink(),
            )
            .toList(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF182A43)
                  : const Color(0xFF14253F),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFF385273)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                children: [
                  for (final tab in tabs)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected == tab.label,
                        label: tab.label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(32),
                          onTap: () => setState(() {
                            selected = tab.label;
                            visited.add(selected);
                          }),
                          child: AnimatedContainer(
                            duration: PosMotion.duration(context, PosMotion.component),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
                            decoration: BoxDecoration(
                              color: selected == tab.label
                                  ? const Color(0xFF326BF3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tab.icon,
                                  size: 21,
                                  color: selected == tab.label
                                      ? Colors.white
                                      : const Color(0xFFA9BDD8),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tab.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected == tab.label
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected == tab.label
                                        ? Colors.white
                                        : const Color(0xFFA9BDD8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreScreen extends ConsumerWidget {
  const _MoreScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final access = ref.watch(permissionServiceProvider);
    final employee = auth.employee;
    final business = auth.activeBusiness;
    final notificationBranch = ref.watch(branchContextProvider)?.id;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'More Options',
          style: TextStyle(
            fontSize: TrexvenFontSize.section,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: TrexvenSpacing.cardPadding,
        children: [
          // User Profile Card Header
          Container(
            padding: TrexvenSpacing.cardPadding,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  child: Text(
                    (employee?.name.isNotEmpty == true)
                        ? employee!.name[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee?.name ?? 'My Profile',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.input,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${business?.name ?? 'No Business'} · ${employee?.employeeCode ?? ''}',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.body,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(TrexvenRadii.status),
                        ),
                        child: Text(
                          employee?.role.name.toUpperCase() ?? 'EMPLOYEE',
                          style: TextStyle(
                            fontSize: TrexvenFontSize.caption,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SectionGroupTitle(title: 'OPERATIONS & ACCESS'),
          const SizedBox(height: 8),
          _MoreMenuContainer(
            children: [
              if (!auth.offlineCashOnly &&
                  business?.branchesEnabled == true &&
                  canSwitchPosBranch(access))
                _MoreMenuItem(
                  icon: Icons.storefront_outlined,
                  title: 'Switch Branch',
                  subtitle: 'Change your authorized working branch',
                  onTap: () async {
                    try {
                      final branches = await ref.read(authorizedBranchesProvider.future);
                      if (!context.mounted) return;
                      final current = ref.read(branchContextProvider);
                      final chosen = await showDialog<AuthorizedBranch>(
                        context: context,
                        builder: (dialogContext) => SimpleDialog(
                          title: const Text('Select Branch'),
                          children: [
                            for (final branch in branches)
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(dialogContext, branch),
                                child: Row(children: [
                                  Icon(branch.id == current?.id
                                      ? Icons.check_circle_outline
                                      : Icons.storefront_outlined),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(branch.name)),
                                ]),
                              ),
                          ],
                        ),
                      );
                      if (chosen != null && context.mounted &&
                          chosen.id != current?.id) {
                        await selectPosBranch(ref, chosen, branches);
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error is StateError
                              ? error.message
                              : 'Unable to switch branches. Verify access and pending sales.')),
                        );
                      }
                    }
                  },
                ),
              if (!auth.offlineCashOnly)
                _MoreMenuItem(
                  icon: Icons.business_outlined,
                  title: 'Switch authorized business',
                  subtitle: 'Change active business context',
                  onTap: () async {
                    try {
                      if (await (await ref.read(
                            pendingSaleStoreProvider.future,
                          )).read() !=
                          null) {
                        throw StateError(
                          'Recover the retained sale before switching business.',
                        );
                      }
                      if (ref.read(cartProvider).isNotEmpty) {
                        throw StateError(
                          'Finish or remove the unsubmitted cart before switching business.',
                        );
                      }
                      if (await OperationJournal().pending() != null) throw StateError('Recover the retained operation before switching business.');
                      final rows =
                          await ref
                                  .read(supabaseProvider)
                                  .rpc('get_trexven_pos_context')
                              as List;
                      if (!context.mounted) return;
                      final id = await showDialog<String>(
                        animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
context: context,
                        builder: (context) => SimpleDialog(
                          title: const Text('Select authorized business'),
                          children: [
                            for (final row in rows)
                              if (!access.isOwner ||
                                  (row['employee'] as Map)['role'] == 'owner')
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    (row['business'] as Map)['id'] as String,
                                  ),
                                  child: Text(
                                    (row['business'] as Map)['business_name']
                                            ?.toString() ??
                                        'Business',
                                  ),
                                ),
                          ],
                        ),
                      );
                      if (id != null && context.mounted) {
                        await ref
                            .read(authStateProvider.notifier)
                            .restoreSession(businessId: id);
                        ref.invalidate(branchContextProvider);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Business switch was not confirmed. Recover pending sales and finish the current cart before verifying access online.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              _MoreMenuItem(
                icon: Icons.tune_rounded,
                title: 'Operations & Workflows',
                subtitle:
                    'Credit, returns, inventory, cash drawers & sync',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PosOperationsScreen()),
                ),
              ),
              if (!auth.offlineCashOnly && auth.activeBusiness != null)
                _MoreMenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Business notifications',
                  subtitle: 'Operational alerts & messages',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationCenterScreen(
                        posScoped: true,
                        branchId: notificationBranch,
                        contextIsCurrent: () => ref.read(authStateProvider).employee?.userId == employee?.userId &&
                            ref.read(authStateProvider).activeBusiness?.id == business?.id &&
                            ref.read(branchContextProvider)?.id == notificationBranch && !ref.read(authStateProvider).offlineCashOnly,
                        api: OperationsClient.pos(
                          ref.read(supabaseProvider),
                          auth.activeBusiness!.id,
                        ),
                        open: (context, route, referenceId) {
                          final current = ref.read(permissionServiceProvider);
                          if ((route == 'inventory' &&
                                  current.hasPermission('view_inventory')) ||
                              (route == 'cash' &&
                                  current.hasPermission('review_cash_shifts'))) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PosOperationsScreen(),
                              ),
                            );
                          } else if ((route == 'credit' || route == 'returns') && current.canAccessCreditReturns) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const PosCreditReturnsScreen()));
                          } else if (route == 'employees' && referenceId == ref.read(authStateProvider).employee?.id) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeSettingsScreen()));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Current permission is required to open this notification.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              _MoreMenuItem(icon: Icons.history_rounded, title: 'Operational history',
                subtitle: 'Your confirmed actions & retained requests',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosOperationHistoryScreen()))),
            ],
          ),
          const SizedBox(height: 20),

          _SectionGroupTitle(title: 'PREFERENCES & SECURITY'),
          const SizedBox(height: 8),
          _MoreMenuContainer(
            children: [
              _MoreMenuItem(
                icon: Icons.settings_outlined,
                title: 'My Settings',
                subtitle: 'Appearance, password & device recovery',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmployeeSettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionGroupTitle(title: 'SUPPORT & ACCOUNT'),
          const SizedBox(height: 8),
          _MoreMenuContainer(
            children: [
              _MoreMenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Help & Safe Recovery',
                subtitle: 'Guidance for offline sales & troubleshooting',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HelpSafeRecoveryScreen(),
                  ),
                ),
              ),
              _MoreMenuItem(
                icon: Icons.info_outline_rounded,
                title: 'About TREXVEN POS',
                subtitle: 'About this point-of-sale application',
                onTap: () => showDialog<void>(context: context,
                  animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
                  builder: (_) => const AboutDialog(
                    applicationName: 'TREXVEN POS',
                    applicationVersion: String.fromEnvironment('TREXVEN_BUILD_VERSION',
                      defaultValue: 'Development build — version not supplied'),
                    children: [
                      SizedBox(height: 12),
                      Text(
                        'TREXVEN POS is the employee-facing point-of-sale application in the TREXVEN business ecosystem. '
                        'It helps authorized staff record sales, manage checkout and receipts, access permitted inventory '
                        'and stocktaking workflows, record expenses, and handle approved credit and returns. '
                        'The business owner manages sensitive settings and financial oversight in the separate TREXVEN Owner App.',
                      ),
                      SizedBox(height: 16),
                      Center(child: Text('Powered by TREXVEN',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                    ],
                  )),

              ),
              _MoreMenuItem(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                subtitle: 'End current terminal session',
                isDestructive: true,
                onTap: () async {
                  final yes = await showDialog<bool>(
                    animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
context: context,
                    builder: (context) => AlertDialog(
                      scrollable: true,
                      title: const Text('Sign out?'),
                      content: const Text(
                        'Pending sales and encrypted queues stay on this device. The original employee must sign in to recover them. Unsubmitted cart changes are not a completed sale.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) {
                    await ref.read(authStateProvider.notifier).logout();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionGroupTitle extends StatelessWidget {
  final String title;
  const _SectionGroupTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: TrexvenFontSize.caption,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MoreMenuContainer extends StatelessWidget {
  final List<Widget> children;
  const _MoreMenuContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => PosActionRow(icon: icon, title: title,
    subtitle: subtitle, onTap: onTap, destructive: isDestructive);
}
