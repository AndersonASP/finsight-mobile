import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../../core/widgets/form_row.dart';
import '../../cards/application/cards_providers.dart';
import '../../cards/data/fin_card.dart';
import '../../cards/presentation/cards_screen.dart';
import '../../categories/data/category.dart';
import '../../categories/presentation/tag_picker_sheet.dart';
import '../../invoices/application/invoices_providers.dart';
import '../../ledger/application/ledger_providers.dart';
import '../../totals/application/totals_providers.dart';
import '../data/purchases_repository.dart';

Future<void> showAddPurchaseSheet(
  BuildContext context, {
  DateTime? initialDate,
  String? initialAmount,
  String? initialDescription,
  String? initialCardId,
  String? initialCardName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddPurchaseSheet(
      initialDate: initialDate,
      initialAmount: initialAmount,
      initialDescription: initialDescription,
      initialCardId: initialCardId,
      initialCardName: initialCardName,
    ),
  );
}

class _AddPurchaseSheet extends ConsumerStatefulWidget {
  const _AddPurchaseSheet({
    this.initialDate,
    this.initialAmount,
    this.initialDescription,
    this.initialCardId,
    this.initialCardName,
  });

  final DateTime? initialDate;

  /// Pre-fill from an Apple Pay automation that couldn't log by itself
  /// (offline, or a Wallet card not linked yet): API-style amount ("26.00"),
  /// merchant, and the card — by id, else matched by its Wallet name.
  final String? initialAmount;
  final String? initialDescription;
  final String? initialCardId;
  final String? initialCardName;

  @override
  ConsumerState<_AddPurchaseSheet> createState() => _AddPurchaseSheetState();
}

