import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../ledger/data/day_detail_item.dart';
import '../../ledger/data/saldos_column_filter.dart';
import '../application/scenarios_providers.dart';
import '../data/scenario.dart';
import '../data/scenarios_repository.dart';
import 'scenario_detail_screen.dart';

/// Mirrors ledger/presentation/day_detail_screen.dart, split into two
/// sections for one day of one scenario: the real items (read-only — a
/// simulation never edits history) and this scenario's own shadow items
/// (removable, via long-press).
class ScenarioDayDetailScreen extends ConsumerStatefulWidget {
  const ScenarioDayDetailScreen({
    super.key,
    required this.scenarioId,
    required this.date,
  });

  final String scenarioId;
  final DateTime date;

  @override
  ConsumerState<ScenarioDayDetailScreen> createState() =>
      _ScenarioDayDetailScreenState();
}

class _ScenarioDayDetailScreenState
    extends ConsumerState<ScenarioDayDetailScreen> {
  late DateTime _date = DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day,
  );

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      scenarioDayDetailProvider((widget.scenarioId, _date)),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              date: _date,
              onPreviousDay: () => setState(
                () => _date = _date.subtract(const Duration(days: 1)),
              ),
              onNextDay: () =>
                  setState(() => _date = _date.add(const Duration(days: 1))),
              onAdd: () => showAddScenarioItemEntryPoint(
                context,
                widget.scenarioId,
                initialDate: _date,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: detailAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erro: $error')),
                data: (detail) {
                  if (detail.real.isEmpty && detail.shadow.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma movimentação neste dia.'),
                    );
                  }
                  return ListView(
                    children: [
                      if (detail.shadow.isNotEmpty) ...[
                        const _SectionLabel('Simulado'),
                        for (final item in detail.shadow)
                          _ShadowItemTile(
                            scenarioId: widget.scenarioId,
                            item: item,
                          ),
                        const Divider(height: 1),
                      ],
                      if (detail.real.isNotEmpty) ...[
                        const _SectionLabel('Real'),
                        for (final item in detail.real)
                          _RealItemTile(item: item),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onAdd,
  });

  final DateTime date;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPreviousDay,
          ),
          Text(
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextDay,
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add), onPressed: onAdd),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

SaldosColumnFilter _columnFilterFromApi(String value) => switch (value) {
  'entrada' => SaldosColumnFilter.entrada,
  'saida' => SaldosColumnFilter.saida,
  'diario' => SaldosColumnFilter.diario,
  'economia' => SaldosColumnFilter.economia,
  'cartao' => SaldosColumnFilter.cartao,
  _ => SaldosColumnFilter.todas,
};

class _RealItemTile extends StatelessWidget {
  const _RealItemTile({required this.item});

  final DayDetailItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: item.type.color,
            child: Icon(item.type.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.description,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            formatCurrency(item.amount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ShadowItemTile extends ConsumerWidget {
  const _ShadowItemTile({required this.scenarioId, required this.item});

  final String scenarioId;
  final ScenarioShadowItem item;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover da simulação?'),
        content: Text('Remover "${item.description}" deste cenário.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repository = ref.read(scenariosRepositoryProvider);
    if (item.kind == 'purchase') {
      await repository.removePurchase(scenarioId, item.id);
    } else {
      await repository.removeTransaction(scenarioId, item.id);
    }
    final date = DateTime(item.date.year, item.date.month, item.date.day);
    ref.invalidate(scenarioDayDetailProvider((scenarioId, date)));
    ref.invalidate(scenarioDailyBalanceProvider(scenarioId));
    ref.invalidate(scenarioDetailProvider(scenarioId));
    ref.invalidate(scenarioProjectionProvider(scenarioId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = _columnFilterFromApi(item.type);
    return InkWell(
      onLongPress: () => _confirmDelete(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: type.color, width: 1.5),
              ),
              child: Icon(type.icon, size: 16, color: type.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.description,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Text(
              formatCurrency(item.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
