import 'package:flutter/material.dart';
import 'account_balance_history_report_screen.dart';
import 'budget_vs_actual_report_screen.dart';
import 'category_breakdown_report_screen.dart';
import 'monthly_trend_report_screen.dart';

/// A fixed list of report types (not provider-driven — there are only ever
/// these four), each pushing its own detail screen, same shape as
/// scenarios_list_screen.dart -> scenario_detail_screen.dart.
class ReportsListScreen extends StatelessWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: const Text('Gastos por categoria'),
            subtitle: const Text(
              'quanto você gastou em cada tag, somando lançamentos e cartão',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoryBreakdownReportScreen(),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('Evolução mensal'),
            subtitle: const Text('entradas e saídas dos últimos meses'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MonthlyTrendReportScreen(),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Histórico de saldo por conta'),
            subtitle: const Text(
              'evolução do saldo de uma conta ao longo do tempo',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AccountBalanceHistoryReportScreen(),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: const Text('Orçado x realizado'),
            subtitle: const Text(
              'compara a previsão de cada categoria com o que foi gasto',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BudgetVsActualReportScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
