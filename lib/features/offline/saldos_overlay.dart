import '../../core/offline/offline_store.dart';
import '../accounts/data/account.dart';
import '../categories/data/category.dart';
import '../ledger/data/day_detail_item.dart';
import '../ledger/data/saldos_column_filter.dart';
import '../reports/data/daily_balance_day.dart';
import '../transactions/data/fin_transaction.dart';
import '../transactions/data/transaction_type.dart';
import 'pending_changes.dart';

/// Per-day change (in cents) that pending lançamentos make to the Saldos table.
class _DayEffect {
  int entrada = 0;
  int saida = 0;
  int diario = 0;
  int economia = 0;

  /// Change to the running checking-only saldo, *before* any adjustment to
  /// that day's "previsão de diário" (see [_saldoDeltaFor]).
  int saldo = 0;
}

int _cents(String amount) => (double.parse(amount) * 100).round();

String _fromCents(int cents) => (cents / 100).toStringAsFixed(2);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Mirrors reports.service.ts's `getDailyBalance` for one transaction: only
/// checking accounts move the consolidated saldo. An account missing from
/// [accountTypes] (accounts never cached) is assumed to be checking — the
/// main account is the overwhelmingly common case.
int _checkingSaldoDelta(
  FinTransaction t,
  Map<String, AccountType> accountTypes,
) {
  bool isChecking(String id) =>
      (accountTypes[id] ?? AccountType.checking) == AccountType.checking;
  final amount = _cents(t.amount);
  var delta = 0;
  if (isChecking(t.accountId)) {
    delta += t.type == FinTransactionType.entrada ? amount : -amount;
  }
  final counterpart = t.counterpartAccountId;
  if (counterpart != null &&
      t.type == FinTransactionType.economia &&
      isChecking(counterpart)) {
    delta += amount;
  }
  return delta;
}

Map<String, _DayEffect> _effectsByDay(
  PendingChanges pending,
  Map<String, AccountType> accountTypes,
) {
  final effects = <String, _DayEffect>{};
  void apply(FinTransaction t, int sign) {
    final effect = effects.putIfAbsent(dateKey(t.date), _DayEffect.new);
    final amount = _cents(t.amount) * sign;
    switch (t.type) {
      case FinTransactionType.entrada:
        effect.entrada += amount;
      case FinTransactionType.saida:
        effect.saida += amount;
      case FinTransactionType.diario:
        effect.diario += amount;
      case FinTransactionType.economia:
        effect.economia += amount;
    }
    effect.saldo += _checkingSaldoDelta(t, accountTypes) * sign;
  }

  for (final t in pending.removed) {
    apply(t, -1);
  }
  for (final t in pending.added) {
    apply(t, 1);
  }
  return effects;
}

/// The day's resulting "diário" cell and saldo change, honoring the server's
/// forecast rule: a future day with no real diário shows (and subtracts) the
/// month's flat daily average; any real diário that day replaces it.
({int diario, bool isForecast, int saldoDelta}) _saldoDeltaFor({
  required DateTime date,
  required _DayEffect effect,
  required DailyBalanceDay? baseDay,
  required List<DailyBalanceDay>? baseMonth,
  required DateTime todayUtc,
}) {
  if (baseDay == null) {
    // Month never cached: no forecast info, so only the raw effect applies.
    return (diario: effect.diario, isForecast: false, saldoDelta: effect.saldo);
  }
  final baseDiario = _cents(baseDay.diario);
  final oldForecast = baseDay.diarioIsForecast ? baseDiario : 0;
  final baseReal = baseDay.diarioIsForecast ? 0 : baseDiario;
  final newReal = baseReal + effect.diario;

  int? forecastAverage;
  if (baseDay.diarioIsForecast) {
    forecastAverage = baseDiario;
  } else {
    for (final d in baseMonth ?? const <DailyBalanceDay>[]) {
      if (d.diarioIsForecast) {
        forecastAverage = _cents(d.diario);
        break;
      }
    }
  }
  final isFuture = _day(date).isAfter(todayUtc);
  final newForecast = (isFuture && newReal == 0 && forecastAverage != null)
      ? forecastAverage
      : 0;

  return (
    diario: newForecast > 0 ? newForecast : newReal,
    isForecast: newForecast > 0,
    saldoDelta: effect.saldo - (newForecast - oldForecast),
  );
}

/// Today's date as the server sees it (it compares against the UTC day).
DateTime currentUtcDay() {
  final now = DateTime.now().toUtc();
  return DateTime(now.year, now.month, now.day);
}

