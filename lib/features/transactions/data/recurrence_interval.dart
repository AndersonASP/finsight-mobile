enum RecurrenceInterval { daily, weekly, biweekly, monthly, annual }

extension RecurrenceIntervalX on RecurrenceInterval {
  String get apiValue => switch (this) {
    RecurrenceInterval.daily => 'daily',
    RecurrenceInterval.weekly => 'weekly',
    RecurrenceInterval.biweekly => 'biweekly',
    RecurrenceInterval.monthly => 'monthly',
    RecurrenceInterval.annual => 'annual',
  };

  String get label => switch (this) {
    RecurrenceInterval.daily => 'Diário',
    RecurrenceInterval.weekly => 'Semanal',
    RecurrenceInterval.biweekly => 'Quinzenal',
    RecurrenceInterval.monthly => 'Mensal',
    RecurrenceInterval.annual => 'Anual',
  };
}
