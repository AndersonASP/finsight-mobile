import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/data/account.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../invoices/presentation/card_invoices_screen.dart';
import '../application/cards_providers.dart';
import '../data/cards_repository.dart';
import '../data/fin_card.dart';

/// Opens the "novo cartão" form, returning the created [FinCard] (or null if
/// dismissed) — reusable from the purchase flow's card picker, not just this
/// screen's own FAB, so logging a card purchase never dead-ends on "cadastre
/// um cartão primeiro".
Future<FinCard?> showCreateCardSheet(BuildContext context) {
  return showModalBottomSheet<FinCard>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CreateCardSheet(),
  );
}

class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cartões')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateCardSheet(context),
        child: const Icon(Icons.add),
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (cards) {
          if (cards.isEmpty)
            return const Center(child: Text('Nenhum cartão cadastrado ainda.'));
          return ListView.separated(
            itemCount: cards.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _CardTile(card: cards[index]),
          );
        },
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  const _CardTile({required this.card});

  final FinCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitFuture = ref
        .watch(cardsRepositoryProvider)
        .getAvailableLimit(card.id);

    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.cartao,
        child: Icon(Icons.credit_card, color: Colors.white, size: 18),
      ),
      title: Text(card.name),
      subtitle: Text('fecha dia ${card.closingDay} · vence dia ${card.dueDay}'),
      trailing: FutureBuilder<String>(
        future: limitFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          return Text(
            '${formatCurrency(snapshot.data!)} livre',
            style: Theme.of(context).textTheme.bodySmall,
          );
        },
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => CardInvoicesScreen(card: card))),
    );
  }
}

class _CreateCardSheet extends ConsumerStatefulWidget {
  const _CreateCardSheet();

  @override
  ConsumerState<_CreateCardSheet> createState() => _CreateCardSheetState();
}

class _CreateCardSheetState extends ConsumerState<_CreateCardSheet> {
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  final _closingDayController = TextEditingController(text: '1');
  final _dueDayController = TextEditingController(text: '10');
  String? _accountId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    _closingDayController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final closingDay = int.tryParse(_closingDayController.text);
    final dueDay = int.tryParse(_dueDayController.text);
    final creditLimit = BrlAmountField.toApiAmount(_limitController.text);
    if (_nameController.text.trim().isEmpty ||
        creditLimit == null ||
        closingDay == null ||
        dueDay == null ||
        _accountId == null) {
      setState(() => _error = 'Preencha todos os campos.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final card = await ref
          .read(cardsRepositoryProvider)
          .create(
            name: _nameController.text.trim(),
            creditLimit: creditLimit,
            closingDay: closingDay,
            dueDay: dueDay,
            defaultPaymentAccountId: _accountId!,
          );
      ref.invalidate(cardsListProvider);
      if (mounted) Navigator.of(context).pop(card);
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
            Text('Novo cartão', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome (ex: Nubank)'),
            ),
            const SizedBox(height: 12),
            BrlAmountFormField(
              controller: _limitController,
              labelText: 'Limite',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _closingDayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dia de fechamento',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _dueDayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dia de vencimento',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro ao carregar contas: $e'),
              data: (accounts) {
                if (accounts.isEmpty) {
                  return OutlinedButton.icon(
                    onPressed: () async {
                      final created = await showCreateAccountSheet(context);
                      if (created != null) {
                        setState(() => _accountId = created.id);
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('criar conta de pagamento'),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: accounts.any((a) => a.id == _accountId)
                      ? _accountId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Conta de pagamento padrão',
                  ),
                  items: accounts
                      .map(
                        (Account a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _accountId = value),
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
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
      ),
    );
  }
}
