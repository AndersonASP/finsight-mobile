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
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddPurchaseSheet(initialDate: initialDate),
  );
}

class _AddPurchaseSheet extends ConsumerStatefulWidget {
  const _AddPurchaseSheet({this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<_AddPurchaseSheet> createState() => _AddPurchaseSheetState();
}

class _AddPurchaseSheetState extends ConsumerState<_AddPurchaseSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _installments = 1;
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

  Future<void> _save() async {
    final amount = BrlAmountField.toApiAmount(_amountController.text);
    if (_card == null || amount == null) {
      setState(() => _error = 'Preencha cartão e valor.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(purchasesRepositoryProvider)
          .create(
            cardId: _card!.id,
            purchaseDate: _date,
            description: _descriptionController.text.trim().isEmpty
                ? _category?.name ?? 'Compra'
                : _descriptionController.text.trim(),
            amount: amount,
            categoryId: _category?.id,
            installmentsCount: _installments,
          );
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
              data: (cards) => FormRow(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.cartao,
                  child: Icon(Icons.credit_card, color: Colors.white, size: 18),
                ),
                title: _card?.name ?? 'escolher cartão',
                onTap: () => _pickCard(cards),
              ),
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
            FormRow(
              leading: const Icon(Icons.repeat_outlined),
              title: _installments == 1 ? 'à vista' : '$_installments parcelas',
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
