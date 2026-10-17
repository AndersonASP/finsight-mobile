import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../../core/widgets/form_row.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/data/account.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../categories/application/categories_providers.dart';
import '../../categories/data/category.dart';
import '../../categories/presentation/tag_picker_sheet.dart';
import '../../../core/offline/connectivity.dart';
import '../../ledger/application/ledger_providers.dart';
import '../../offline/sync_service.dart';
import '../../purchases/presentation/add_purchase_sheet.dart';
import '../../totals/application/totals_providers.dart';
import '../data/fin_transaction.dart';
import '../data/recurrence_interval.dart';
import '../data/transaction_type.dart';
import '../data/transactions_repository.dart';

/// Entry point for "adicionar": shows the type picker first, then opens the
/// lançamento form already set to the chosen type — picking "gasto com
/// cartão" skips the form entirely and opens the purchase sheet instead.
Future<void> showAddTransactionEntryPoint(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final result = await _showTypePickerSheet(context);
  if (!context.mounted) return;
  if (result is FinTransactionType) {
    showAddTransactionForm(context, type: result, initialDate: initialDate);
  } else if (result is _SwitchToCard) {
    showAddPurchaseSheet(context, initialDate: initialDate);
  }
}

/// Opens the lançamento form directly for an already-known [type], skipping
/// the type picker — used when the type picker was never shown to begin
/// with (e.g. long-pressing a typed cell on the Saldos table).
Future<void> showAddTransactionForm(
  BuildContext context, {
  required FinTransactionType type,
  DateTime? initialDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TransactionFormSheet(type: type, initialDate: initialDate),
  );
}

/// Opens the lançamento form pre-filled for editing an existing transaction
/// — fetched fresh by [transactionId] rather than trusting a possibly-stale
/// copy the caller might be holding (e.g. a [DayDetailItem] projection).
/// Offline, it's the device's copy (including a not-yet-synced edit).
Future<void> showEditTransactionSheet(
  BuildContext context,
  String transactionId,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EditTransactionLoader(transactionId: transactionId),
  );
}

class _EditTransactionLoader extends ConsumerWidget {
  const _EditTransactionLoader({required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<FinTransaction>(
      future: ref.read(syncServiceProvider).loadTransaction(transactionId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro ao carregar: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final transaction = snapshot.data!;
        return _TransactionFormSheet(
          type: transaction.type,
          existing: transaction,
        );
      },
    );
  }
}

/// The "tipo de lançamento" list — one of the four [FinTransactionType]s, or
/// "gasto com cartão" (returned as [_SwitchToCard]). Used both as the first
/// step of [showAddTransactionEntryPoint] and to change the type from
/// inside an already-open form.
Future<Object?> _showTypePickerSheet(BuildContext context) {
  return showModalBottomSheet<Object>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Tipo de lançamento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          for (final type in FinTransactionType.values)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: type.color,
                child: Icon(type.icon, color: Colors.white, size: 18),
              ),
              title: Text(type.label.toLowerCase()),
              subtitle: Text(type.hint),
              onTap: () => Navigator.of(sheetContext).pop(type),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.credit_card, color: Colors.white, size: 18),
            ),
            title: const Text('gasto com cartão'),
            subtitle: const Text('compras no crédito, à vista ou parceladas'),
            onTap: () => Navigator.of(sheetContext).pop(_SwitchToCard()),
          ),
        ],
      ),
    ),
  );
}

class _TransactionFormSheet extends ConsumerStatefulWidget {
  const _TransactionFormSheet({
    required this.type,
    this.initialDate,
    this.existing,
  });

  final FinTransactionType type;
  final DateTime? initialDate;

  /// When set, the form edits this transaction instead of creating a new
  /// one — every field below pre-fills from it.
  final FinTransaction? existing;

