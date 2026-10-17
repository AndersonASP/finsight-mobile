import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../debts/data/debt.dart';
import '../../debts/data/debts_repository.dart';

/// Creates or edits a debt — described once, never paid off by hand: fixed
/// installments advance with the calendar, variable balances are updated
/// from time to time. Returns true when something was saved or deleted.
Future<bool?> showDebtSheet(
  BuildContext context, {
  String? debtId,
  int? installmentsPaid,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => debtId == null
        ? const _DebtForm()
        : _DebtLoader(debtId: debtId, installmentsPaid: installmentsPaid),
  );
}

class _DebtLoader extends ConsumerWidget {
  const _DebtLoader({required this.debtId, this.installmentsPaid});

  final String debtId;
  final int? installmentsPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Debt>(
      future: ref.read(debtsRepositoryProvider).get(debtId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro ao carregar: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _DebtForm(
          existing: snapshot.data,
          installmentsPaid: installmentsPaid,
        );
      },
    );
  }
}

class _DebtForm extends ConsumerStatefulWidget {
  const _DebtForm({this.existing, this.installmentsPaid});

  final Debt? existing;
  final int? installmentsPaid;

  @override
  ConsumerState<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<_DebtForm> {
  Debt? get _existing => widget.existing;

  late final _creditor = TextEditingController(text: _existing?.creditor);
  late DebtType _type = _existing?.type ?? DebtType.consignado;
  late bool _fixed = _existing == null
      ? true
      : _existing!.kind == DebtKind.parcelaFixa;
  late final _balance = TextEditingController(
    text: _existing != null && _existing!.kind == DebtKind.saldoVariavel
        ? BrlAmountField.fromApiAmount(_existing!.currentBalance)
        : '',
  );
  late final _installment = TextEditingController(
    text: _existing?.installmentAmount == null
        ? ''
        : BrlAmountField.fromApiAmount(_existing!.installmentAmount!),
  );
  late final _current = TextEditingController(
    text: _initialCurrentInstallment()?.toString() ?? '',
  );
  late final _total = TextEditingController(
    text: _existing?.installmentsTotal?.toString() ?? '',
  );
  late final _dueDay = TextEditingController(
    text: _existing?.installmentDueDay?.toString() ?? '',
  );
  late final _payoff = TextEditingController(
    text: _existing?.payoffAmount == null
        ? ''
        : BrlAmountField.fromApiAmount(_existing!.payoffAmount!),
  );
  late final _rate = TextEditingController(
    text: _existing?.monthlyInterestRate == null
        ? ''
        : double.parse(
            _existing!.monthlyInterestRate!,
          ).toString().replaceAll('.', ','),
  );
  bool _saving = false;
  String? _error;

  /// The installment due this month, as the user would say it: if this
  /// month's due date already passed it's the last one paid, else the next.
  int? _initialCurrentInstallment() {
    final paid = widget.installmentsPaid;
    final dueDay = _existing?.installmentDueDay;
    if (paid == null || dueDay == null) return null;
    return DateTime.now().day > dueDay ? paid : paid + 1;
  }

  @override
  void dispose() {
    for (final c in [
      _creditor,
      _balance,
      _installment,
      _current,
      _total,
      _dueDay,
      _payoff,
      _rate,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({DebtStatus? status}) async {
    final creditor = _creditor.text.trim();
    final total = int.tryParse(_total.text);
    final current = int.tryParse(_current.text);
    final dueDay = int.tryParse(_dueDay.text);
    final installment = BrlAmountField.toApiAmount(_installment.text);
    final balance = BrlAmountField.toApiAmount(_balance.text);
    final rate = _rate.text.trim().isEmpty
        ? null
        : _rate.text.trim().replaceAll(',', '.');

    String? error;
    if (creditor.isEmpty) error = 'Informe com quem é a dívida.';
    if (_fixed &&
        (installment == null ||
            total == null ||
            current == null ||
            dueDay == null)) {
      error = 'Preencha a parcela, em qual você está, o total e o dia.';
    } else if (_fixed && (current! > total! || dueDay! < 1 || dueDay > 31)) {
      error = 'Confira a parcela atual e o dia do vencimento.';
    }
    if (!_fixed && balance == null) error = 'Informe quanto deve hoje.';
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payoff = BrlAmountField.toApiAmount(_payoff.text);
      final currentChanged =
          _existing == null || current != _initialCurrentInstallment();
      await ref
          .read(debtsRepositoryProvider)
          .save(
            id: _existing?.id,
            creditor: creditor,
            type: _type,
            kind: _fixed ? DebtKind.parcelaFixa : DebtKind.saldoVariavel,
            currentBalance: _fixed ? null : balance,
            installmentAmount: _fixed ? installment : null,
            installmentsTotal: _fixed ? total : null,
            installmentDueDay: _fixed ? dueDay : null,
            currentInstallment: _fixed && currentChanged ? current : null,
            payoffAmount: _fixed ? payoff : null,
            clearPayoff:
                _fixed && payoff == null && _existing?.payoffAmount != null,
            monthlyInterestRate: rate,
            clearInterestRate:
                rate == null && _existing?.monthlyInterestRate != null,
            status: status,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Não foi possível salvar: $e';
      });
    }
  }

  Future<void> _delete() async {
    await ref.read(debtsRepositoryProvider).delete(_existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _existing == null ? 'Nova dívida' : 'Editar dívida',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _creditor,
              decoration: const InputDecoration(
                labelText: 'Com quem (banco, loja, pessoa)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DebtType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final t in DebtType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (t) => setState(() => _type = t ?? _type),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tem parcela fixa por mês?'),
              subtitle: Text(
                _fixed
                    ? 'O app desconta as parcelas sozinho conforme os meses passam.'
                    : 'Você informa o saldo devedor de vez em quando.',
              ),
              value: _fixed,
              onChanged: (v) => setState(() => _fixed = v),
            ),
            if (_fixed) ...[
              const Text('Valor da parcela'),
              BrlAmountField(controller: _installment),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _current,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: const InputDecoration(
                        labelText: 'Parcela deste mês',
                        helperText: 'ex.: 13',
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('de'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _total,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: const InputDecoration(
                        labelText: 'Total',
                        helperText: 'ex.: 48',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dueDay,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(
                  labelText: 'Dia do vencimento',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Valor para quitar hoje (opcional)'),
              Text(
                'Veja no app do banco. É menor que a soma das parcelas, '
                'porque tira os juros futuros — deixa o patrimônio mais real.',
                style: theme.textTheme.bodySmall,
              ),
              BrlAmountField(controller: _payoff),
            ] else ...[
              const Text('Quanto você deve hoje'),
              BrlAmountField(controller: _balance),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Juros ao mês, em % (opcional)',
                helperText: 'Ajuda a saber quais dívidas pagar primeiro.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : () => _save(),
              child: const Text('Salvar'),
            ),
            if (_existing != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => _save(status: DebtStatus.paga),
                child: const Text('Marcar como quitada'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _saving ? null : _delete,
                child: const Text('Excluir'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
