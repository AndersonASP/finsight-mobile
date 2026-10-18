import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../ledger/data/saldos_column_filter.dart';
import '../../ledger/presentation/monthly_balance_table.dart';
import '../../transactions/data/transaction_type.dart';
import '../application/scenarios_providers.dart';
import '../data/scenario.dart';
import '../data/scenarios_repository.dart';
import 'add_scenario_purchase_sheet.dart';
import 'add_scenario_transaction_sheet.dart';
import 'delete_scenario.dart';
import 'scenario_day_detail_screen.dart';

/// Shows a "o que simular?" picker (the same five types as the Saldos
/// table's long-press dispatch) then opens the matching scenario-scoped add
/// sheet — used by the FAB and by [ScenarioDayDetailScreen]'s own "+".
Future<void> showAddScenarioItemEntryPoint(
  BuildContext context,
  String scenarioId, {
  DateTime? initialDate,
}) async {
  final type = await _showScenarioTypePickerSheet(context);
  if (type == null || !context.mounted) return;
  _openAddScenarioItemFor(
    context,
    scenarioId,
    type,
    initialDate ?? DateTime.now(),
  );
}

void _openAddScenarioItemFor(
  BuildContext context,
  String scenarioId,
  SaldosColumnFilter type,
  DateTime date,
) {
  switch (type) {
    case SaldosColumnFilter.cartao:
      showAddScenarioPurchaseSheet(context, scenarioId, initialDate: date);
    case SaldosColumnFilter.entrada:
      showAddScenarioTransactionSheet(
        context,
        scenarioId,
        initialType: FinTransactionType.entrada,
        initialDate: date,
      );
    case SaldosColumnFilter.saida:
      showAddScenarioTransactionSheet(
        context,
        scenarioId,
        initialType: FinTransactionType.saida,
        initialDate: date,
      );
    case SaldosColumnFilter.diario:
      showAddScenarioTransactionSheet(
        context,
        scenarioId,
        initialType: FinTransactionType.diario,
        initialDate: date,
      );
    case SaldosColumnFilter.economia:
      showAddScenarioTransactionSheet(
        context,
        scenarioId,
        initialType: FinTransactionType.economia,
        initialDate: date,
      );
    case SaldosColumnFilter.todas:
      break; // never offered by the picker below.
  }
}

Future<SaldosColumnFilter?> _showScenarioTypePickerSheet(BuildContext context) {
  return showModalBottomSheet<SaldosColumnFilter>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'O que simular?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          for (final type in SaldosColumnFilter.values.where(
            (f) => f != SaldosColumnFilter.todas,
          ))
            ListTile(
              leading: CircleAvatar(
                backgroundColor: type.color,
                child: Icon(type.icon, color: Colors.white, size: 18),
              ),
              title: Text(type.label),
              onTap: () => Navigator.of(sheetContext).pop(type),
            ),
        ],
      ),
    ),
  );
}

class ScenarioDetailScreen extends ConsumerWidget {
  const ScenarioDetailScreen({super.key, required this.scenarioId});

  final String scenarioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(scenarioDetailProvider(scenarioId));
    final month = ref.watch(scenarioMonthProvider);
    final filter = ref.watch(scenarioColumnFilterProvider);
    final daysAsync = ref.watch(scenarioDailyBalanceProvider(scenarioId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cenário'),
        actions: [
          if (detailAsync.value case final detail?)
            IconButton(
              tooltip: 'Excluir simulação',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final deleted = await confirmAndDeleteScenario(
                  context,
                  ref,
                  scenarioId: scenarioId,
                  name: detail['name'] as String? ?? 'Cenário',
                );
                if (deleted && context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      floatingActionButton: detailAsync.maybeWhen(
        data: (detail) => (detail['status'] as String) == 'draft'
            ? FloatingActionButton(
                onPressed: () =>
                    showAddScenarioItemEntryPoint(context, scenarioId),
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail['name'] as String,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status.label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (status == ScenarioStatus.draft) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref
                                    .read(scenariosRepositoryProvider)
                                    .discard(scenarioId);
                                ref.invalidate(scenariosListProvider);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text('Descartar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await ref
                                    .read(scenariosRepositoryProvider)
                                    .confirm(scenarioId);
                                ref.invalidate(scenariosListProvider);
                                ref.invalidate(
                                  scenarioDetailProvider(scenarioId),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Cenário confirmado. Dados reais atualizados.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Confirmar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () =>
                          ref.read(scenarioMonthProvider.notifier).state =
                              month.previousMonth,
                    ),
                    Text(
                      formatMonth(month),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () =>
                          ref.read(scenarioMonthProvider.notifier).state =
                              month.nextMonth,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: MonthlyBalanceTable(
                  daysAsync: daysAsync,
                  filter: filter,
                  onFilterChanged: (value) =>
                      ref.read(scenarioColumnFilterProvider.notifier).state =
                          value,
                  onCellTap: (type, date) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScenarioDayDetailScreen(
                        scenarioId: scenarioId,
                        date: date,
                      ),
                    ),
                  ),
                  onCellLongPress: status == ScenarioStatus.draft
                      ? (type, date) => _openAddScenarioItemFor(
                          context,
                          scenarioId,
                          type,
                          date,
                        )
                      : (type, date) {}, // confirmed/discarded: read-only
                  onSaldoTap: (date) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScenarioDayDetailScreen(
                        scenarioId: scenarioId,
                        date: date,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
