import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reformats raw digits into a BRL amount as the user types, calculator-style:
/// each new digit pushes in from the right, so "1" "2" "3" types "0,01" ->
/// "0,12" -> "1,23". The cursor always stays at the end.
class _CentsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    if (digits.length > 12) digits = digits.substring(digits.length - 12);

    final cents = int.parse(digits);
    final reais = cents ~/ 100;
    final centavos = cents % 100;
    final formatted =
        '${_groupThousands(reais.toString())},${centavos.toString().padLeft(2, '0')}';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _groupThousands(String digits) {
    final chars = digits.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }
    return buffer.toString().split('').reversed.join();
  }
}

/// A big, label-less BRL amount input matching the "R$ |0,00" calculator-style
/// entry pattern: a static bold "R$" and a field that masks itself into a
/// currency value as digits are typed.
class BrlAmountField extends StatelessWidget {
  const BrlAmountField({
    super.key,
    required this.controller,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool autofocus;

  /// Converts the field's masked text (e.g. "1.234,56") into the plain
  /// decimal string the API expects (e.g. "1234.56"). Empty means no amount.
  static String? toApiAmount(String maskedText) {
    if (maskedText.isEmpty) return null;
    return maskedText.replaceAll('.', '').replaceAll(',', '.');
  }

  /// The inverse of [toApiAmount] — formats the API's plain decimal string
  /// (e.g. "1234.56") into this field's masked display text (e.g.
  /// "1.234,56"), to pre-fill the controller when editing an existing value.
  static String fromApiAmount(String apiAmount) {
    final parts = apiAmount.split('.');
    final reais = parts[0].isEmpty ? '0' : parts[0];
    final centavos = (parts.length > 1 ? parts[1] : '00')
        .padRight(2, '0')
        .substring(0, 2);
    return '${_groupThousands(reais)},$centavos';
  }

  static String _groupThousands(String digits) {
    final chars = digits.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w300);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('R\$', style: style?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [_CentsInputFormatter()],
            style: style,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: '0,00',
              hintStyle: style?.copyWith(
                color: Theme.of(context).colorScheme.outlineVariant,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A labeled BRL amount field for ordinary forms (several fields stacked in
/// a sheet) — same calculator-style masking as [BrlAmountField] (digits push
/// in from the right, thousands separator, 2 decimals), just styled as a
/// normal Material text field with a label and an "R$" prefix instead of the
/// big standalone display. Use [BrlAmountField.toApiAmount]/[fromApiAmount]
/// to convert to/from the API's plain decimal string, same as that widget.
class BrlAmountFormField extends StatelessWidget {
  const BrlAmountFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String labelText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [_CentsInputFormatter()],
      decoration: InputDecoration(labelText: labelText, prefixText: 'R\$ '),
    );
  }
}
