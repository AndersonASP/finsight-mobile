import 'package:flutter/material.dart';

class BarSeries {
  const BarSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;

  /// One value per x-axis category, same length/order as the chart's `xLabels`.
  final List<double> values;
}

/// A small multi-series bar chart (1-2 series) for a handful of x categories
/// (months, or a couple of comparison bars per category) — never a second
/// y-axis: every series here shares the same R$ scale. A legend is shown
/// only when there's more than one series (a single series is already named
/// by the screen's own title/heading).
class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    super.key,
    required this.xLabels,
    required this.series,
    required this.valueFormatter,
    this.height = 180,
  });

  final List<String> xLabels;
  final List<BarSeries> series;
  final String Function(double) valueFormatter;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = series
        .expand((s) => s.values)
        .fold<double>(0, (max, v) => v.abs() > max ? v.abs() : max);
    // `height` is only the target *bar* height used for scaling — the value
    // label above each bar and the x-axis label below size themselves and
    // add on top, rather than being squeezed into a fixed total height
    // (that under-budgeting is exactly what caused bars to overflow their
    // box before).
    final scale = maxValue == 0 ? 0.0 : height / maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (series.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 16,
              children: [
                for (final s in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < xLabels.length; i++)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final s in series)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 1.5,
                            ),
                            child: _Bar(
                              value: s.values[i],
                              scale: scale,
                              color: s.color,
                              formatter: valueFormatter,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      xLabels[i],
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.scale,
    required this.color,
    required this.formatter,
  });

  final double value;
  final double scale;
  final Color color;
  final String Function(double) formatter;

  @override
  Widget build(BuildContext context) {
    final barHeight = value.abs() * scale;
    // Fixed width so a wide formatted value (e.g. "R$ 5.000,00") clips with
    // an ellipsis instead of forcing this bar — and its siblings in the same
    // group — wider than the chart column has room for.
    return SizedBox(
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (value != 0)
            Text(
              formatter(value),
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 2),
          Container(
            width: 16,
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
