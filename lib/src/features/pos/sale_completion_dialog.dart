import 'package:flutter/material.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../models/sale.dart';
import '../../ui/trexven_ui.dart';

/// Shown only after the existing submission returns its confirmed receipt.
class SaleCompletionDialog extends StatelessWidget {
  final Sale sale;
  final String? currency;
  final double? cashTendered, cashChange;
  const SaleCompletionDialog({super.key, required this.sale, this.currency,
    this.cashTendered, this.cashChange});
  String money(num value) => CustomerPresentation.money(value.toDouble(), currency: currency);
  String recordedMoney(dynamic value) {
    final parsed = num.tryParse('$value');
    return parsed == null || !parsed.isFinite ? 'Amount unavailable' : money(parsed);
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: false, child: Dialog(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PosStatus('Sale confirmed', success: true),
          const SizedBox(height: 12),
          Text('Sale complete', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          PosGlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TREXVEN · Sale total', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(money(sale.total), style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white)),
          ])),
          const SizedBox(height: 16),
          if (sale.payments?.isNotEmpty == true)
            for (final payment in sale.payments!)
              _line(CustomerPresentation.label(payment['method']), recordedMoney(payment['amount']))
          else _line('Payment method', CustomerPresentation.label(sale.paymentMethod)),
          if (sale.credit != null) ...[
            const SizedBox(height: 8),
            const Text('Approved credit is recorded separately from money collected.'),
            if (sale.credit!['outstanding'] != null || sale.credit!['amount'] != null)
              _line('Credit', recordedMoney(sale.credit!['outstanding'] ?? sale.credit!['amount'])),
          ],
          if (cashTendered != null) _line('Cash tendered', money(cashTendered!)),
          if (cashChange != null) _line('Cash change', money(cashChange!)),
          const SizedBox(height: 16),
          OutlinedButton.icon(icon: const Icon(Icons.receipt_long_outlined), label: const Text('View receipt'),
            onPressed: () => showDialog<void>(context: context,
              animationStyle: AnimationStyle(duration: PosMotion.duration(context, PosMotion.component)),
              builder: (ctx) => AlertDialog(
              scrollable: true, title: const Text('Sale receipt'), content: SelectableText([
                'Receipt: ${sale.id}',
                for (final item in sale.items) '${item.productName} × ${item.quantity}: ${money(item.total)}',
                'Total: ${money(sale.total)}',
              ].join('\n')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]))),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('New Sale')),
        ])))));
  Widget _line(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 16, runSpacing: 4,
      children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]));
}