/// [base] (server data, live or cached) for [year]/[month], with [pending]
/// lançamentos applied: the type columns of the days they fall on, plus the
/// running saldo from that day on — including days in later months, so a
/// lançamento added for the 10th still shifts next month's saldo.
///
/// [baseForMonth] returns another month's cached table (to know whether a
/// pending lançamento in that month replaced a forecast).
List<DailyBalanceDay> applyPendingToDailyBalance({
  required List<DailyBalanceDay> base,
  required int year,
  required int month,
  required PendingChanges pending,
  required Map<String, AccountType> accountTypes,
  required List<DailyBalanceDay>? Function(int year, int month) baseForMonth,
  DateTime? todayUtc,
}) {
  if (pending.isEmpty || base.isEmpty) return base;
  final today = todayUtc ?? currentUtcDay();
  final effects = _effectsByDay(pending, accountTypes);
  final monthStart = DateTime(year, month);

  // Running saldo change carried in from pending lançamentos before this month.
  var carried = 0;
  for (final entry in effects.entries) {
    final date = DateTime.parse(entry.key);
    if (!date.isBefore(monthStart)) continue;
    final otherMonth = baseForMonth(date.year, date.month);
    final baseDay = otherMonth?.where((d) => d.day == date.day).firstOrNull;
    carried += _saldoDeltaFor(
      date: date,
      effect: entry.value,
      baseDay: baseDay,
      baseMonth: otherMonth,
      todayUtc: today,
    ).saldoDelta;
  }

  var running = carried;
  return [
    for (final day in base)
      () {
        final effect = effects[dateKey(day.date)];
        if (effect == null) {
          if (running == 0) return day;
          return _copyDay(day, saldo: _cents(day.saldo) + running);
        }
        final resolved = _saldoDeltaFor(
          date: day.date,
          effect: effect,
          baseDay: day,
          baseMonth: base,
          todayUtc: today,
        );
        running += resolved.saldoDelta;
        return _copyDay(
          day,
          entrada: _cents(day.entrada) + effect.entrada,
          saida: _cents(day.saida) + effect.saida,
          diario: resolved.diario,
          diarioIsForecast: resolved.isForecast,
          economia: _cents(day.economia) + effect.economia,
          saldo: _cents(day.saldo) + running,
        );
      }(),
  ];
}

DailyBalanceDay _copyDay(
  DailyBalanceDay day, {
  int? entrada,
  int? saida,
  int? diario,
  bool? diarioIsForecast,
  int? economia,
  required int saldo,
}) {
  return DailyBalanceDay(
    day: day.day,
    date: day.date,
    entrada: entrada != null ? _fromCents(entrada) : day.entrada,
    entradaShadow: day.entradaShadow,
    saida: saida != null ? _fromCents(saida) : day.saida,
    saidaShadow: day.saidaShadow,
    diario: diario != null ? _fromCents(diario) : day.diario,
    diarioIsForecast: diarioIsForecast ?? day.diarioIsForecast,
    diarioShadow: day.diarioShadow,
    economia: economia != null ? _fromCents(economia) : day.economia,
    economiaShadow: day.economiaShadow,
    cartao: day.cartao,
    cartaoShadow: day.cartaoShadow,
    saldo: _fromCents(saldo),
  );
}

/// True when some pending lançamento (or the server version it replaces)
/// falls on [date].
bool pendingTouchesDate(PendingChanges pending, DateTime date) {
  final key = dateKey(date);
  return [
    ...pending.added,
    ...pending.removed,
  ].any((t) => dateKey(t.date) == key);
}

/// [base] (one day's line items, live or cached) with [pending] applied:
/// deleted/edited lançamentos removed, created/edited ones (that now fall on
/// [date]) added and flagged [DayDetailItem.isPending].
List<DayDetailItem> applyPendingToDayDetail({
  required List<DayDetailItem> base,
  required DateTime date,
  required PendingChanges pending,
  required List<Category> categories,
}) {
  if (pending.isEmpty) return base;
  final key = dateKey(date);
  final baseById = {
    for (final item in base)
      if (item.installment == null) item.id: item,
  };
  bool isReplaced(DayDetailItem item) =>
      item.installment == null &&
      (pending.updates.containsKey(item.id) ||
          pending.deletes.containsKey(item.id));

  final categoryById = {for (final c in categories) c.id: c};
  final items = [
    for (final item in base)
      if (!isReplaced(item)) item,
    for (final t in pending.added)
      if (dateKey(t.date) == key)
        _itemFor(t, categoryById[t.categoryId], baseById[t.id]),
  ];
  items.sort(
    (a, b) => double.parse(b.amount).compareTo(double.parse(a.amount)),
  );
  return items;
}

DayDetailItem _itemFor(
  FinTransaction t,
  Category? category,
  DayDetailItem? serverItem,
) {
  final description = t.description?.trim() ?? '';
  return DayDetailItem(
    id: t.id,
    type: switch (t.type) {
      FinTransactionType.entrada => SaldosColumnFilter.entrada,
      FinTransactionType.saida => SaldosColumnFilter.saida,
      FinTransactionType.diario => SaldosColumnFilter.diario,
      FinTransactionType.economia => SaldosColumnFilter.economia,
    },
    description: description.isNotEmpty ? description : t.type.apiValue,
    date: DateTime(t.date.year, t.date.month, t.date.day),
    amount: _fromCents(_cents(t.amount)),
    categoryName: category?.name,
    categoryColor: category?.color ?? (serverItem?.categoryColor),
    recurring: serverItem?.recurring,
    isPending: true,
  );
}
