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
  String query = '', method = 'all';
  @override
  void dispose() { search.dispose(); super.dispose(); }
  String money(num amount) => CustomerPresentation.money(amount.toDouble(),
    currency: ref.read(authStateProvider).activeBusiness?.currency);
  String recordedMoney(dynamic value) {
    final amount = num.tryParse('$value');
    return amount == null || !amount.isFinite ? 'Amount unavailable' : money(amount);
  }
  String date(DateTime time) => DateFormat('dd MMM yyyy · HH:mm').format(time.toLocal());
  Future<void> refresh(String employee) async {
    ref.invalidate(recentSalesProvider(employee));
    await ref.read(recentSalesProvider(employee).future);
  }
  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(authStateProvider).employee?.membershipId;
    return Scaffold(appBar: AppBar(title: const Text('Sales History')),
      body: employee == null || employee.isEmpty
        ? const PosStateView(title: 'Sign in to view transactions', icon: Icons.person_outline)
        : ref.watch(recentSalesProvider(employee)).when(
          loading: () => const Center(child: TrexvenLoading(message: 'Loading transactions…')),
          error: (_, _) => PosStateView(title: 'Sales unavailable', message: 'Check your connection and try again.',
            icon: Icons.cloud_off_outlined,
            action: FilledButton(onPressed: () => refresh(employee), child: const Text('Retry'))),
          data: (sales) {
            final methods = sales.map((s) => s.paymentMethod).toSet().toList()..sort();
            final selected = method == 'all' || methods.contains(method) ? method : 'all';
            final visible = sales.where((s) => (selected == 'all' || s.paymentMethod == selected) &&
              ('${s.id} ${CustomerPresentation.label(s.paymentMethod)} ${s.items.map((i) => i.productName).join(' ')}')
                .toLowerCase().contains(query)).toList();
            return RefreshIndicator(onRefresh: () => refresh(employee), child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(), slivers: [
                SliverPadding(padding: PosSpace.page, sliver: SliverToBoxAdapter(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TrexvenTextField(controller: search, variant: TrexvenFieldVariant.search,
                      decoration: const TrexvenInputDecoration(hintText: 'Product, receipt or payment method',
                        prefixIcon: Icon(Icons.search_rounded)),
                      onChanged: (v) => setState(() => query = v.trim().toLowerCase())),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      ChoiceChip(label: const Text('All'), selected: selected == 'all',
                        onSelected: (_) => setState(() => method = 'all')),
                      for (final item in methods)
                        ChoiceChip(label: Text(CustomerPresentation.label(item)), selected: selected == item,
                          onSelected: (_) => setState(() => method = item)),
                    ]),
                    const SizedBox(height: 12),
                    Text('${visible.length} authorized transactions', style: Theme.of(context).textTheme.bodySmall),
                  ]))),
                if (visible.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: Center(child: TrexvenEmptyState(
                    title: sales.isEmpty ? 'No sales yet' : 'No matching transactions',
                    message: sales.isEmpty ? 'Confirmed sales will appear here.' : 'Try another search or filter.',
                    icon: Icons.receipt_long_outlined)))
                else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(itemCount: visible.length, itemBuilder: (context, i) {
                    final sale = visible[i];
                    return Column(children: [
                      Material(color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16), child: InkWell(
                          borderRadius: BorderRadius.circular(16), onTap: () => details(sale),
                          child: Padding(padding: const EdgeInsets.all(12), child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Wrap(spacing: 16, runSpacing: 4, alignment: WrapAlignment.spaceBetween,
                                children: [Text(money(sale.total), style: Theme.of(context).textTheme.titleMedium),
                                  PosStatus(CustomerPresentation.label(sale.paymentMethod))]),
                              const SizedBox(height: 8),
                              Text(date(sale.timestamp), style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Text('${sale.itemCount} items · View receipt', style: Theme.of(context).textTheme.bodySmall),
                            ])))),
                      const SizedBox(height: 8),
                    ]);
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
