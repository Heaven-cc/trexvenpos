import 'package:flutter/material.dart';

/// Layout-matched placeholders for initial data reads.
/// Each TREXVEN application owns its own copy of this component.
enum TrexvenSkeletonKind {
  dashboard,
  inventory,
  financeSummary,
  financeChart,
  financeTransactions,
  intelligence,
  employees,
  salesHistory,
  expenses,
  operations,
}

class TrexvenSkeleton extends StatefulWidget {
  const TrexvenSkeleton({
    super.key,
    required this.kind,
    this.scrollable = true,
    this.padding = const EdgeInsets.all(16),
  });

  final TrexvenSkeletonKind kind;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  State<TrexvenSkeleton> createState() => _TrexvenSkeletonState();
}

class _TrexvenSkeletonState extends State<TrexvenSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _shape({double? width, double height = 12, double radius = 7}) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.20 : 0.13,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _line(double fraction, {double height = 11}) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: fraction,
    child: _shape(height: height),
  );

  Widget _space([double height = 12]) => SizedBox(height: height);

  Widget _panel(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _metric() => _panel([
    _line(0.65, height: 9),
    _space(12),
    _line(0.86, height: 19),
    _space(8),
    _line(0.5, height: 8),
  ]);

  Widget _metrics() => Row(children: [
    Expanded(child: _metric()),
    const SizedBox(width: 10),
    Expanded(child: _metric()),
  ]);

  Widget _listRow() => _panel([
    Row(children: [
      _shape(width: 38, height: 38, radius: 10),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(0.78),
          _space(8),
          _line(0.48, height: 9),
        ],
      )),
      const SizedBox(width: 12),
      _shape(width: 52, height: 13),
    ]),
  ]);

  Widget _rows(int count) => Column(
    children: [
      for (var i = 0; i < count; i++) ...[
        _listRow(),
        if (i < count - 1) _space(10),
      ],
    ],
  );

  Widget _filters() => Row(children: [
    _shape(width: 58, height: 30, radius: 16),
    const SizedBox(width: 8),
    _shape(width: 82, height: 30, radius: 16),
    const SizedBox(width: 8),
    _shape(width: 64, height: 30, radius: 16),
  ]);

  Widget _chart() => _panel([
    _line(0.42),
    _space(18),
    SizedBox(height: 118, child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in <double>[42, 62, 51, 88, 73, 108, 91, 116])
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _shape(height: h, radius: 5),
          )),
      ],
    )),
  ]);

  Widget _content() {
    switch (widget.kind) {
      case TrexvenSkeletonKind.dashboard:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _line(0.52, height: 19),
          _space(7),
          _line(0.35),
          _space(20),
          _panel([_line(0.42), _space(16), _line(0.66, height: 26), _space(12), _line(0.50)]),
          _space(18),
          _line(0.32, height: 15),
          _space(10),
          _metrics(),
          _space(10),
          _metrics(),
          _space(18),
          _line(0.44, height: 15),
          _space(10),
          _metrics(),
        ]);
      case TrexvenSkeletonKind.inventory:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _line(0.46, height: 20),
          _space(12),
          _shape(height: 44, radius: 12),
          _space(14),
          _metrics(),
          _space(14),
          _filters(),
          _space(15),
          _rows(5),
        ]);
      case TrexvenSkeletonKind.financeSummary:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _line(0.50),
          _space(13),
          _line(0.72, height: 24),
          _space(14),
          _line(0.40),
        ]);
      case TrexvenSkeletonKind.financeChart:
        return _chart();
      case TrexvenSkeletonKind.financeTransactions:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _line(0.44, height: 14),
          _space(15),
          _rows(3),
        ]);
      case TrexvenSkeletonKind.intelligence:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _shape(height: 40, radius: 12),
          _space(16),
          _panel([_shape(height: 140, radius: 12), _space(14), _line(0.66), _space(9), _line(0.38)]),
          _space(12),
          _metrics(),
          _space(16),
          _line(0.42, height: 15),
          _space(12),
          _rows(3),
        ]);
      case TrexvenSkeletonKind.employees:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _line(0.44, height: 20),
          _space(15),
          _metrics(),
          _space(18),
          _shape(height: 44, radius: 12),
          _space(14),
          _rows(5),
        ]);
      case TrexvenSkeletonKind.salesHistory:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _line(0.58),
          _space(12),
          _shape(height: 46, radius: 12),
          _space(14),
          _filters(),
          _space(20),
          _line(0.42, height: 16),
          _space(14),
          _rows(5),
        ]);
      case TrexvenSkeletonKind.expenses:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _shape(height: 48, radius: 12),
          _space(14),
          _shape(height: 48, radius: 12),
          _space(14),
          _shape(height: 82, radius: 12),
          _space(16),
          _shape(height: 46, radius: 12),
        ]);
      case TrexvenSkeletonKind.operations:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _line(0.45, height: 18),
          _space(16),
          _metrics(),
          _space(18),
          _filters(),
          _space(14),
          _rows(4),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: widget.padding, child: _content());
    return Semantics(
      label: 'Loading content',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulse,
          child: widget.scrollable
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [content],
                )
              : content,
          builder: (context, child) => Opacity(
            opacity: MediaQuery.disableAnimationsOf(context)
                ? 1
                : 0.75 + 0.25 * _pulse.value,
            child: child,
          ),
        ),
      ),
    );
  }
}
