import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/format/money.dart';
import '../../../core/notifications/reminder_notifications.dart';
import '../../../core/notifications/reminder_planner.dart';
import '../application/bills_providers.dart';
import '../data/bill.dart';

final _dueFormat = DateFormat("EEE, d 'de' MMM", 'pt_BR');

/// "A pagar": fixed saídas and card invoices with a "pago" check.
///
/// The check is only a visual control to avoid paying something twice — the
/// saldo already counts every bill on its due date, checked or not.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key, this.highlightDate});

  /// Due date to highlight (when opened from a reminder).
  final DateTime? highlightDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsProvider);
    final remindersEnabled = ref.watch(remindersEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('A pagar'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Enviar lembrete de teste',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () => _sendTestReminder(context, ref),
            ),
          IconButton(
            tooltip: remindersEnabled == true
                ? 'Desativar lembretes'
                : 'Ativar lembretes',
            icon: Icon(
              remindersEnabled == true
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
            ),
            onPressed: () => _toggleReminders(context, ref, remindersEnabled),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(billsControllerProvider).syncPending();
          ref.invalidate(billsProvider);
          await ref.read(billsProvider.future);
        },
        child: bills.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro ao carregar contas: $e'),
              ),
            ],
          ),
          data: (list) => _BillsList(
            bills: list,
            highlightDate: highlightDate,
            showRemindersPrompt: remindersEnabled == null,
          ),
        ),
      ),
    );
  }

  /// Debug only: fires a reminder for the next unpaid bills in 5 seconds
  /// (press ⌘⇧H in the simulator to see it from the home screen).
  Future<void> _sendTestReminder(BuildContext context, WidgetRef ref) async {
    final bills = ref.read(billsProvider).value ?? const [];
    final next = bills.where((b) => !b.paid).toList();
    final now = DateTime.now();
    final sample = next.isEmpty
        ? null
        : planReminders(
            next.where((b) => b.dueDate == next.first.dueDate).toList(),
            DateTime(2000),
          ).last;
    final notifications = ref.read(reminderNotificationsProvider);
    await notifications.requestPermission();
    await notifications.scheduleOne(
      PlannedReminder(
        id: 1,
        when: now.add(const Duration(seconds: 5)),
        title: sample?.title ?? 'Lembrete de teste',
        body: sample?.body ?? 'Nenhuma conta pendente — só um teste.',
        dueDate: sample?.dueDate ?? DateTime(now.year, now.month, now.day),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lembrete de teste em 5 segundos.')),
      );
    }
  }

  Future<void> _toggleReminders(
    BuildContext context,
    WidgetRef ref,
    bool? enabled,
  ) async {
    final controller = ref.read(billsControllerProvider);
    if (enabled == true) {
      await controller.disableReminders();
      return;
    }
    final granted = await controller.enableReminders();
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notificações bloqueadas. Ative em Ajustes > FinSight > Notificações.',
          ),
        ),
      );
    }
  }
}

class _BillsList extends ConsumerWidget {
  const _BillsList({
    required this.bills,
    required this.highlightDate,
    required this.showRemindersPrompt,
  });

  final List<Bill> bills;
  final DateTime? highlightDate;
  final bool showRemindersPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = DateTime(today.year, today.month, today.day + 7);

    final overdue = <Bill>[];
    final dueToday = <Bill>[];
    final nextWeek = <Bill>[];
    final later = <Bill>[];
    final paidThisMonth = <Bill>[];
    for (final bill in bills) {
      final due = bill.dueDate;
      if (due.isBefore(today)) {
        if (!bill.paid) {
          overdue.add(bill);
        } else if (due.year == today.year && due.month == today.month) {
          paidThisMonth.add(bill);
        }
      } else if (due == today) {
        dueToday.add(bill);
      } else if (due.isBefore(weekEnd)) {
        nextWeek.add(bill);
      } else {
        later.add(bill);
      }
    }

    final sections = [
      ('Vencidas sem check', overdue, true),
      ('Hoje', dueToday, false),
      ('Próximos 7 dias', nextWeek, false),
      ('Mais adiante', later, false),
      ('Pagas este mês', paidThisMonth, false),
    ].where((s) => s.$2.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (showRemindersPrompt) const _RemindersPrompt(),
        if (sections.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Nenhuma conta fixa ou fatura nos próximos dias.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        for (final (title, items, isAlert) in sections) ...[
          _SectionHeader(title: title, isAlert: isAlert, bills: items),
          for (final bill in items)
            BillTile(
              bill: bill,
              highlighted:
                  highlightDate != null && bill.dueDate == highlightDate,
              overdue: isAlert,
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.isAlert,
    required this.bills,
  });

  final String title;
  final bool isAlert;
  final List<Bill> bills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unpaidTotal = bills
        .where((b) => !b.paid)
        .fold<double>(0, (sum, b) => sum + (double.tryParse(b.amount) ?? 0));
    final color = isAlert ? theme.colorScheme.error : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ),
          if (unpaidTotal > 0)
            Text(
              'falta ${formatCurrency(unpaidTotal.toStringAsFixed(2))}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// One bill with its "pago" checkbox. Also used by the day detail screen.
class BillTile extends ConsumerWidget {
  const BillTile({
    super.key,
    required this.bill,
    this.highlighted = false,
    this.overdue = false,
  });

  final Bill bill;
  final bool highlighted;
  final bool overdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: highlighted
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      child: CheckboxListTile(
        value: bill.paid,
        onChanged: (value) =>
            ref.read(billsControllerProvider).setPaid(bill, value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        secondary: Text(
          formatCurrency(bill.amount),
          style: theme.textTheme.titleMedium?.copyWith(
            color: bill.paid ? muted : null,
            decoration: bill.paid ? TextDecoration.lineThrough : null,
          ),
        ),
        title: Text(
          bill.description,
          style: TextStyle(
            color: bill.paid ? muted : null,
            decoration: bill.paid ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          [
            _dueFormat.format(bill.dueDate),
            if (bill.kind == BillKind.invoice) 'fatura',
            if (bill.paid) 'pago',
          ].join(' · '),
          style: TextStyle(color: overdue ? theme.colorScheme.error : null),
        ),
      ),
    );
  }
}

class _RemindersPrompt extends ConsumerWidget {
  const _RemindersPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lembretes de contas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Aviso 1 dia antes e no dia do vencimento, às 9h. Contas '
              'marcadas como pagas não geram aviso.',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      ref.read(billsControllerProvider).disableReminders(),
                  child: const Text('Agora não'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () =>
                      ref.read(billsControllerProvider).enableReminders(),
                  child: const Text('Ativar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
