part of 'financial_operations_screen.dart';

typedef _Row = Map<String, dynamic>;

class _SectionData {
  final List<_Row> rows;
  final Object? error;
  const _SectionData([this.rows = const [], this.error]);
}

class _CustomerCredit {
  final String key;
  final List<_Row> accounts;
  _CustomerCredit(this.key, this.accounts);
  String get name => accounts.first['debtor_name']?.toString() ?? 'Customer';
  String get contact => accounts.first['contact']?.toString() ?? '';
  int get outstanding =>
      accounts.fold(0, (n, a) => n + _cents(a['outstanding']));
  int get original =>
      accounts.fold(0, (n, a) => n + _cents(a['original_amount']));
}

// Exact integer arithmetic for balances and quantities; display never determines
// an RPC outcome. The server still locks and validates every financial change.
int _cents(Object? value) {
  final text = value?.toString() ?? '';
  final negative = text.startsWith('-');
  return OperationsClient.moneyCents(
        negative ? text.substring(1) : text,
        allowZero: true,
      ) *
      (negative ? -1 : 1);
}

int _units(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(text)) {
    throw const FormatException(
      'Enter a quantity with at most three decimal places.',
    );
  }
  final parts = text.split('.');
  return int.parse(parts.first) * 1000 +
      int.parse(parts.length == 1 ? '0' : parts[1].padRight(3, '0'));
}

String _quantity(int units) =>
    (units / 1000).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

String _money(Object? amount, String? currency) =>
    CustomerPresentation.amount(amount, currency: currency);

String _cash(int cents, String? currency) =>
    _money((cents / 100).toStringAsFixed(2), currency);

String _customerKey(_Row row) => '${row['debtor_name']}\u0000${row['contact']}';

List<_CustomerCredit> _customers(List<_Row> accounts) {
  final groups = <String, List<_Row>>{};
  for (final account in accounts) {
    groups.putIfAbsent(_customerKey(account), () => []).add(account);
  }
  return groups.entries.map((e) => _CustomerCredit(e.key, e.value)).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

class _CreditCard extends StatelessWidget {
  final Widget child;
  final bool highlighted;
  const _CreditCard({required this.child, this.highlighted = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: TrexvenSpacing.cardPadding,
    decoration: BoxDecoration(
      color: highlighted
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(TrexvenRadii.card),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class _CreditBadge extends StatelessWidget {
  final String text;
  final bool active;
  const _CreditBadge(this.text, {this.active = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: TrexvenPresentation.spacing(context, 10), vertical: TrexvenPresentation.spacing(context, 5)),
    decoration: BoxDecoration(
      color: active
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(TrexvenRadii.pill),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: active
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: TrexvenFontSize.caption,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CreditMetric extends StatelessWidget {
  final String label, value, caption;
  const _CreditMetric(this.label, this.value, this.caption);
  @override
  Widget build(BuildContext context) => _CreditCard(
    highlighted: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(value, style: TrexvenPresentation.typography(context, TrexvenTypography.title)),
        const SizedBox(height: 12),
        Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _CreditField {
  final String key, label, initial;
  final String? helper;
  final bool numeric, required;
  final List<String>? choices;
  final String? Function(String)? validate;
  const _CreditField(
    this.key,
    this.label, {
    this.initial = '',
    this.helper,
    this.numeric = false,
    this.required = true,
    this.choices,
    this.validate,
  });
}

Future<Map<String, String>?> _creditForm(
  BuildContext context,
  String title,
  List<_CreditField> fields, {
  String? description,
  String? confirmation,
  String submit = 'Confirm',
}) async {
  final controls = {
    for (final field in fields)
      field.key: TextEditingController(text: field.initial),
  };
  final formKey = GlobalKey<FormState>();
  var confirmed = false;
  String? error;
  return showDialog<Map<String, String>>(
    animationStyle: TrexvenPresentation.motion(context),
context: context,
    builder: (dialogContext) => TextControllerScope(
      controllers: controls.values.toList(),
      child: StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (description != null) ...[
                    Text(description),
                    const SizedBox(height: 16),
                  ],
                  for (final field in fields)
                    if (field.choices != null)
                      TrexvenDropdown<String>(
                        value: field.initial.isEmpty ? null : field.initial,
                        decoration: TrexvenInputDecoration(
                          labelText: field.label,
                        ),
                        items: [
                          for (final value in field.choices!)
                            DropdownMenuItem(
                              value: value,
                              child: Text(CustomerPresentation.label(value)),
                            ),
                        ],
                        onChanged: (value) => update(() {
                          controls[field.key]!.text = value ?? '';
                          error = null;
                        }),
                        validator: (value) =>
                            (value == null || value.isEmpty) && field.required
                            ? 'Choose ${field.label.toLowerCase()}.'
                            : null,
                      )
                    else
                      TrexvenTextFormField(
                        controller: controls[field.key],
                        decoration: TrexvenInputDecoration(
                          labelText: field.label,
                          helperText: field.helper,
                        ),
                        keyboardType: field.numeric
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (field.required && text.isEmpty) {
                            return 'This field is required.';
                          }
                          return field.validate?.call(text);
                        },
                      ),
                  if (confirmation != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: confirmed,
                      onChanged: (value) =>
                          update(() => confirmed = value ?? false),
                      title: Text(confirmation),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (confirmation != null && !confirmed) {
                  update(() => error = 'Verify the outcome before confirming.');
                  return;
                }
                final values = controls.map(
                  (k, v) => MapEntry(k, v.text.trim()),
                );
                final method = values['method'];
                if (method != null &&
                    method != 'cash' &&
                    values.containsKey('evidence') &&
                    values['evidence']!.isEmpty) {
                  update(
                    () => error =
                        'Enter the verified bank or terminal reference.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, values);
              },
              child: Text(submit),
            ),
          ],
        ),
      ),
    ),
  );
}

String? _moneyError(String value, {int? maximum, bool zero = false}) {
  try {
    final cents = OperationsClient.moneyCents(value, allowZero: zero);
    if (maximum != null && cents > maximum) {
      return 'Amount exceeds the outstanding balance.';
    }
    return null;
  } on FormatException catch (e) {
    return e.message;
  }
}
