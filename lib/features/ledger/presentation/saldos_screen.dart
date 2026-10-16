import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../core/format/money.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../../core/providers/today_navigation_provider.dart';
import '../../../core/theme/saldo_tier.dart';
import '../../../core/widgets/today_button.dart';
import '../../purchases/presentation/add_purchase_sheet.dart';
import '../../reports/data/daily_balance_day.dart';
import '../../transactions/data/transaction_type.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import '../application/ledger_providers.dart';
import '../data/saldos_column_filter.dart';
import 'day_detail_screen.dart';

/// Long-pressing a typed cell on the Saldos table already tells us both the
/// day and the lançamento type — so this skips the type-picker step and
/// opens the matching form directly (the purchase sheet for "cartão", since
/// that type isn't a plain [FinTransactionType]).
void _openAddTransactionFor(
  BuildContext context,
  SaldosColumnFilter type,
  DateTime date,
) {
  switch (type) {
    case SaldosColumnFilter.cartao:
      showAddPurchaseSheet(context, initialDate: date);
    case SaldosColumnFilter.entrada:
      showAddTransactionForm(
        context,
        type: FinTransactionType.entrada,
        initialDate: date,
      );
    case SaldosColumnFilter.saida:
      showAddTransactionForm(
        context,
        type: FinTransactionType.saida,
        initialDate: date,
      );
    case SaldosColumnFilter.diario:
      showAddTransactionForm(
        context,
        type: FinTransactionType.diario,
        initialDate: date,
      );
    case SaldosColumnFilter.economia:
      showAddTransactionForm(
        context,
        type: FinTransactionType.economia,
        initialDate: date,
      );
    case SaldosColumnFilter.todas:
      break; // _TypeValueRow's `type` is always a concrete type, never `todas`.
  }
}

const _dayColumnWidth = 40.0;
const _valuesColumnWidth = 230.0;

/// A lighter line than the theme's default divider — the full-strength one
/// reads as too heavy for a dense table with this many rows.
Color _subtleDividerColor(BuildContext context) =>
    Theme.of(context).dividerColor.withValues(alpha: 0.4);

class SaldosScreen extends ConsumerStatefulWidget {
  const SaldosScreen({super.key});

  @override
  ConsumerState<SaldosScreen> createState() => _SaldosScreenState();
}

