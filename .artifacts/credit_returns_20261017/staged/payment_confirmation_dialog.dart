import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'operations_client.dart';
import 'customer_presentation.dart';
import 'text_controller_scope.dart';

class PaymentDraft {
  final List<Map<String, dynamic>> payments;
  final Map<String, dynamic>? credit;

  PaymentDraft(this.payments, this.credit);
}

Future<PaymentDraft?> confirmPayment(
  BuildContext context,
  double total,
  String method, {
  bool offline = false,
  bool cashAllowed = true,
  bool recovery = false,
  bool allowCredit = true,
  DateTime? businessDate,
}) async {
  const navy = Color(0xFF14213D);
  const blue = Color(0xFF2864F0);
  const muted = Color(0xFF71809A);
  const background = Color(0xFFF5F7FC);
  const border = Color(0xFFE5EAF2);

  final canonical = switch (method.toLowerCase()) {
    'transfer' || 'bank_transfer' => 'bank_transfer',
    'pos terminal' || 'card' => 'card',
    _ => 'cash',
  };

  final amounts = {
    for (final m in ['cash', 'bank_transfer', 'card'])
      m: TextEditingController(
        text:
            method != 'credit' && m == canonical && (m != 'cash' || cashAllowed)
            ? total.toStringAsFixed(2)
            : '0',
      ),
  };

  final evidence = {
    for (final m in ['bank_transfer', 'card']) m: TextEditingController(),
  };

  final name = TextEditingController();
  final contact = TextEditingController();
  final due = TextEditingController();

  var credit = method == 'credit' && allowCredit && !offline;
  var confirmed = false;
  String? error;

  int amountCents(String key) {
    if (offline && key != 'cash') return 0;

    return OperationsClient.moneyCents(amounts[key]!.text, allowZero: true);
  }

  int paidCents() {
    var result = 0;

    for (final key in amounts.keys) {
      result += amountCents(key);
    }

    return result;
  }

  String money(int cents) {
    final amount = (cents / 100).toStringAsFixed(2);
    final parts = amount.split('.');
    final digits = parts.first;

    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    return '${buffer.toString()}.${parts.last}';
  }

  final fullCents = (total * 100).round();

  Widget field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool numeric = false,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      style: const TextStyle(
        color: navy,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: muted, fontSize: 12),
        hintStyle: const TextStyle(color: muted, fontSize: 12),
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: blue, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: border),
        ),
      ),
    );
  }

  Widget paymentSection({
    required String paymentMethod,
    required String title,
    required IconData icon,
    required StateSetter update,
  }) {
    final isCash = paymentMethod == 'cash';
    final enabled = !isCash || cashAllowed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: blue, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isCash && !cashAllowed)
                const Text(
                  'Drawer required',
                  style: TextStyle(
                    color: Color(0xFFCB4D4D),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          field(
            controller: amounts[paymentMethod]!,
            label: 'Amount received',
            numeric: true,
            enabled: enabled,
            onChanged: (_) => update(() => error = null),
          ),
          if (!isCash) ...[
            const SizedBox(height: 10),
            field(
              controller: evidence[paymentMethod]!,
              label: 'Verified payment reference',
              hint: 'Bank or terminal reference',
              onChanged: (_) => update(() => error = null),
            ),
          ],
        ],
      ),
    );
  }

  final result = await showDialog<PaymentDraft>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return TextControllerScope(
        controllers: [
          ...amounts.values,
          ...evidence.values,
          name,
          contact,
          due,
        ],
        child: StatefulBuilder(
          builder: (dialogContext, update) {
            int? paid;

            try {
              paid = paidCents();
            } catch (_) {
              paid = null;
            }

            final remaining = paid == null ? null : fullCents - paid;

            return Dialog(
              backgroundColor: background,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 22,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 470,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.88,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 17, 12, 13),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Confirm Payment',
                              style: TextStyle(
                                color: navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: navy,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SALE TOTAL',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    money(fullCents),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 13),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Recorded',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              paid == null
                                                  ? 'Invalid amount'
                                                  : money(paid),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Remaining',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            remaining == null
                                                ? '—'
                                                : money(remaining),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (offline)
                              _PaymentNotice(
                                icon: Icons.wifi_off_rounded,
                                text:
                                    'Offline sale: cash only. '
                                    'Payment will remain pending sync.',
                              ),
                            if (recovery)
                              _PaymentNotice(
                                icon: Icons.verified_outlined,
                                text:
                                    'Verify the original payment. '
                                    'Do not collect payment again. '
                                    'The original receipt and request '
                                    'key must be retained.',
                              ),
                            if (!offline && !recovery)
                              const _PaymentNotice(
                                icon: Icons.info_outline_rounded,
                                text:
                                    'Enter only money actually received. '
                                    'Bank transfers and terminal payments '
                                    'must be independently verified.',
                              ),
                            const SizedBox(height: 15),
                            const Text(
                              'Payment breakdown',
                              style: TextStyle(
                                color: navy,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            paymentSection(
                              paymentMethod: 'cash',
                              title: 'Cash',
                              icon: Icons.payments_outlined,
                              update: update,
                            ),
                            if (!offline) ...[
                              paymentSection(
                                paymentMethod: 'bank_transfer',
                                title: 'Bank Transfer',
                                icon: Icons.account_balance_outlined,
                                update: update,
                              ),
                              paymentSection(
                                paymentMethod: 'card',
                                title: 'POS Terminal',
                                icon: Icons.credit_card_outlined,
                                update: update,
                              ),
                            ],
                            if (!offline && allowCredit) ...[
                              const SizedBox(height: 5),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: border),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: Column(
                                    children: [
                                      CheckboxListTile(
                                        value: credit,
                                        activeColor: blue,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 9,
                                            ),
                                        title: const Text(
                                          'Request credit approval',
                                          style: TextStyle(
                                            color: navy,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: const Text(
                                          'For an unpaid balance',
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 10,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          update(() {
                                            credit = value ?? false;
                                            error = null;
                                          });
                                        },
                                      ),
                                      if (credit)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            13,
                                            0,
                                            13,
                                            13,
                                          ),
                                          child: Column(
                                            children: [
                                              field(
                                                controller: name,
                                                label: 'Debtor name',
                                              ),
                                              const SizedBox(height: 9),
                                              field(
                                                controller: contact,
                                                label: 'Contact reference',
                                              ),
                                              const SizedBox(height: 9),
                                              field(
                                                controller: due,
                                                label: 'Due date (YYYY-MM-DD)',
                                                hint: '2026-12-31',
                                              ),
                                              const SizedBox(height: 9),
                                              const Text(
                                                'The original sale request '
                                                'is retained while an owner '
                                                'or authorized manager '
                                                'reviews the credit request.',
                                                style: TextStyle(
                                                  color: muted,
                                                  fontSize: 10,
                                                  height: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: border),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  value: confirmed,
                                  activeColor: blue,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  title: const Text(
                                    'I have verified the payment',
                                    style: TextStyle(
                                      color: navy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Cash was received or the bank/'
                                    'terminal transaction was confirmed. '
                                    'A screenshot alone is insufficient. '
                                    'This records your confirmation, not provider-verified settlement.',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 10,
                                      height: 1.4,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    update(() {
                                      confirmed = value ?? false;
                                      error = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                error!,
                                style: const TextStyle(
                                  color: Color(0xFFCB4D4D),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: navy,
                                minimumSize: const Size(0, 46),
                                side: const BorderSide(color: border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: !confirmed
                                  ? null
                                  : () {
                                      try {
                                        final payments =
                                            <Map<String, dynamic>>[];
                                        var paid = 0;

                                        for (final m in amounts.keys) {
                                          final cents = amountCents(m);

                                          paid += cents;

                                          if (m == 'cash' &&
                                              cents > 0 &&
                                              !cashAllowed) {
                                            throw const FormatException(
                                              'Join an assigned drawer '
                                              'before receiving cash.',
                                            );
                                          }

                                          if (cents > 0 ||
                                              (total == 0 && m == 'cash')) {
                                            if (m != 'cash' &&
                                                evidence[m]!.text
                                                    .trim()
                                                    .isEmpty) {
                                              throw const FormatException(
                                                'External confirmation '
                                                'reference required.',
                                              );
                                            }

                                            payments.add({
                                              'method': m,
                                              'amount': cents / 100,
                                              'confirmed': true,
                                              if (m != 'cash')
                                                'evidence': evidence[m]!.text
                                                    .trim(),
                                            });
                                          }
                                        }

                                        if (paid > fullCents ||
                                            (!credit && paid != fullCents) ||
                                            (offline && paid != fullCents)) {
                                          throw const FormatException(
                                            'Confirmed payments must '
                                            'match the sale total unless '
                                            'credit approval is requested.',
                                          );
                                        }

                                        Map<String, dynamic>? debtor;

                                        if (credit) {
                                          final dueText = due.text.trim();
                                          final parsed = DateTime.tryParse(
                                            dueText,
                                          );

                                          final validDate =
                                              RegExp(
                                                r'^\d{4}-\d{2}-\d{2}$',
                                              ).hasMatch(dueText) &&
                                              parsed != null &&
                                              parsed
                                                      .toIso8601String()
                                                      .substring(0, 10) ==
                                                  dueText;

                                          if (paid >= fullCents ||
                                              name.text.trim().isEmpty ||
                                              contact.text.trim().isEmpty ||
                                              !validDate ||
                                              (businessDate != null &&
                                                  parsed.isBefore(
                                                    businessDate,
                                                  ))) {
                                            throw const FormatException(
                                              'An unpaid balance, '
                                              'debtor name, contact and '
                                              'valid due date are required.',
                                            );
                                          }

                                          debtor = {
                                            'debtor_name': name.text.trim(),
                                            'contact': contact.text.trim(),
                                            'due_date': dueText,
                                          };
                                        }

                                        Navigator.pop(
                                          dialogContext,
                                          PaymentDraft(payments, debtor),
                                        );
                                      } catch (e) {
                                        update(() {
                                          error = e is FormatException
                                              ? e.message
                                              : CustomerPresentation.error(e);
                                        });
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: blue,
                                disabledBackgroundColor: blue.withValues(
                                  alpha: 0.35,
                                ),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              child: Text(
                                credit
                                    ? 'Request Approval'
                                    : offline
                                    ? 'Record Cash'
                                    : 'Confirm Payment',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  return result;
}

class _PaymentNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PaymentNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2864F0), size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF14213D),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
