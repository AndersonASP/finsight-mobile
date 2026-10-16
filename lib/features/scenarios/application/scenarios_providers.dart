import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/scenario.dart';
import '../data/scenarios_repository.dart';

final scenariosListProvider = FutureProvider.autoDispose<List<Scenario>>((ref) {
  return ref.watch(scenariosRepositoryProvider).list();
});

final scenarioDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, scenarioId) {
  return ref.watch(scenariosRepositoryProvider).detail(scenarioId);
});

/// Projects 30 days from today — enough to surface near-term deficits without
/// asking the user to pick a date range for a first version of this screen.
final scenarioProjectionProvider = FutureProvider.autoDispose.family<ScenarioProjection, String>((ref, scenarioId) {
  final now = DateTime.now();
  return ref
      .watch(scenariosRepositoryProvider)
      .projection(scenarioId: scenarioId, from: now, to: now.add(const Duration(days: 30)));
});
