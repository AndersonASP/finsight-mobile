import 'package:flutter/material.dart';

class HorizontalBarItem {
  const HorizontalBarItem({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.color,
  });

  final String label;
  final double value;
  final String valueLabel;
  final Color color;
}

/// A single-series ranked bar list (e.g. "gastos por categoria") — each row
/// is already direct-labeled with its name and value, so no legend is
/// needed for a single series. Reuses [LinearProgressIndicator] (already the
/// app's bar-fill primitive, see the goals screen) instead of a bespoke
/// painter.
class HorizontalBarList extends StatelessWidget {
  const HorizontalBarList({super.key, required this.items});

  final List<HorizontalBarItem> items;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.valueLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxValue == 0 ? 0 : item.value / maxValue,
                    minHeight: 10,
                    color: item.color,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
