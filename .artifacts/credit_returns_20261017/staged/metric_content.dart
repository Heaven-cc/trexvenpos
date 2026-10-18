import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';

enum MetricLayout { compact, standard, hero }

/// Content-driven KPI layout. Callers retain their existing card decoration,
/// typography and interactions; no proposed fixed card heights are imposed.
class MetricContent extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color? color;
  final TextStyle? valueStyle, titleStyle;
  final MetricLayout layout;
  const MetricContent({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.valueStyle,
    this.titleStyle,
    this.layout = MetricLayout.compact,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: valueStyle ?? theme.textTheme.titleLarge,
          softWrap: true,
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: titleStyle ?? theme.textTheme.bodySmall,
          softWrap: true,
        ),
      ],
    );
    final badge = Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Icon(icon, size: 20, color: color ?? theme.colorScheme.primary),
    );
    return Semantics(
      label: '$title: $value',
      excludeSemantics: true,
      child: layout == MetricLayout.compact
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge,
                SizedBox(width: 12),
                Expanded(child: values),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [badge, SizedBox(height: 12), values],
            ),
    );
  }
}
