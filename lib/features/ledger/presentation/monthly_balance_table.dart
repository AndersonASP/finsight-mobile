import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/saldo_tier.dart';
import '../../reports/data/daily_balance_day.dart';
import '../data/saldos_column_filter.dart';

const _dayColumnWidth = 40.0;
// Narrow enough to leave the saldo column room for "-R\$ 3.353,34" on one
// line on a ~390pt-wide iPhone; the type values still fit with room to spare.
const _valuesColumnWidth = 200.0;

/// A lighter line than the theme's default divider — the full-strength one
/// reads as too heavy for a dense table with this many rows.
Color _subtleDividerColor(BuildContext context) =>
    Theme.of(context).dividerColor.withValues(alpha: 0.4);

/// The day-by-day table shared by the real Saldos screen and a scenario's
/// detail screen — same columns, same saldo, same tap/long-press
/// affordances either way. The caller supplies the data (real-only, or
/// real+shadow overlaid — see reports.service.ts's `getDailyBalance`'s
/// `scenarioId` param) and reacts to taps; this widget only renders and
/// scrolls.
class MonthlyBalanceTable extends StatefulWidget {
  const MonthlyBalanceTable({
    super.key,
    required this.daysAsync,
    required this.filter,
    required this.onFilterChanged,
    required this.onCellTap,
    required this.onCellLongPress,
    required this.onSaldoTap,
    this.scrollToTodaySignal = 0,
  });

  final AsyncValue<List<DailyBalanceDay>> daysAsync;
  final SaldosColumnFilter filter;
  final ValueChanged<SaldosColumnFilter> onFilterChanged;
  final void Function(SaldosColumnFilter type, DateTime date) onCellTap;
  final void Function(SaldosColumnFilter type, DateTime date) onCellLongPress;
  final ValueChanged<DateTime> onSaldoTap;

  /// Bump this (from the parent's state) to ask the table to scroll to
  /// today's row once its data is available — besides the implicit scroll
  /// this widget already does on its own first load.
  final int scrollToTodaySignal;

  @override
  State<MonthlyBalanceTable> createState() => _MonthlyBalanceTableState();
}