class _AddPurchaseSheetState extends ConsumerState<_AddPurchaseSheet> {
  late final _amountController = TextEditingController(
    text: widget.initialAmount == null
        ? ''
        : BrlAmountField.fromApiAmount(widget.initialAmount!),
  );
  late final _descriptionController = TextEditingController(
    text: widget.initialDescription ?? '',
  );
  bool _initialCardResolved = false;
  int _installments = 1;
  // Mutually exclusive with installments: a subscription is always a single
  // charge per month, repeated — never itself split into parcelas.
  bool _isSubscription = false;
  int? _subscriptionOccurrenceCount = 12;
  bool _subscriptionIsOpenEnded = false;
  FinCard? _card;
  Category? _category;
  late DateTime _date = widget.initialDate ?? DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCard(List<FinCard> cards) async {
    final selected = await showModalBottomSheet<Object>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Cartão',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.add)),
              title: const Text('novo cartão'),
              onTap: () => Navigator.of(sheetContext).pop(_CreateNewCard()),
            ),
            for (final card in cards)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.cartao,
                  child: Icon(Icons.credit_card, color: Colors.white, size: 18),
                ),
                title: Text(card.name),
                onTap: () => Navigator.of(sheetContext).pop(card),
              ),
          ],
        ),
      ),
    );

    if (selected is FinCard) {
      setState(() => _card = selected);
      return;
    }
    if (selected is _CreateNewCard) {
      if (!mounted) return;
      final created = await showCreateCardSheet(context);
      if (created != null) setState(() => _card = created);
    }
  }

  /// The pre-filled card: by id, else the one whose name and the Wallet's
  /// name contain each other ("Nubank" ↔ "Nubank Ultravioleta"), else the
  /// only card there is.
  FinCard? _matchInitialCard(List<FinCard> cards) {
    if (widget.initialCardId != null) {
      for (final card in cards) {
        if (card.id == widget.initialCardId) return card;
      }
    }
    final wallet = widget.initialCardName?.trim().toLowerCase();
    if (wallet != null && wallet.isNotEmpty) {
      for (final card in cards) {
        final name = card.name.trim().toLowerCase();
        if (wallet.contains(name) || name.contains(wallet)) return card;
      }
    }
    if (widget.initialAmount != null && cards.length == 1) return cards.single;
    return null;
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

  Future<void> _pickInstallments() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Parcelas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            for (final n in List.generate(24, (i) => i + 1))
              ListTile(
                title: Text(n == 1 ? 'à vista' : '${n}x'),
                trailing: n == _installments ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(n),
              ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _installments = selected);
  }

  String get _subscriptionSummary {
    return _subscriptionIsOpenEnded
        ? 'mensal, a perder de vista'
        : 'mensal, ${_subscriptionOccurrenceCount}x';
  }

  Future<void> _pickSubscriptionDetails() async {
    final result = await showModalBottomSheet<_SubscriptionChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubscriptionDetailsSheet(
        occurrenceCount: _subscriptionOccurrenceCount,
        isOpenEnded: _subscriptionIsOpenEnded,
      ),
    );
    if (result != null) {
      setState(() {
        _subscriptionOccurrenceCount = result.occurrenceCount;
        _subscriptionIsOpenEnded = result.isOpenEnded;
      });
    }
  }

  Future<void> _save() async {
    final amount = BrlAmountField.toApiAmount(_amountController.text);
    if (_card == null || amount == null) {
      setState(() => _error = 'Preencha cartão e valor.');
      return;
    }
    if (_isSubscription &&
        !_subscriptionIsOpenEnded &&
        (_subscriptionOccurrenceCount == null ||
            _subscriptionOccurrenceCount! < 1)) {
      setState(() => _error = 'Informe quantas vezes a assinatura repete.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final description = _descriptionController.text.trim().isEmpty
        ? _category?.name ?? 'Compra'
        : _descriptionController.text.trim();
    try {
      if (_isSubscription) {
        await ref
            .read(purchasesRepositoryProvider)
            .createRecurring(
              cardId: _card!.id,
              description: description,
              amount: amount,
              startDate: _date,
              occurrenceCount: _subscriptionIsOpenEnded
                  ? null
                  : _subscriptionOccurrenceCount,
              isOpenEnded: _subscriptionIsOpenEnded,
              categoryId: _category?.id,
            );
      } else {
        await ref
            .read(purchasesRepositoryProvider)
            .create(
              cardId: _card!.id,
              purchaseDate: _date,
              description: description,
              amount: amount,
              categoryId: _category?.id,
              installmentsCount: _installments,
            );
      }
      ref.invalidate(cardInvoicesProvider(_card!.id));
      ref.invalidate(dailyBalanceProvider);
      ref.invalidate(monthlyTotalsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsListProvider);

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
            cardsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro ao carregar cartões: $e'),
              data: (cards) {
                if (!_initialCardResolved) {
                  _initialCardResolved = true;
                  _card ??= _matchInitialCard(cards);
                }
                return FormRow(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.cartao,
                    child: Icon(
                      Icons.credit_card,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: _card?.name ?? 'escolher cartão',
                  onTap: () => _pickCard(cards),
                );
              },
            ),
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
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.autorenew),
              title: const Text('Assinatura (recorrente)'),
              subtitle: const Text('cobra o mesmo valor todo mês'),
              value: _isSubscription,
              onChanged: (value) => setState(() => _isSubscription = value),
            ),
            const Divider(height: 1),
            if (_isSubscription)
              FormRow(
                leading: const Icon(Icons.event_repeat_outlined),
                title: _subscriptionSummary,
                onTap: _pickSubscriptionDetails,
              )
            else
              FormRow(
                leading: const Icon(Icons.repeat_outlined),
                title: _installments == 1
                    ? 'à vista'
                    : '$_installments parcelas',
                onTap: _pickInstallments,
              ),
            const Divider(height: 1),
            FormRow(
              leading: const Icon(Icons.sell_outlined),
              title: _category?.name ?? 'tags',
              leadingDot: _category?.color,
              onTap: _pickTag,
            ),
            const Divider(height: 1),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.cartao),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('adicionar gasto com cartão'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal marker returned by the card picker when the user chooses
/// "novo cartão" instead of an existing [FinCard].
class _CreateNewCard {}

/// Result of [_SubscriptionDetailsSheet] when the user confirms. No
/// frequency to pick — a card subscription is always monthly.
class _SubscriptionChoice {
  const _SubscriptionChoice({
    required this.occurrenceCount,
    required this.isOpenEnded,
  });

  final int? occurrenceCount;
  final bool isOpenEnded;
}

class _SubscriptionDetailsSheet extends StatefulWidget {
  const _SubscriptionDetailsSheet({
    required this.occurrenceCount,
    required this.isOpenEnded,
  });

  final int? occurrenceCount;
  final bool isOpenEnded;

  @override
  State<_SubscriptionDetailsSheet> createState() =>
      _SubscriptionDetailsSheetState();
}

class _SubscriptionDetailsSheetState extends State<_SubscriptionDetailsSheet> {
  late bool _isOpenEnded = widget.isOpenEnded;
  late final _countController = TextEditingController(
    text: '${widget.occurrenceCount ?? 12}',
  );

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _confirm() {
    final count = int.tryParse(_countController.text);
    if (!_isOpenEnded && (count == null || count < 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe quantas vezes repete.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _SubscriptionChoice(
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
          Text('Assinatura', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
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
                : const Text('Repete sem data pra parar, até você mudar isso'),
            value: _isOpenEnded,
            onChanged: (value) => setState(() => _isOpenEnded = value),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _confirm, child: const Text('Confirmar')),
        ],
      ),
    );
  }
}
