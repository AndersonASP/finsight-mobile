import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../data/savings_capacity.dart';

double _n(String value) => double.tryParse(value) ?? 0;

/// "Dá para guardar este mês": how much can still be moved to savings
/// without the account running short, against the target — honest even
/// when the target isn't reachable. Tapping explains the math.
class SavingsCapacityCard extends ConsumerWidget {
  const SavingsCapacityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capacity = ref.watch(savingsCapacityProvider).value;
    // Past months already have their "economizado" below; nothing to suggest.
    if (capacity == null || capacity.isPast || _n(capacity.entradas) <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final pode = _n(capacity.podeGuardarAgora);
    final reachesGoal = _n(capacity.faltaParaMeta) <= 0;
    final progress = _n(capacity.metaValor) <= 0
        ? 1.0
        : (_n(capacity.totalPossivel) / _n(capacity.metaValor)).clamp(0.0, 1.0);
    final color = reachesGoal ? AppColors.surplus : AppColors.metaAbaixo;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, capacity),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dá para guardar este mês',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatCurrency(capacity.podeGuardarAgora),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: pode > 0 ? AppColors.surplus : null,
                ),
              ),
              Text(_headline(capacity), style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress, color: color),
              const SizedBox(height: 4),
              Text(
                reachesGoal
                    ? 'Com isso você chega a ${_pct(capacity.percentPossivel)} da renda — '
                          'meta de ${capacity.metaPercent}% atingida'
                    : '${_pct(capacity.percentPossivel)} da renda · meta ${capacity.metaPercent}% '
                          '(${formatCurrency(capacity.metaValor)}) · faltam '
                          '${formatCurrency(capacity.faltaParaMeta)}',
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
              if (capacity.overspending.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Acima do seu normal este mês:',
                  style: theme.textTheme.labelMedium,
                ),
                for (final o in capacity.overspending)
                  Text(
                    '• ${o.categoryName}: +${formatCurrency(o.excess)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_destinationIcon(capacity.destino.kind), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Para onde: ${capacity.destino.title}',
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          _withCurrency(capacity.destino.detail),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _pct(String value) => '${_n(value).round()}%';

/// The API writes plain decimals ("Faltam 1234.56."); show them as R$.
String _withCurrency(String text) => text.replaceAllMapped(
  RegExp(r'(?<![\d,])(\d+\.\d{2})(?!\d)'),
  (m) => formatCurrency(m[1]!),
);

String _headline(SavingsCapacity c) {
  if (c.limitadoPor == 'saldo') {
    return _n(c.podeGuardarAgora) > 0
        ? 'Limitado pelo saldo: guardar mais faria faltar dinheiro antes do fim do mês.'
        : 'Agora não: o saldo projetado fica apertado antes do fim do mês.';
  }
  if (_n(c.sobraProjetada) <= 0) {
    return 'Pelas contas do mês não sobra nada para guardar.';
  }
  return 'É o que sobra no mês sem deixar a conta apertada.';
}

IconData _destinationIcon(String kind) => switch (kind) {
  'divida' => Icons.trending_down,
  'reserva' => Icons.shield_outlined,
  _ => Icons.trending_up,
};

void _showDetail(BuildContext context, SavingsCapacity c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      Widget row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              formatCurrency(value),
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Como chegamos nesse valor',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('1. Sobra do mês', style: theme.textTheme.titleSmall),
              row('Entradas', c.entradas),
              row('− Saídas fixas', c.saidas),
              row('− Cartão', c.cartao),
              row('− Diário até agora', c.diarioReal),
              row('− Diário previsto até o fim do mês', c.diarioPrevisto),
              row('− Já guardado', c.economiaFeita),
              row('= Sobra projetada', c.sobraProjetada, bold: true),
              const SizedBox(height: 16),
              Text('2. Teto de segurança', style: theme.textTheme.titleSmall),
              if (c.menorSaldoProjetado != null) ...[
                row(
                  'Menor saldo previsto até o fim do mês',
                  c.menorSaldoProjetado!,
                ),
                row('− Folga de 1 semana de diário', c.folga),
              ],
              Text(
                'Guardar mais que isso deixaria a conta no aperto antes do '
                'próximo salário.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('3. Resultado', style: theme.textTheme.titleSmall),
              row(
                'Dá para guardar agora (o menor dos dois)',
                c.podeGuardarAgora,
                bold: true,
              ),
              row('+ Já guardado no mês', c.economiaFeita),
              row('= Total do mês', c.totalPossivel, bold: true),
              row('Meta (${c.metaPercent}% das entradas)', c.metaValor),
              if (c.overspending.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Onde o mês pesou mais que o normal',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  'Comparado com a média dos últimos 3 meses no mesmo ponto do mês.',
                  style: theme.textTheme.bodySmall,
                ),
                for (final o in c.overspending)
                  row(
                    '${o.categoryName} (normal: ${formatCurrency(o.average)})',
                    o.current,
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
