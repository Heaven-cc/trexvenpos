import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// POS-only expense entry workspace.
///
/// Recording and history are intentionally unavailable until a server-side,
/// branch-attributed cash expense contract exists. This screen never writes
/// a local or remote expense or implies that a transaction was saved.
class PosExpenseSupportScreen extends StatefulWidget {
  const PosExpenseSupportScreen({super.key});

  @override
  State<PosExpenseSupportScreen> createState() => _PosExpenseSupportScreenState();
}

class _PosExpenseSupportScreenState extends State<PosExpenseSupportScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String _category = 'Shop supplies';
  int _tab = 0;

  static const _categories = [
    'Shop supplies',
    'Food & refreshments',
    'Transport',
    'Utilities',
    'Other expense',
  ];

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );

  Widget _lockedField(String label, String value, IconData icon) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      _panel(Row(children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses'),
        actions: [IconButton(
          tooltip: 'Expense history',
          onPressed: () => setState(() => _tab = 1),
          icon: const Icon(Icons.receipt_long_outlined),
        )]),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Record & manage cash spending',
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          _panel(Row(children: [
            Icon(Icons.store_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current branch', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('Expense attribution requires backend verification',
                  style: Theme.of(context).textTheme.bodySmall),
              ])),
            const Icon(Icons.shield_outlined),
          ])),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Record Expense')),
              ButtonSegment(value: 1, label: Text('Expense History')),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) => setState(() => _tab = selection.first),
          ),
          const SizedBox(height: 20),
          if (_tab == 0) ...[
            Row(children: [
              Expanded(child: Text('New Expense',
                style: Theme.of(context).textTheme.titleMedium)),
              Chip(label: const Text('Cash only'),
                avatar: const Icon(Icons.payments_outlined, size: 18)),
            ]),
            const SizedBox(height: 12),
            _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                  helperText: 'Currency follows the active business when connected',
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Expense category'),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What was the money spent on?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lockedField('Payment method', 'Cash', Icons.payments_outlined),
                const SizedBox(width: 10),
                _lockedField('Date', 'Today', Icons.calendar_today_outlined),
              ]),
            ])),
            const SizedBox(height: 14),
            _panel(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: scheme.primary),
              const SizedBox(width: 10),
              const Expanded(child: Text(
                'Recording is not yet available. A verified cash expense service '
                'must enforce the active business, branch, employee, and business date. '
                'No expense will be saved from this screen.')),
            ])),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add),
              label: const Text('Save Expense — Integration required'),
            ),
          ] else ...[
            Text('Expense History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _panel(Column(children: [
              Icon(Icons.receipt_long_outlined, size: 36, color: scheme.primary),
              const SizedBox(height: 12),
              const Text('Expense history unavailable',
                style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'A verified expense history endpoint is required. '
                'No sample entries are shown as real records.',
                textAlign: TextAlign.center,
              ),
            ])),
          ],
        ],
      )),
    );
  }
}
