import 'package:flutter/material.dart';

class HelpSafeRecoveryScreen extends StatefulWidget {
  const HelpSafeRecoveryScreen({super.key});
  @override
  State<HelpSafeRecoveryScreen> createState() => _HelpSafeRecoveryScreenState();
}

class _HelpSafeRecoveryScreenState extends State<HelpSafeRecoveryScreen> {
  bool help = false;
  Widget guide(String title, String subtitle, IconData icon, List<String> steps) =>
    Card(child: ExpansionTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. '),
              Expanded(child: Text(steps[i])),
            ])),
      ],
    ));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Safe Recovery')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(color: colors.primaryContainer, child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.shield_outlined, color: colors.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Protect your transactions', style: TextStyle(
                color: colors.onPrimaryContainer, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Check the original sale status before retrying. Never collect the same payment twice.',
                style: TextStyle(color: colors.onPrimaryContainer)),
            ])),
          ]),
        )),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Recovery Guides')),
            ButtonSegment(value: true, label: Text('Get Help')),
          ],
          selected: {help},
          onSelectionChanged: (value) => setState(() => help = value.first),
        ),
        const SizedBox(height: 14),
        if (!help) ...[
          const Text('What do you need help with?',
            style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          guide('Pending or interrupted sale', 'Checkout stopped or app closed',
            Icons.receipt_long_outlined, [
              'Check whether the sale was completed before retrying.',
              'Use the existing pending-sale recovery workflow where available.',
              'Never charge the customer twice for the same sale.',
            ]),
          guide('Offline sales & synchronization', 'Transactions waiting to sync',
            Icons.wifi_off_outlined, [
              'Keep the original device and employee account available.',
              'Reconnect to the internet when possible.',
              'Use the existing sync or recovery workflow; do not delete local sales data.',
            ]),
          guide('Payment discrepancy', 'Customer paid but checkout is uncertain',
            Icons.account_balance_wallet_outlined, [
              'Do not collect another payment until the original transaction is checked.',
              'Review the original sale or recovery status.',
              'Contact an authorized manager or owner if the result is unclear.',
            ]),
          guide('Login & employee access', 'Password, account or permission issues',
            Icons.lock_outline, [
              'Check the employee ID and credentials.',
              'Use Change Password in My Settings when permitted.',
              'Contact the business owner for employee access changes.',
            ]),
        ] else Card(child: Padding(padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Need additional help?',
              style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Contact your business owner or authorized manager for access, transaction discrepancies, or issues that cannot be resolved safely.'),
            const SizedBox(height: 10),
            Text('Support tickets and live chat are not currently available.',
              style: TextStyle(color: colors.onSurfaceVariant)),
          ]),
        )),
        const SizedBox(height: 12),
        Card(child: ListTile(
          leading: Icon(Icons.warning_amber_rounded, color: colors.error),
          title: const Text('Before reinstalling or clearing app data'),
          subtitle: const Text('Unsynced sales and recovery information may exist only on this device. Do not clear storage or uninstall until recovery is confirmed.'),
        )),
      ]),
    );
  }
}