  @override
  ConsumerState<_TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<_TransactionFormSheet> {
  late final _amountController = TextEditingController(
    text: widget.existing != null
        ? BrlAmountField.fromApiAmount(widget.existing!.amount)
        : '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late FinTransactionType _type = widget.existing?.type ?? widget.type;
  // null means "use the smart default" (see _smartDefaultAccountId) — once
  // the user explicitly picks an account (or we're editing, which always
  // has one), this pins it instead of following the default.
  late String? _accountId = widget.existing?.accountId;
  // A freshly-picked tag (full object, from the tag picker) takes priority
  // for display; until the user picks one, the existing transaction's
  // categoryId is resolved against the loaded category list in build().
  Category? _category;
  late String? _counterpartAccountId = widget.existing?.counterpartAccountId;
  late bool _isTransfer = widget.existing?.counterpartAccountId != null;
  late DateTime _date =
      widget.existing?.date ?? widget.initialDate ?? DateTime.now();
  // Recurrence only applies to a brand-new lançamento (null = "não repete")
  // — editing an existing occurrence only ever touches that one row.
  RecurrenceInterval? _recurrenceInterval;
  int? _occurrenceCount;
  bool _recurrenceIsOpenEnded = false;
  bool _saving = false;
  String? _error;

  /// Resolves the category to display: a freshly-picked one, else the
  /// existing transaction's categoryId looked up in the loaded list (we
  /// only ever had the id, not the name/color, until the list resolves).
  Category? _resolveCategory(List<Category> categories) {
    if (_category != null) return _category;
    final existingId = widget.existing?.categoryId;
    if (existingId == null) return null;
    for (final category in categories) {
      if (category.id == existingId) return category;
    }
    return null;
  }

  /// The account used when the user hasn't explicitly picked one: the
  /// earliest-created `checking` account, falling back to the earliest
  /// account of any type — never just "whichever account happens to be
  /// first" regardless of type, which could silently land on a Reserva.
  String? _smartDefaultAccountId(List<Account> accounts) {
    if (accounts.isEmpty) return null;
    final checking = accounts.where((a) => a.type == AccountType.checking);
    return (checking.isNotEmpty ? checking : accounts).first.id;
  }

  Account? _resolveAccount(List<Account> accounts, String? id) {
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Future<void> _pickAccount(List<Account> accounts, String? currentId) async {
    if (accounts.isEmpty) {
      final created = await showCreateAccountSheet(context);
      if (created != null) setState(() => _accountId = created.id);
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Conta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            for (final account in accounts)
              ListTile(
                title: Text(account.name),
                subtitle: Text(account.type.label),
                trailing: account.id == currentId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(account.id),
              ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _accountId = result);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickType() async {
    final result = await _showTypePickerSheet(context);

    if (result is FinTransactionType) {
      setState(() => _type = result);
      return;
    }
    if (result is _SwitchToCard) {
      if (!mounted) return;
      final date = _date;
      Navigator.of(context).pop();
      showAddPurchaseSheet(context, initialDate: date);
    }
  }

  Future<void> _pickTag() async {
    final category = await showTagPickerSheet(context);
    if (category != null) setState(() => _category = category);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String get _recurrenceSummary {
    if (_recurrenceInterval == null) return 'não repete';
    final frequency = _recurrenceInterval!.label.toLowerCase();
    return _recurrenceIsOpenEnded
        ? '$frequency, a perder de vista'
        : '$frequency, ${_occurrenceCount}x';
  }

  Future<void> _pickRecurrence() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecurrencePickerSheet(
        initial: _recurrenceInterval == null
            ? null
            : _RecurrenceChoice(
                interval: _recurrenceInterval!,
                occurrenceCount: _occurrenceCount,
                isOpenEnded: _recurrenceIsOpenEnded,
              ),
      ),
    );
    if (result is _RecurrenceChoice) {
      setState(() {
        _recurrenceInterval = result.interval;
        _occurrenceCount = result.occurrenceCount;
        _recurrenceIsOpenEnded = result.isOpenEnded;
      });
    } else if (result is _ClearRecurrence) {
      setState(() {
        _recurrenceInterval = null;
        _occurrenceCount = null;
        _recurrenceIsOpenEnded = false;
      });
    }
  }

  Future<void> _save({
    required String? accountId,
    required Category? resolvedCategory,
  }) async {
    final amount = BrlAmountField.toApiAmount(_amountController.text);
    if (amount == null) {
      setState(() => _error = 'Informe um valor.');
      return;
    }
    if (_isTransfer && _counterpartAccountId == null) {
      setState(() => _error = 'Escolha a conta de destino da transferência.');
      return;
    }
    if (accountId == null) {
      setState(() => _error = 'Cadastre uma conta primeiro.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final categoryId = resolvedCategory?.id;
    final description = _descriptionController.text.trim();
    final counterpartAccountId = _isTransfer ? _counterpartAccountId : null;
    try {
      final sync = ref.read(syncServiceProvider);
      final edited = FinTransaction(
        id: widget.existing?.id ?? '',
        accountId: accountId,
        type: _type,
        amount: amount,
        date: _date,
        categoryId: categoryId,
        description: description,
        counterpartAccountId: counterpartAccountId,
      );
      var savedOffline = false;
      if (widget.existing != null) {
        savedOffline = await sync.updateTransaction(
          original: widget.existing!,
          updated: edited,
        );
      } else if (_recurrenceInterval != null) {
        // The server generates the occurrences — no offline version of this.
        await sync.requireOnline(
          () => ref
              .read(transactionsRepositoryProvider)
              .createRecurring(
                accountId: accountId,
                type: _type,
                amount: amount,
                startDate: _date,
                interval: _recurrenceInterval!,
                occurrenceCount: _recurrenceIsOpenEnded
                    ? null
                    : _occurrenceCount,
                isOpenEnded: _recurrenceIsOpenEnded,
                categoryId: categoryId,
                description: description,
                counterpartAccountId: counterpartAccountId,
              ),
        );
      } else {
        savedOffline = await sync.createTransaction(edited);
      }
      ref.invalidate(dailyBalanceProvider);
      ref.invalidate(monthlyTotalsProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      if (savedOffline) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Salvo no aparelho — será enviado quando a internet voltar.',
            ),
          ),
        );
      }
    } on OfflineException catch (e) {
      setState(
        () => _error = _recurrenceInterval != null
            ? 'Sem conexão: lançamentos recorrentes precisam de internet.'
            : e.message,
      );
    } catch (e) {
      setState(() => _error = 'Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);
    final accounts = accountsAsync.value ?? const [];
    final effectiveAccountId = _accountId ?? _smartDefaultAccountId(accounts);
    final resolvedAccount = _resolveAccount(accounts, effectiveAccountId);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final resolvedCategory = _resolveCategory(
      categoriesAsync.value ?? const [],
    );

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
            BrlAmountField(controller: _amountController, autofocus: true),
            const Divider(height: 24),
            FormRow(
              leading: CircleAvatar(
                backgroundColor: _type.color,
                child: Icon(_type.icon, color: Colors.white, size: 18),
              ),
              title: _type.label.toLowerCase(),
              onTap: _pickType,
            ),
            const Divider(height: 1),
            FormRow(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: resolvedAccount?.name ?? 'conta',
              onTap: () => _pickAccount(accounts, effectiveAccountId),
            ),
            if (_type == FinTransactionType.economia) ...[
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.sync_alt),
                title: const Text('Transferir para outra conta'),
                value: _isTransfer,
                onChanged: (value) => setState(() => _isTransfer = value),
              ),
              if (_isTransfer)
                accountsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro ao carregar contas: $e'),
                  data: (accounts) {
                    // Only "Reserva" accounts show up here — that's the
                    // caixinha this transfer is meant to feed, not just any
                    // account the user happens to have.
                    final reserveAccounts = accounts
                        .where(
                          (a) =>
                              a.type == AccountType.savingsReserve &&
                              a.id != effectiveAccountId,
                        )
                        .toList();
                    if (reserveAccounts.isEmpty) {
                      return OutlinedButton.icon(
                        onPressed: () async {
                          final created = await showCreateAccountSheet(
                            context,
                            initialType: AccountType.savingsReserve,
                          );
                          if (created != null) {
                            setState(() => _counterpartAccountId = created.id);
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('criar conta reserva'),
                      );
                    }
                    return _AccountDropdown(
                      accounts: reserveAccounts,
                      value: _counterpartAccountId,
                      onChanged: (value) =>
                          setState(() => _counterpartAccountId = value),
                    );
                  },
                ),
            ],
            const Divider(height: 1),
            FormRow(
              leading: const Icon(Icons.edit_outlined),
              child: TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'descrição',
                ),
              ),
            ),
            const Divider(height: 1),
            FormRow(
              leading: const Icon(Icons.calendar_today_outlined),
              title: 'data',
              trailingText:
                  '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
              onTap: _pickDate,
            ),
            // Recorrência só faz sentido criando um lançamento novo — editar
            // uma ocorrência existente só muda aquele único registro.
            if (widget.existing == null) ...[
              const Divider(height: 1),
              FormRow(
                leading: const Icon(Icons.event_repeat_outlined),
                title: _recurrenceSummary,
                onTap: _pickRecurrence,
              ),
            ],
            const Divider(height: 1),
            FormRow(
              leading: const Icon(Icons.sell_outlined),
              title: resolvedCategory?.name ?? 'tags',
              leadingDot: resolvedCategory?.color,
              onTap: _pickTag,
            ),
            const Divider(height: 1),
            if (widget.existing == null &&
                effectiveAccountId == null &&
                accountsAsync.hasValue) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => showCreateAccountSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('criar conta'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _type.color),
              onPressed: (!_saving && effectiveAccountId != null)
                  ? () => _save(
                      accountId: effectiveAccountId,
                      resolvedCategory: resolvedCategory,
                    )
                  : null,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.existing != null
                          ? 'salvar alterações'
                          : 'adicionar ${_type.label.toLowerCase()}',
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal marker returned by the type picker when the user chooses
/// "gasto com cartão" instead of one of the plain [FinTransactionType]s.
class _SwitchToCard {}

/// Result of [_RecurrencePickerSheet] when the user confirms a repeating
/// schedule. `occurrenceCount` is null when `isOpenEnded` is true — the
/// server decides how many occurrences cover its ~10-year window.
class _RecurrenceChoice {
  const _RecurrenceChoice({
    required this.interval,
    required this.occurrenceCount,
    required this.isOpenEnded,
  });

  final RecurrenceInterval interval;
  final int? occurrenceCount;
  final bool isOpenEnded;
}

/// Returned instead of [_RecurrenceChoice] when the user explicitly turns
/// recurrence off — distinct from a swipe-to-dismiss (which returns null
/// and must leave any previously-chosen recurrence untouched).
class _ClearRecurrence {}

class _RecurrencePickerSheet extends StatefulWidget {
  const _RecurrencePickerSheet({this.initial});

  final _RecurrenceChoice? initial;

  @override
  State<_RecurrencePickerSheet> createState() => _RecurrencePickerSheetState();
}

class _RecurrencePickerSheetState extends State<_RecurrencePickerSheet> {
  late RecurrenceInterval? _interval = widget.initial?.interval;
  late bool _isOpenEnded = widget.initial?.isOpenEnded ?? false;
  late final _countController = TextEditingController(
    text: '${widget.initial?.occurrenceCount ?? 12}',
  );

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_interval == null) {
      Navigator.of(context).pop(_ClearRecurrence());
      return;
    }
    final count = int.tryParse(_countController.text);
    if (!_isOpenEnded && (count == null || count < 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe quantas vezes repete.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _RecurrenceChoice(
        interval: _interval!,
        occurrenceCount: _isOpenEnded ? null : count,
        isOpenEnded: _isOpenEnded,
      ),
    );
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
          Text('Repetição', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<RecurrenceInterval?>(
            initialValue: _interval,
            decoration: const InputDecoration(labelText: 'Frequência'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Não repete')),
              for (final interval in RecurrenceInterval.values)
                DropdownMenuItem(value: interval, child: Text(interval.label)),
            ],
            onChanged: (value) => setState(() => _interval = value),
          ),
          if (_interval != null) ...[
            const SizedBox(height: 12),
            if (!_isOpenEnded)
              TextField(
                controller: _countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantas vezes'),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('A perder de vista'),
              subtitle: _isOpenEnded
                  ? null
                  : const Text(
                      'Repete sem data pra parar, até você mudar isso',
                    ),
              value: _isOpenEnded,
              onChanged: (value) => setState(() => _isOpenEnded = value),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: _confirm, child: const Text('Confirmar')),
        ],
      ),
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  final List<Account> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: accounts.any((a) => a.id == value) ? value : null,
      decoration: const InputDecoration(labelText: 'Conta reserva'),
      items: accounts
          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
