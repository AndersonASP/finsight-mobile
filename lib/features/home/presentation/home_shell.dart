import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/notifications/reminder_notifications.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/providers/today_navigation_provider.dart';
import '../../../core/widgets/liquid_glass_nav_bar.dart';
import '../../../core/widgets/today_button.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../bills/application/bills_providers.dart';
import '../../bills/presentation/bills_screen.dart';
import '../../budget/application/budget_providers.dart';
import '../../budget/presentation/budget_screen.dart';
import '../../cards/application/cards_providers.dart';
import '../../cards/presentation/cards_screen.dart';
import '../../categories/application/categories_providers.dart';
import '../../categories/presentation/tags_screen.dart';
import '../../debts/application/debts_providers.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../ledger/application/ledger_providers.dart';
import '../../ledger/presentation/saldos_screen.dart';
import '../../offline/sync_service.dart';
import '../../reports/presentation/reports_list_screen.dart';
import '../../scenarios/application/scenarios_providers.dart';
import '../../scenarios/presentation/scenarios_list_screen.dart';
import '../../totals/application/totals_providers.dart';
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

  @override
  void initState() {
    super.initState();
    // Sends anything queued offline in a previous session and keeps the
    // device's copy of the Saldos tab fresh (see SyncService).
    ref.read(syncServiceProvider).start();
    unawaited(_initReminders());
  }

  /// Hooks up bill reminders: a tapped one opens "Contas a pagar" on its
  /// due date — including the one that launched the app.
  Future<void> _initReminders() async {
    final notifications = ref.read(reminderNotificationsProvider);
    try {
      await notifications.init(_openBills);
      final launchDate = await notifications.launchDueDate();
      if (launchDate != null) _openBills(launchDate);
    } catch (error) {
      debugPrint('Bill reminders unavailable: $error');
    }
  }

  void _openBills(DateTime dueDate) {
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => BillsScreen(highlightDate: dueDate)),
    );
  }

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
      // The page runs underneath the floating glass bar, so the blur has
      // content to show; scrollables get the bar's height as bottom padding.
      extendBody: true,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: LiquidGlassNavBar(
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
        items: const [
          LiquidGlassNavItem(icon: Icons.table_rows_rounded, label: 'Saldos'),
          LiquidGlassNavItem(icon: Icons.calculate_rounded, label: 'Totais'),
          LiquidGlassNavItem(icon: Icons.sell_rounded, label: 'Tags'),
          LiquidGlassNavItem(icon: Icons.menu_rounded, label: 'Menu'),
        ],
        actionIcon: Icons.add_rounded,
        actionLabel: 'Adicionar',
        onAction: () => showAddTransactionEntryPoint(context),
      ),
    );
  }
}

class _MenuTab extends ConsumerWidget {
  const _MenuTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = ref.watch(overdueBillsCountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Menu'), leading: const TodayButton()),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Contas a pagar'),
            trailing: overdue > 0
                ? Badge(
                    label: Text('$overdue'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BillsScreen())),
          ),
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
            leading: Icon(
              Icons.restart_alt,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Reiniciar dados',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmReset(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reiniciar todos os dados?'),
        content: const Text(
          'Isso apaga permanentemente todas as contas, lançamentos, cartões, '
          'dívidas, tags e tudo mais que você cadastrou. Não pode ser desfeito.\n\n'
          'Depois do reinício, o app volta com uma "Conta corrente" e uma '
          '"Reserva de emergência" zeradas — você pode editar o nome e o '
          'saldo inicial delas.',
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
                child: const Text('Sim, reiniciar tudo'),
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
    if (confirmed != true) return;

    await ref.read(dioProvider).post('/reset');

    ref.invalidate(accountsListProvider);
    ref.invalidate(dailyBalanceProvider);
    ref.invalidate(monthlyTotalsProvider);
    ref.invalidate(categoriesListProvider);
    ref.invalidate(cardsListProvider);
    ref.invalidate(debtsListProvider);
    ref.invalidate(budgetItemsListProvider);
    ref.invalidate(budgetSummaryProvider);
    ref.invalidate(scenariosListProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dados reiniciados.')));
    }
  }
}
