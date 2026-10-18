
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Main metric card used for prominent dashboard figures.
class TrexvenHeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final Widget? supporting;
  final bool compact;

  const TrexvenHeroMetric({
    super.key,
    required this.label,
    required this.value,
    this.supporting,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111B35),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TrexvenTypography.label.copyWith(
              color: const Color(0xFFB0BED0),
            ),
          ),
          SizedBox(height: compact ? 8 : 16),
          Text(
            value,
            style: TrexvenTypography.display.copyWith(
              color: Colors.white,
            ),
          ),
          if (supporting != null) ...[
            SizedBox(height: compact ? 6 : 8),
            DefaultTextStyle.merge(
              style: TrexvenTypography.caption.copyWith(
                color: const Color(0xFFB0BED0),
              ),
              child: supporting!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Standard KPI card with an optional compact layout.
class TrexvenMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final bool valueFirst;
  final bool compact;

  const TrexvenMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.valueFirst = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = Text(
      label,
      style: theme.textTheme.bodySmall,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final metric = Text(
      value,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    return TrexvenCard(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          valueFirst ? metric : title,
          SizedBox(height: compact ? 4 : 8),
          valueFirst ? title : metric,
        ],
      ),
    );
  }
}

/// Responsive product row.
///
/// Keeps product names and amounts readable on narrow screens
/// and when accessibility text scaling is enabled.
class TrexvenProductRow extends StatelessWidget {
  final String name;
  final String amount;
  final Widget subtitle;
  final Widget? leading;

  const TrexvenProductRow({
    super.key,
    required this.name,
    required this.amount,
    required this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        subtitle,
      ],
    );

    final price = Text(
      amount,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(16) > 20;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: stacked
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 8),
                  price,
                ],
              )
                  : Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 12),
                  Flexible(child: price),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shared borderless card.
///
/// Uses the global CardTheme for background, shape and elevation.
class TrexvenCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const TrexvenCard({
    super.key,
    required this.child,
    this.padding = TrexvenSpacing.cardPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Shared dialog wrapper.
class TrexvenDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  const TrexvenDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title,
      scrollable: true,
      content: content,
      actions: actions,
    );
  }
}

/// Shared bottom-sheet wrapper.
///
/// Allows scrolling when the keyboard is visible.
class TrexvenBottomSheet extends StatelessWidget {
  final Widget child;

  const TrexvenBottomSheet({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: TrexvenSpacing.pagePadding.add(
          EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Standard loading state.
class TrexvenLoading extends StatelessWidget {
  final String? message;

  const TrexvenLoading({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: TrexvenSpacing.cardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: theme.colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared empty state.
class TrexvenEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  const TrexvenEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: TrexvenSpacing.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Shared error state with optional retry action.
class TrexvenErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const TrexvenErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return TrexvenEmptyState(
      title: 'Unable to load',
      message: message,
      icon: Icons.error_outline,
      action: onRetry == null
          ? null
          : TextButton(
        onPressed: onRetry,
        child: const Text('Retry'),
      ),
    );
  }
}
