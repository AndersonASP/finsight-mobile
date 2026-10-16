import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/today_navigation_provider.dart';
import '../../../core/widgets/today_button.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../budget/presentation/budget_screen.dart';
import '../../cards/presentation/cards_screen.dart';
import '../../categories/presentation/tags_screen.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../ledger/presentation/saldos_screen.dart';
import '../../reports/presentation/reports_list_screen.dart';
import '../../scenarios/presentation/scenarios_list_screen.dart';
import '../../totals/presentation/totais_screen.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';

/// Bottom-nav shell mirroring the reference app's tabs (saldos / totais / tags / menu).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [
    SaldosScreen(),
    TotaisScreen(),
    TagsScreen(),
    _MenuTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // Jumping to "today" always means looking at the Saldos tab.
    ref.listen<int>(goToTodaySignalProvider, (previous, next) {
      if (previous != next && _index != 0) setState(() => _index = 0);
    });

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomTabItem(
              icon: Icons.table_rows_outlined,
              label: 'Saldos',
              selected: _index == 0,
              onTap: () => setState(() => _index = 0),
            ),
            _BottomTabItem(
              icon: Icons.calculate_outlined,
              label: 'Totais',
              selected: _index == 1,
              onTap: () => setState(() => _index = 1),
            ),
            _BottomTabItem(
              icon: Icons.add_circle,
              label: 'Adicionar',
              selected: false,
              onTap: () => showAddTransactionEntryPoint(context),
            ),
            _BottomTabItem(
              icon: Icons.sell_outlined,
              label: 'Tags',
              selected: _index == 2,
              onTap: () => setState(() => _index = 2),
            ),
            _BottomTabItem(
              icon: Icons.menu,
              label: 'Menu',
              selected: _index == 3,
              onTap: () => setState(() => _index = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTab extends ConsumerWidget {
  const _MenuTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu'), leading: const TodayButton()),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Contas'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AccountsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: const Text('Previsão de diário'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BudgetScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.credit_card_outlined),
            title: const Text('Cartões e faturas'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CardsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Relatórios'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportsListScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: const Text('Dívidas'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DebtsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Simulações'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScenariosListScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
