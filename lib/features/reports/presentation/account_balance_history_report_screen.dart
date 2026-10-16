import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/saldo_tier.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/data/account_balance_history_point.dart';

class AccountBalanceHistoryReportScreen extends ConsumerStatefulWidget {
  const AccountBalanceHistoryReportScreen({super.key});

  @override
  ConsumerState<AccountBalanceHistoryReportScreen> createState() =>
      _AccountBalanceHistoryReportScreenState();
}

class _AccountBalanceHistoryReportScreenState
    extends ConsumerState<AccountBalanceHistoryReportScreen> {
  String? _accountId;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de saldo por conta')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(child: Text('Nenhuma conta cadastrada ainda.'));
          }
          final accountId =
              (_accountId != null && accounts.any((a) => a.id == _accountId))
              ? _accountId!
              : accounts.first.id;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Conta'),
                  items: accounts
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _accountId = value),
                ),
              ),
              Expanded(child: _HistoryChart(accountId: accountId)),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryChart extends ConsumerWidget {
  const _HistoryChart({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(accountBalanceHistoryProvider(accountId));
    final brightness = Theme.of(context).brightness;

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
      data: (points) {
        if (points.isEmpty) {
          return const Center(child: Text('Sem dados ainda.'));
        }
        final maxAbs = points.fold<double>(0, (max, p) {
          final v = (double.tryParse(p.balance) ?? 0).abs();
          return v > max ? v : max;
        });
        final scale = maxAbs == 0 ? 0.0 : 140 / maxAbs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in points)
                    Expanded(
                      child: _BalanceBar(
                        point: point,
                        scale: scale,
                        brightness: brightness,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BalanceBar extends StatelessWidget {
  const _BalanceBar({
    required this.point,
    required this.scale,
    required this.brightness,
  });

  final AccountBalanceHistoryPoint point;
  final double scale;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final balance = double.tryParse(point.balance) ?? 0;
    final tier = SaldoTiers.tierFor(balance);
    final color = SaldoTiers.backgroundFor(tier, brightness);
    final barHeight = balance.abs() * scale;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            formatCurrency(point.balance),
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${point.month.toString().padLeft(2, '0')}/${point.year.toString().substring(2)}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
