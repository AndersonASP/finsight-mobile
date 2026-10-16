import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/today_navigation_provider.dart';
import '../theme/app_colors.dart';

/// A little calendar-page icon showing today's day number. Tapping it jumps
/// to today's row on the Saldos screen, from anywhere in the app.
class TodayButton extends ConsumerWidget {
  const TodayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now().day;

    return IconButton(
      tooltip: 'Ir para hoje',
      onPressed: () => ref.read(goToTodaySignalProvider.notifier).state++,
      icon: SizedBox(
        width: 34,
        height: 34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.saida,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
              ),
              alignment: Alignment.center,
              child: Text(
                '$today',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, height: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