class _MonthlyBalanceTableState extends State<MonthlyBalanceTable> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  bool _pendingScrollToToday = true;

  /// +1 when the last swipe moved to the next type, -1 to the previous —
  /// so the cells slide in from the side the finger came from.
  int _swipeDirection = 1;

  /// A horizontal swipe on the middle column steps through the column's
  /// types in [SaldosColumnFilter.values] order, stopping at either end.
  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 150) return; // a slow drag isn't a swipe
    final direction = velocity < 0 ? 1 : -1;
    const options = SaldosColumnFilter.values;
    final next = options.indexOf(widget.filter) + direction;
    if (next < 0 || next >= options.length) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _swipeDirection = direction);
    widget.onFilterChanged(options[next]);
  }

  @override
  void didUpdateWidget(MonthlyBalanceTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToTodaySignal != oldWidget.scrollToTodaySignal) {
      _pendingScrollToToday = true;
    }
  }

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
    final now = DateTime.now();

    return Column(
      children: [
        _ColumnHeaderRow(
          filter: widget.filter,
          onFilterChanged: widget.onFilterChanged,
          onSwipe: _onHorizontalSwipe,
        ),
        Divider(height: 1, color: _subtleDividerColor(context)),
        Expanded(
          child: widget.daysAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Erro: $error')),
            data: (days) {
              if (_pendingScrollToToday) {
                _pendingScrollToToday = false;
                _scrollToDay(days, now.day);
              }
              return ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                // Room to scroll the last day out from under a floating
                // bottom bar (or the system's home indicator).
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final isToday =
                      day.date.year == now.year &&
                      day.date.month == now.month &&
                      day.date.day == now.day;
                  return _DayRow(
                    day: day,
                    filter: widget.filter,
                    isToday: isToday,
                    onCellTap: widget.onCellTap,
                    onCellLongPress: widget.onCellLongPress,
                    onSaldoTap: widget.onSaldoTap,
                    onSwipe: _onHorizontalSwipe,
                    swipeDirection: _swipeDirection,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The fixed "dia | [filtro ▾] | saldos" header row — it sits above the
/// scrollable list, so it never scrolls away with the content.
class _ColumnHeaderRow extends StatelessWidget {
  const _ColumnHeaderRow({
    required this.filter,
    required this.onFilterChanged,
    required this.onSwipe,
  });

  final SaldosColumnFilter filter;
  final ValueChanged<SaldosColumnFilter> onFilterChanged;
  final GestureDragEndCallback onSwipe;

  @override
  Widget build(BuildContext context) {
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
            child: GestureDetector(
              onHorizontalDragEnd: onSwipe,
              // Drawn as a rounded select field (outline + chevron) so it
              // reads as tappable, not as a plain column title.
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showFilterSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (filter != SaldosColumnFilter.todas) ...[
                            Icon(filter.icon, size: 14, color: filter.color),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            filter.label,
                            style: labelStyle?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.expand_more,
                            size: 18,
                            color: labelStyle?.color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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

  void _showFilterSheet(BuildContext context) {
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
                  onFilterChanged(option);
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
    required this.onCellTap,
    required this.onCellLongPress,
    required this.onSaldoTap,
    required this.onSwipe,
    required this.swipeDirection,
  });

  final GestureDragEndCallback onSwipe;
  final int swipeDirection;
  final DailyBalanceDay day;
  final SaldosColumnFilter filter;
  final bool isToday;
  final void Function(SaldosColumnFilter type, DateTime date) onCellTap;
  final void Function(SaldosColumnFilter type, DateTime date) onCellLongPress;
  final ValueChanged<DateTime> onSaldoTap;

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
              child: GestureDetector(
                onHorizontalDragEnd: onSwipe,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    // The incoming cells slide in from the swipe's side;
                    // the outgoing ones just fade.
                    final isIncoming = child.key == ValueKey(filter);
                    final offset = Tween<Offset>(
                      begin: Offset(isIncoming ? 0.25 * swipeDirection : 0, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.center,
                    children: [...previous, ?current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(filter),
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
                            isShadow: day.shadowFor(rowTypes[i]),
                            onTap: onCellTap,
                            onLongPress: onCellLongPress,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => onSaldoTap(day.date),
                child: Container(
                  key: ValueKey('saldo-column-${day.day}'),
                  color: SaldoTiers.backgroundFor(tier, brightness),
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  // Never wraps: a value too long for the column shrinks
                  // a little instead of breaking the line.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topRight,
                    child: Text(
                      formatCurrency(day.saldo),
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: SaldoTiers.textFor(tier, brightness),
                      ),
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
    required this.onTap,
    required this.onLongPress,
    this.isForecast = false,
    this.isShadow = false,
  });

  final SaldosColumnFilter type;
  final String value;
  final DateTime date;
  final void Function(SaldosColumnFilter type, DateTime date) onTap;
  final void Function(SaldosColumnFilter type, DateTime date) onLongPress;

  /// True for a future day's "diário" showing "previsão de diário"'s
  /// projected value rather than a real lançamento — drawn as an outline
  /// instead of filled, so it never reads as a confirmed transaction.
  final bool isForecast;

  /// True when this cell's value includes at least one item from a
  /// scenario being simulated — same outline/italic treatment as
  /// [isForecast], since both mean "not (only) a confirmed real value".
  final bool isShadow;

  @override
  Widget build(BuildContext context) {
    final hasValue = double.parse(value) != 0;
    final outlined = isForecast || isShadow;
    final zeroColor = Theme.of(context).colorScheme.outlineVariant;
    return InkWell(
      onTap: () => onTap(type, date),
      onLongPress: () => onLongPress(type, date),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          children: [
            if (outlined)
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
            // Shrinks instead of cutting with "…" when a value is too long.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatCurrency(value),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: outlined ? FontStyle.italic : null,
                    fontWeight: hasValue ? FontWeight.w600 : null,
                    color: outlined
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : (hasValue
                              ? null
                              : Theme.of(context).colorScheme.onSurfaceVariant),
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
