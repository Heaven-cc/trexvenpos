import 'package:flutter/material.dart';
import '../../ui/trexven_ui.dart';

/// No insert is offered: production has no branch-attributed expense contract.
class PosExpenseSupportScreen extends StatelessWidget {
  const PosExpenseSupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Expenses')),
    body: const PosStateView(title: 'Expense recording is unavailable',
      icon: Icons.account_balance_wallet_outlined,
      message: 'This POS needs a supported expense service before recording cash expenses. '
        'Ask your owner to arrange the integration. No expense has been recorded.'));
}
