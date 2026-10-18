import 'package:flutter/material.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import '../theme/pos_theme.dart';

class PosSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const PosSurface({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

class PosGlassCard extends StatelessWidget {
  final Widget child;
  const PosGlassCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
      gradient: PosThemeData.premiumGradient,
      border: Border.all(color: PosThemeData.accent.withValues(alpha: .3))),
    child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white),
      child: IconTheme(data: const IconThemeData(color: Colors.white), child: child)));
}

class PosStatus extends StatelessWidget {
  final String label;
  final Color? color;
  final bool success;
  const PosStatus(this.label, {super.key, this.color, this.success = false});
  @override
  Widget build(BuildContext context) {
    final ink = color ?? (success ? Theme.of(context).trexvenColors.success : null)
        ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: ink.withValues(alpha: .1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w600)));
  }
}

class PosActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
  const PosActionRow({super.key, required this.icon, required this.title,
    this.subtitle, this.onTap, this.trailing, this.destructive = false});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 21, color: destructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.secondary)),
    title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
      color: destructive ? Theme.of(context).colorScheme.error : null)),
    subtitle: subtitle == null ? null : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
    trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded, size: 20)),
    onTap: onTap);
}

class PosStateView extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  const PosStateView({super.key, required this.title, this.message,
    this.icon = Icons.inbox_outlined, this.action});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) =>
    SingleChildScrollView(child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: box.hasBoundedHeight ? box.maxHeight : 0),
      child: Center(child: TrexvenEmptyState(title: title, message: message, icon: icon, action: action)))));
}
