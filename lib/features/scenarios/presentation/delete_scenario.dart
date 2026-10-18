import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/scenarios_providers.dart';
import '../data/scenarios_repository.dart';

/// Asks before removing simulação [scenarioId] for good, then deletes it and
/// refreshes the list. Returns whether it was deleted. Real lançamentos of
/// an already-confirmed simulação aren't touched.
Future<bool> confirmAndDeleteScenario(
  BuildContext context,
  WidgetRef ref, {
  required String scenarioId,
  required String name,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Excluir simulação?'),
      content: Text(
        'Remover "$name" permanentemente. Lançamentos reais já confirmados '
        'a partir dela não são afetados.',
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Excluir'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    await ref.read(scenariosRepositoryProvider).delete(scenarioId);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('Não foi possível excluir: $e')));
    }
    return false;
  } finally {
    ref.invalidate(scenariosListProvider);
  }
  return true;
}
