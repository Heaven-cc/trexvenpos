import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../models/sale.dart';
import '../../ui/trexven_ui.dart';
import '../auth/auth_provider.dart';
import 'sales_provider.dart';

class RecentSalesScreen extends ConsumerStatefulWidget {
  const RecentSalesScreen({super.key});
  @override
  ConsumerState<RecentSalesScreen> createState() => _RecentSalesScreenState();
}

class _RecentSalesScreenState extends ConsumerState<RecentSalesScreen> {
  final search = TextEditingController();
  String query = '', method = 'all', dateFilter = 'week';
  DateTimeRange? customRange;
  @override
  void dispose() { search.dispose(); super.dispose(); }
  String money(num amount) => CustomerPresentation.money(amount.toDouble(),
    currency: ref.read(authStateProvider).activeBusiness?.currency);
  String recordedMoney(dynamic value) {
    final amount = num.tryParse('$value');
    return amount == null || !amount.isFinite ? 'Amount unavailable' : money(amount);
  }
  String date(DateTime time) => DateFormat('dd MMM yyyy · HH:mm').format(time.toLocal());
  ({String employeeId, String filter, String? startDate, String? endDate})
      historyRequest(String employeeId) => (
        employeeId: employeeId,
        filter: dateFilter,
        startDate: dateFilter == 'custom' && customRange != null
            ? DateFormat('yyyy-MM-dd').format(customRange!.start) : null,
        endDate: dateFilter == 'custom' && customRange != null
            ? DateFormat('yyyy-MM-dd').format(customRange!.end) : null,
      );

