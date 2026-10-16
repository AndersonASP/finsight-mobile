import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/data/account.dart';
import '../../transactions/data/transaction_type.dart';
import '../application/scenarios_providers.dart';
import '../data/scenarios_repository.dart';

Future<void> showAddScenarioTransactionSheet(
  BuildContext context,
  String scenarioId,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddScenarioTransactionSheet(scenarioId: scenarioId),
  );
}

class _AddScenarioTransactionSheet extends ConsumerStatefulWidget {
  const _AddScenarioTransactionSheet({required this.scenarioId});

  final String scenarioId;

  @override
  ConsumerState<_AddScenarioTransactionSheet> createState() =>
      _AddScenarioTransactionSheetState();
}

class _AddScenarioTransactionSheetState
    extends ConsumerState<_AddScenarioTransactionSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  FinTransactionType _type = FinTransactionType.saida;
  String? _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = BrlAmountField.toApiAmount(_amountController.text);
    if (_accountId == null || amount == null) {
      setState(() => _error = 'Preencha conta e valor.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(scenariosRepositoryProvider)
          .addTransaction(
            scenarioId: widget.scenarioId,
            accountId: _accountId!,
            type: _type,
            amount: amount,
            date: _date,
            description: _descriptionController.text.trim(),
          );
      ref.invalidate(scenarioDetailProvider(widget.scenarioId));
      ref.invalidate(scenarioProjectionProvider(widget.scenarioId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Novo item simulado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FinTransactionType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: FinTransactionType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            BrlAmountFormField(
              controller: _amountController,
              labelText: 'Valor',
              autofocus: true,
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro ao carregar contas: $e'),
              data: (accounts) => DropdownButtonFormField<String>(
                initialValue: accounts.any((a) => a.id == _accountId)
                    ? _accountId
                    : null,
                decoration: const InputDecoration(labelText: 'Conta'),
                items: accounts
                    .map(
                      (Account a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              trailing: Text(
                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Adicionar ao cenário'),
            ),
          ],
        ),
      ),
    );
  }
}
