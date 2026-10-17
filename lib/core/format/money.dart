import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _monthFormat = DateFormat('MMM/yy', 'pt_BR');

/// Formats a decimal string (e.g. "1234.50", as returned by the API) as "R$ 1.234,50".
String formatCurrency(String decimalString) {
  final value = double.tryParse(decimalString) ?? 0;
  return _currencyFormat.format(value);
}

/// pt_BR month abbreviations come with a trailing dot (e.g. "out."); we want "out/26".
String formatMonth(DateTime month) =>
    _monthFormat.format(month).replaceAll('.', '');

/// Formats a decimal string (e.g. "10.00") as a rounded percentage ("10%").
String formatPercent(String decimalString) {
  final value = double.tryParse(decimalString) ?? 0;
  return '${value.round()}%';
}