  Future<void> chooseRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: customRange,
    );
    if (!mounted || picked == null) return;
    setState(() { customRange = picked; dateFilter = 'custom'; });
  }

  Widget dateChip(String value, String label) => ChoiceChip(
    label: Text(label),
    selected: dateFilter == value,
    onSelected: (_) => value == 'custom'
        ? chooseRange()
        : setState(() => dateFilter = value),
  );

  Future<void> refresh(String employee) async {
    final request = historyRequest(employee);
    ref.invalidate(recentSalesProvider(request));
    await ref.read(recentSalesProvider(request).future);
  }
  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(authStateProvider).employee?.membershipId;
    return Scaffold(appBar: AppBar(title: const Text('Sales History'),
      actions: [IconButton(tooltip: 'Custom date range', icon: const Icon(Icons.calendar_month_outlined),
        onPressed: chooseRange)]),
      body: employee == null || employee.isEmpty
        ? const PosStateView(title: 'Sign in to view transactions', icon: Icons.person_outline)
        : ref.watch(recentSalesProvider(historyRequest(employee))).when(
          loading: () => const TrexvenSkeleton(kind: TrexvenSkeletonKind.salesHistory),
          error: (_, _) => PosStateView(title: 'Sales unavailable', message: 'Unable to load authorized sales receipts. Check your connection or contact the owner if the sales-history update has not been activated.',
            icon: Icons.cloud_off_outlined,
            action: FilledButton(onPressed: () => refresh(employee), child: const Text('Retry'))),
          data: (sales) {
            final methods = sales.map((s) => s.paymentMethod).toSet().toList()..sort();
            final selected = method == 'all' || methods.contains(method) ? method : 'all';
            final visible = sales.where((s) =>
              (selected == 'all' || s.paymentMethod == selected) &&
              ('${s.id} ${CustomerPresentation.label(s.paymentMethod)} ${s.items.map((i) => i.productName).join(' ')}')
                .toLowerCase().contains(query)).toList();
            return RefreshIndicator(onRefresh: () => refresh(employee), child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(), slivers: [
                SliverPadding(padding: PosSpace.page, sliver: SliverToBoxAdapter(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Transaction records & receipts',
                      style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    TrexvenTextField(controller: search, variant: TrexvenFieldVariant.search,
                      decoration: const TrexvenInputDecoration(hintText: 'Search receipt, product or payment',
                        prefixIcon: Icon(Icons.search_rounded)),
                      onChanged: (v) => setState(() => query = v.trim().toLowerCase())),
                    const SizedBox(height: 12),
                    SingleChildScrollView(scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        dateChip('all', 'All'),
                        const SizedBox(width: 8),
                        dateChip('today', 'Today'),
                        const SizedBox(width: 8),
                        dateChip('yesterday', 'Yesterday'),
                        const SizedBox(width: 8),
                        dateChip('week', '7 days'),
                        const SizedBox(width: 8),
                        dateChip('custom', customRange == null ? 'Custom' :
                          '${DateFormat('dd MMM').format(customRange!.start)} – ${DateFormat('dd MMM').format(customRange!.end)}'),
                      ])),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: Text('Transactions',
                        style: Theme.of(context).textTheme.titleMedium)),
                      DropdownButton<String>(
                        value: selected,
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('Payment: All')),
                          for (final item in methods)
                            DropdownMenuItem(value: item,
                              child: Text(CustomerPresentation.label(item))),
                        ],
                        onChanged: (v) => setState(() => method = v ?? 'all'),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${visible.length} authorized transactions',
                        style: Theme.of(context).textTheme.bodySmall),
                      Text('Newest first', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                    const SizedBox(height: 12),
                  ]))),
                if (visible.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: Center(child: TrexvenEmptyState(
                    title: sales.isEmpty ? 'No sales yet' : 'No matching transactions',
                    message: sales.isEmpty ? 'Confirmed sales will appear here.' : 'Try another search or filter.',
                    icon: Icons.receipt_long_outlined)))
                else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(itemCount: visible.length, itemBuilder: (context, i) {
                    final sale = visible[i];
                    final productNames = sale.items
                        .map((item) => item.productName.trim())
                        .where((name) => name.isNotEmpty)
                        .toList();
                    final products = productNames.isEmpty ? 'Items not listed' :
                        productNames.take(2).join(', ') +
                        (productNames.length > 2 ? ' +${productNames.length - 2} more' : '');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => details(sale),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                const Icon(Icons.receipt_long_outlined),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sale.id.length > 12
                                        ? 'Receipt …${sale.id.substring(sale.id.length - 8)}'
                                        : 'Receipt ${sale.id}',
                                      style: Theme.of(context).textTheme.titleSmall),
                                    Text(date(sale.timestamp),
                                      style: Theme.of(context).textTheme.bodySmall),
                                  ])),
                                PosStatus(CustomerPresentation.label(sale.paymentMethod)),
                              ]),
                              const Divider(height: 24),
                              Text(products, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(money(sale.total),
                                      style: Theme.of(context).textTheme.titleMedium),
                                    Text('${sale.itemCount} items',
                                      style: Theme.of(context).textTheme.bodySmall),
                                  ])),
                                const Icon(Icons.chevron_right_rounded),
                                const SizedBox(width: 4),
                                const Text('View receipt'),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    );
                  })),
              ]));
          }));
  }
  void details(Sale sale) => showModalBottomSheet<void>(context: context, isScrollControlled: true,
    sheetAnimationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.page)),
    builder: (context) => TrexvenBottomSheet(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Sale receipt', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4), Text(date(sale.timestamp)),
        const SizedBox(height: 12),
        PosSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final item in sale.items) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.productName.isEmpty ? 'Product' : item.productName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(spacing: 12, runSpacing: 4, children: [
                Text('${item.quantity} × ${money(item.unitPrice)}'), Text(money(item.total)),
                if (item.discount > 0) Text('Discount ${money(item.discount)}'),
              ]),
            ])),
          const Divider(), const SizedBox(height: 12),
          Text('Total ${money(sale.total)}', style: Theme.of(context).textTheme.titleLarge),
        ])),
        const SizedBox(height: 12),
        if (sale.payments?.isNotEmpty == true)
          for (final payment in sale.payments!)
            ListTile(contentPadding: EdgeInsets.zero, title: Text(CustomerPresentation.label(payment['method'])),
              subtitle: Text(recordedMoney(payment['amount'])))
        else Text('Payment: ${CustomerPresentation.label(sale.paymentMethod)}'),
        const SizedBox(height: 12),
        ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Receipt reference'),
          children: [SelectableText(sale.id)]),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close receipt')),
      ])));
}
