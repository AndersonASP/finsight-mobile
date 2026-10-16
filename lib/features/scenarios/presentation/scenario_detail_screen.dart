import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../application/scenarios_providers.dart';
import '../data/scenario.dart';
import '../data/scenarios_repository.dart';
import 'add_scenario_transaction_sheet.dart';

class ScenarioDetailScreen extends ConsumerWidget {
  const ScenarioDetailScreen({super.key, required this.scenarioId});

  final String scenarioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(scenarioDetailProvider(scenarioId));
    final projectionAsync = ref.watch(scenarioProjectionProvider(scenarioId));

    return Scaffold(
      appBar: AppBar(title: const Text('Cenário')),
      floatingActionButton: detailAsync.maybeWhen(
        data: (detail) => (detail['status'] as String) == 'draft'
            ? FloatingActionButton(
                onPressed: () => showAddScenarioTransactionSheet(context, scenarioId),
                child: const Icon(Icons.add),
              )
            : null,
        orElse: () => null,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (detail) {
          final status = ScenarioStatusX.fromApi(detail['status'] as String);
          final transactions = detail['transactions'] as List;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(detail['name'] as String, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(status.label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              _ProjectionCard(projectionAsync: projectionAsync),
              const SizedBox(height: 20),
              Text('Itens simulados', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (transactions.isEmpty) const Text('Nenhum item ainda.'),
              for (final t in transactions)
                Card(
                  child: ListTile(
                    title: Text((t['description'] as String?) ?? (t['type'] as String)),
                    subtitle: Text(t['date'] as String),
                    trailing: Text(formatCurrency(t['amount'] as String)),
                  ),
                ),
              if (status == ScenarioStatus.draft) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await ref.read(scenariosRepositoryProvider).discard(scenarioId);
                          ref.invalidate(scenariosListProvider);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('Descartar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await ref.read(scenariosRepositoryProvider).confirm(scenarioId);
                          ref.invalidate(scenariosListProvider);
                          ref.invalidate(scenarioDetailProvider(scenarioId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(const SnackBar(content: Text('Cenário confirmado — dados reais atualizados.')));
                          }
                        },
                        child: const Text('Confirmar'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.projectionAsync});

  final AsyncValue<ScenarioProjection> projectionAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: projectionAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
          error: (error, _) => Text('Erro ao calcular projeção: $error'),
          data: (projection) {
            final before = projection.before.last;
            final after = projection.after.last;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Projeção (próximos 30 dias)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ProjectionColumn(label: 'Antes', balance: before.balance, deficitDays: projection.deficitDaysBefore),
                    ),
                    const Icon(Icons.arrow_forward, size: 18),
                    Expanded(
                      child: _ProjectionColumn(label: 'Depois', balance: after.balance, deficitDays: projection.deficitDaysAfter),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('% economizado'),
                    Text('${formatPercent(projection.savingsImpact.percentBefore)} → ${formatPercent(projection.savingsImpact.percentAfter)}'),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProjectionColumn extends StatelessWidget {
  const _ProjectionColumn({required this.label, required this.balance, required this.deficitDays});

  final String label;
  final String balance;
  final int deficitDays;

  @override
  Widget build(BuildContext context) {
    final isNegative = double.parse(balance) < 0;
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          formatCurrency(balance),
          style: TextStyle(fontWeight: FontWeight.bold, color: isNegative ? AppColors.deficit : null),
        ),
        if (deficitDays > 0) Text('$deficitDays dia(s) negativo(s)', style: const TextStyle(color: AppColors.deficit, fontSize: 12)),
      ],
    );
  }
}
