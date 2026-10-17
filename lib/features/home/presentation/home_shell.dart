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
import '../../ledger/application/ledger_providers.dart';
import '../../ledger/presentation/saldos_screen.dart';
import '../../offline/sync_service.dart';
import '../../quick_entry/application/quick_entry_providers.dart';
import '../../quick_entry/presentation/apple_pay_screen.dart';
import '../../scenarios/application/scenarios_providers.dart';
import '../../scenarios/presentation/scenarios_list_screen.dart';
import '../../totals/application/totals_providers.dart';
import '../../totals/presentation/totais_screen.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import '../../wealth/application/wealth_providers.dart';
import '../../wealth/presentation/wealth_screen.dart';

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
    // Keeps the iOS side (Apple Pay automation) logged in as this session.
    unawaited(ref.read(tokenStorageProvider).mirrorToNative());
    // An automation that couldn't log a purchase leaves it for the app to
    // open pre-filled — on launch, or whenever the app comes back.
    _lifecycle = AppLifecycleListener(onResume: _openPendingQuickEntry);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openPendingQuickEntry(),
    );
  }

  AppLifecycleListener? _lifecycle;

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _openPendingQuickEntry() {
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) return;
    unawaited(openPendingQuickEntry(navigatorContext, ref));
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
    WealthScreen(),
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
          LiquidGlassNavItem(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Patrimônio',
          ),
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
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          const _MenuSection('Dia a dia'),
          _MenuItem(
            icon: Icons.event_available_outlined,
            title: 'A pagar',
            trailing: overdue > 0
                ? Badge(
                    label: Text('$overdue'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            builder: (_) => const BillsScreen(),
          ),
          _MenuItem(
            icon: Icons.credit_card_outlined,
            title: 'Cartões e faturas',
            builder: (_) => const CardsScreen(),
          ),
          const _MenuSection('Cadastros'),
          _MenuItem(
            icon: Icons.account_balance_outlined,
            title: 'Contas bancárias',
            builder: (_) => const AccountsScreen(),
          ),
          _MenuItem(
            icon: Icons.sell_outlined,
            title: 'Tags',
            builder: (_) => const TagsScreen(),
          ),
          _MenuItem(
            icon: Icons.pie_chart_outline,
            title: 'Previsão de diário',
            builder: (_) => const BudgetScreen(),
          ),
          const _MenuSection('Ferramentas'),
          _MenuItem(
            icon: Icons.science_outlined,
            title: 'Simulações',
            builder: (_) => const ScenariosListScreen(),
          ),
          _MenuItem(
            icon: Icons.contactless_outlined,
            title: 'Apple Pay e Atalhos',
            builder: (_) => const ApplePayScreen(),
          ),
          const Divider(height: 32),
          _MenuItem(
            icon: Icons.settings_outlined,
            title: 'Ajustes',
            builder: (_) => const _SettingsScreen(),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.builder,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final WidgetBuilder builder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: builder)),
    );
  }
}

/// Rarely-used and destructive actions, kept off the main Menu list.
class _SettingsScreen extends ConsumerWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              ref.read(authControllerProvider.notifier).signOut();
            },
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
            subtitle: const Text('Apaga tudo e começa do zero'),
            onTap: () => _confirmReset(context, ref),
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
    ref.invalidate(billsProvider);
    ref.invalidate(wealthSummaryProvider);
    ref.invalidate(wealthHistoryProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dados reiniciados.')));
    }
  }
}
