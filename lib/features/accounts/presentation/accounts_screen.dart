import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../reserve_loans/presentation/reserve_loan_sheet.dart';
import '../application/accounts_providers.dart';
import '../data/account.dart';
import '../data/accounts_repository.dart';

/// Opens the "nova conta" form, returning the created [Account] (or null if
/// dismissed) — reusable from anywhere a flow needs an account and there may
/// not be one yet (e.g. the card or economia-transfer pickers), not just
/// from this screen's own FAB.
Future<Account?> showCreateAccountSheet(
  BuildContext context, {
  AccountType? initialType,
}) {
  return showModalBottomSheet<Account>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CreateAccountSheet(initialType: initialType),
  );
}

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Contas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateAccountSheet(context),
        child: const Icon(Icons.add),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar contas: $error')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(child: Text('Nenhuma conta cadastrada ainda.'));
          }
          return ListView.separated(
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _AccountTile(account: accounts[index]),
          );
        },
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceFuture = ref
        .watch(accountsRepositoryProvider)
        .getBalance(account.id);

    return ListTile(
      title: Text(account.name),
      subtitle: Text(account.type.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<String>(
            future: balanceFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              return Text(
                formatCurrency(snapshot.data!),
                style: Theme.of(context).textTheme.titleMedium,
              );
            },
          ),
          if (account.type == AccountType.savingsReserve)
            IconButton(
              tooltip: 'Empréstimo da reserva',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () =>
                  showReserveLoanSheet(context, reserveAccount: account),
            ),
        ],
      ),
      onLongPress: () => _confirmDelete(context, ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: Text('Remover "${account.name}" permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(accountsRepositoryProvider).delete(account.id);
              ref.invalidate(accountsListProvider);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _CreateAccountSheet extends ConsumerStatefulWidget {
  const _CreateAccountSheet({this.initialType});

  final AccountType? initialType;

  @override
  ConsumerState<_CreateAccountSheet> createState() =>
      _CreateAccountSheetState();
}

class _CreateAccountSheetState extends ConsumerState<_CreateAccountSheet> {
  final _nameController = TextEditingController();
  final _initialBalanceController = TextEditingController(
    text: BrlAmountField.fromApiAmount('0'),
  );
  late AccountType _type = widget.initialType ?? AccountType.checking;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final account = await ref
        .read(accountsRepositoryProvider)
        .create(
          name: _nameController.text.trim(),
          type: _type,
          initialBalance:
              BrlAmountField.toApiAmount(_initialBalanceController.text) ?? '0',
        );
    ref.invalidate(accountsListProvider);
    if (mounted) Navigator.of(context).pop(account);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nova conta', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AccountType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: AccountType.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 12),
          BrlAmountFormField(
            controller: _initialBalanceController,
            labelText: 'Saldo inicial',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
