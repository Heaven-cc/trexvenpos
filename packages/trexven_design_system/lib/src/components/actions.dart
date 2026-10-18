import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/presentation.dart';

class TrexvenHeaderAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const TrexvenHeaderAction({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 340 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;
    return compact
        ? IconButton(tooltip: label, onPressed: onPressed, icon: Icon(icon))
        : TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
  }
}

class TrexvenPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;
  final BorderRadius? borderRadius;
  final Color? rippleColor;

  const TrexvenPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleAmount = 0.98,
    this.borderRadius,
    this.rippleColor,
  });

  @override
  State<TrexvenPressable> createState() => _TrexvenPressableState();
}

class _TrexvenPressableState extends State<TrexvenPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleAmount,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TrexvenPresentation.isPos(context)) {
      _controller.duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero : const Duration(milliseconds: 150);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          fit: StackFit.passthrough, // Let the children determine the size
          children: [
            widget.child,
            if (widget.onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: widget.borderRadius ?? BorderRadius.zero,
                    highlightColor: (widget.rippleColor ?? brandBlue)
                        .withValues(alpha: 0.05),
                    splashColor: (widget.rippleColor ?? brandBlue).withValues(
                      alpha: 0.1,
                    ),
                    onTap: widget.onTap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TrexvenTapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final double? width;
  final double? height;

  const TrexvenTapCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius = TrexvenRadii.card,
    this.backgroundColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surface;

    return TrexvenPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.2 : 0.02,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class TrexvenSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;

  const TrexvenSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedIconColor = iconColor ?? theme.colorScheme.primary;
    final iconBgColor = resolvedIconColor.withValues(alpha: 0.1);
    final titleColor = theme.colorScheme.onSurface;
    final subtitleColor = theme.trexvenColors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: resolvedIconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.trexvenColors.muted?.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrexvenButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;

  const TrexvenButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                foregroundColor ?? theme.colorScheme.onPrimary,
              ),
            ),
          )
        else ...[
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(child: Text(text, textAlign: TextAlign.center)),
        ],
      ],
    );

    return SizedBox(
      width: width ?? double.infinity,
      child: TrexvenPressable(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(TrexvenRadii.field),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? theme.colorScheme.primary,
            foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
          ),
          child: content,
        ),
      ),
    );
  }
}