class _SaldosScreenState extends ConsumerState<SaldosScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  // Set when "go to today" fires on a month that isn't loaded yet, or on
  // first open — the actual scroll waits for that month's data to arrive
  // (see `data:` below) instead of firing immediately against a list that
  // doesn't have it.
  bool _pendingScrollToToday = true;

  /// Scrolls to [day] by list *index*, not by looking up an already-built
  /// widget — `ListView.builder`-style lists only build items near the
  /// viewport, so a day far from the current scroll position may not exist
  /// as a widget yet. `ItemScrollController` handles that correctly.
  void _scrollToDay(List<DailyBalanceDay> days, int day) {
    final index = days.indexWhere((d) => d.day == day);
    if (index == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_itemScrollController.isAttached) {
        _itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final filter = ref.watch(saldosColumnFilterProvider);
    final daysAsync = ref.watch(dailyBalanceProvider);
    final now = DateTime.now();

    ref.listen<int>(goToTodaySignalProvider, (previous, next) {
      if (previous == next) return;
      final currentMonth = DateTime(now.year, now.month);
      if (month != currentMonth) {
        _pendingScrollToToday = true;
        ref.read(selectedMonthProvider.notifier).state = currentMonth;
      } else {
        final days = daysAsync.value;
        if (days != null) _scrollToDay(days, now.day);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopHeader(month: month),
            _ColumnHeaderRow(filter: filter),
            Divider(height: 1, color: _subtleDividerColor(context)),
            Expanded(
              child: daysAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erro: $error')),
                data: (days) {
                  if (_pendingScrollToToday) {
                    _pendingScrollToToday = false;
                    _scrollToDay(days, now.day);
                  }
                  return ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final day = days[index];
                      final isToday =
                          day.date.year == now.year &&
                          day.date.month == now.month &&
                          day.date.day == now.day;
                      return _DayRow(
                        day: day,
                        filter: filter,
                        isToday: isToday,
                      );
                    },
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

class _TopHeader extends ConsumerWidget {
  const _TopHeader({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          const TodayButton(),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                month.previousMonth,
          ),
          Text(
            formatMonth(month),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                month.nextMonth,
          ),
          const Spacer(),
          const SizedBox(
            width: 34,
          ), // balances the TodayButton so the month stays centered
        ],
      ),
    );
  }
}

/// The fixed "dia | [filtro ▾] | saldos" header row — it sits above the
/// scrollable list, so it never scrolls away with the content.
class _ColumnHeaderRow extends ConsumerWidget {
  const _ColumnHeaderRow({required this.filter});

  final SaldosColumnFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: _dayColumnWidth,
            child: Text('dia', style: labelStyle),
          ),
          SizedBox(
            width: _valuesColumnWidth,
            child: InkWell(
              onTap: () => _showFilterSheet(context, ref),
              child: Row(
                children: [
                  Text(
                    filter.label,
                    style: labelStyle?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: null,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.expand_more, size: 18, color: labelStyle?.color),
                ],
              ),
            ),
          ),
          Expanded(
            child: Text(
              'saldos',
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Mostrar na coluna',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            for (final option in SaldosColumnFilter.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: option.color,
                  child: Icon(option.icon, color: Colors.white, size: 16),
                ),
                title: Text(option.label),
                trailing: option == filter ? const Icon(Icons.check) : null,
                onTap: () {
                  ref.read(saldosColumnFilterProvider.notifier).state = option;
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.filter,
    required this.isToday,
  });

  final DailyBalanceDay day;
  final SaldosColumnFilter filter;
  final bool isToday;

  String _valueFor(SaldosColumnFilter type) => switch (type) {
    SaldosColumnFilter.entrada => day.entrada,
    SaldosColumnFilter.saida => day.saida,
    SaldosColumnFilter.diario => day.diario,
    SaldosColumnFilter.economia => day.economia,
    SaldosColumnFilter.cartao => day.cartao,
    SaldosColumnFilter.todas => '0',
  };

  @override
  Widget build(BuildContext context) {
    final rowTypes = filter == SaldosColumnFilter.todas
        ? SaldosColumnFilter.values
              .where((f) => f != SaldosColumnFilter.todas)
              .toList()
        : [filter];
    final tier = SaldoTiers.tierFor(double.parse(day.saldo));
    final brightness = Theme.of(context).brightness;
    final dividerSide = BorderSide(color: _subtleDividerColor(context));

    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.07)
              : null,
          border: Border(bottom: dividerSide),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _dayColumnWidth,
              child: Container(
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: dividerSide,
                    left: isToday
                        ? BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: isToday ? FontWeight.bold : null,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _valuesColumnWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < rowTypes.length; i++) ...[
                    if (i != 0 && filter == SaldosColumnFilter.todas)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: dividerSide.color,
                        indent: 4,
                        endIndent: 4,
                      ),
                    _TypeValueRow(
                      type: rowTypes[i],
                      value: _valueFor(rowTypes[i]),
                      date: day.date,
                      isForecast:
                          rowTypes[i] == SaldosColumnFilter.diario &&
                          day.diarioIsForecast,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DayDetailScreen(date: day.date),
                  ),
                ),
                child: Container(
                  key: ValueKey('saldo-column-${day.day}'),
                  color: SaldoTiers.backgroundFor(tier, brightness),
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    formatCurrency(day.saldo),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: SaldoTiers.textFor(tier, brightness),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeValueRow extends StatelessWidget {
  const _TypeValueRow({
    required this.type,
    required this.value,
    required this.date,
    this.isForecast = false,
  });

  final SaldosColumnFilter type;
  final String value;
  final DateTime date;

  /// True for a future day's "diário" showing "previsão de diário"'s
  /// projected value rather than a real lançamento — drawn as an outline
  /// instead of filled, so it never reads as a confirmed transaction.
  final bool isForecast;

  @override
  Widget build(BuildContext context) {
    final hasValue = double.parse(value) != 0;
    final zeroColor = Theme.of(context).colorScheme.outlineVariant;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DayDetailScreen(date: date, initialFilter: type),
        ),
      ),
      onLongPress: () => _openAddTransactionFor(context, type, date),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          children: [
            if (isForecast)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: type.color, width: 1.5),
                ),
                child: Icon(type.icon, size: 12, color: type.color),
              )
            else
              CircleAvatar(
                radius: 10,
                backgroundColor: hasValue ? type.color : zeroColor,
                child: Icon(type.icon, size: 12, color: Colors.white),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                formatCurrency(value),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontStyle: isForecast ? FontStyle.italic : null,
                  fontWeight: hasValue ? FontWeight.w600 : null,
                  color: isForecast
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : (hasValue
                            ? null
                            : Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
