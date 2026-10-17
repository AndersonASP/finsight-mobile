import 'package:dio/dio.dart';
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
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _CreateAccountSheet(existing: account),
      ),
      onLongPress: () => _confirmDelete(context, ref),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // Fetched before the dialog so the warning can name the real impact —
    // "this account still has money in it" is the whole point of the warning.
    final balance = await ref
        .read(accountsRepositoryProvider)
        .getBalance(account.id);
    final hasBalance = (double.tryParse(balance) ?? 0) != 0;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: Text(
          hasBalance
              ? 'Remover "${account.name}" permanentemente. Ela tem saldo de ${formatCurrency(balance)}: excluir vai apagar todo o histórico de lançamentos dela e afetar seus saldos e projeções.'
              : 'Remover "${account.name}" permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(accountsRepositoryProvider).delete(account.id);
      ref.invalidate(accountsListProvider);
    } on DioException catch (e) {
      // The backend blocks deletion (instead of crashing or silently
      // orphaning a card/loan) when something still depends on this account
      // — surface its specific reason rather than failing silently.
      final data = e.response?.data;
      final message = data is Map
          ? (data['error']?['message'] as String?)
          : null;
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Não foi possível excluir'),
            content: Text(message ?? 'Tente novamente em alguns instantes.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      }
    }
  }
}

class _CreateAccountSheet extends ConsumerStatefulWidget {
  const _CreateAccountSheet({this.initialType, this.existing});

  final AccountType? initialType;

  /// Non-null when editing an existing account instead of creating a new
  /// one — the type stays fixed (changing it would retroactively change how
  /// past activity was ever counted toward saldo), only name and saldo
  /// inicial are editable.
  final Account? existing;

  @override
  ConsumerState<_CreateAccountSheet> createState() =>
      _CreateAccountSheetState();
}

class _CreateAccountSheetState extends ConsumerState<_CreateAccountSheet> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _initialBalanceController = TextEditingController(
    text: BrlAmountField.fromApiAmount(widget.existing?.initialBalance ?? '0'),
  );
  late AccountType _type =
      widget.existing?.type ?? widget.initialType ?? AccountType.checking;
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
    final repository = ref.read(accountsRepositoryProvider);
    final initialBalance =
        BrlAmountField.toApiAmount(_initialBalanceController.text) ?? '0';
    final account = widget.existing != null
        ? await repository.update(
            id: widget.existing!.id,
            name: _nameController.text.trim(),
            initialBalance: initialBalance,
          )
        : await repository.create(
            name: _nameController.text.trim(),
            type: _type,
            initialBalance: initialBalance,
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
          Text(
            widget.existing != null ? 'Editar conta' : 'Nova conta',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          if (widget.existing != null)
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Tipo'),
              child: Text(_type.label),
            )
          else
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
