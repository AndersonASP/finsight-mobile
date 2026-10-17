import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../cards/application/cards_providers.dart';
import '../application/quick_entry_providers.dart';
import '../data/wallet_card_mapping.dart';

/// Links Wallet cards to FinSight cards/accounts and explains how to set up
/// the Apple Pay automation that logs purchases without opening the app.
class ApplePayScreen extends ConsumerWidget {
  const ApplePayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mappings = ref.watch(walletMappingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apple Pay e Atalhos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editMapping(context, ref),
        icon: const Icon(Icons.add_card),
        label: const Text('Vincular cartão'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          const _HowToCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              'Cartões da Carteira',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          mappings.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erro ao carregar: $e'),
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nenhum cartão vinculado. Com um só cartão cadastrado '
                      'no FinSight, as compras vão para ele; com mais de um, '
                      'vincule cada cartão da Carteira.',
                    ),
                  )
                : Column(
                    children: [
                      for (final mapping in list)
                        ListTile(
                          leading: Icon(
                            mapping.isCredit
                                ? Icons.credit_card
                                : Icons.account_balance_outlined,
                          ),
                          title: Text(mapping.walletName),
                          subtitle: Text(
                            '${mapping.isCredit ? 'Crédito' : 'Débito'} · '
                            '${mapping.targetName}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Remover',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref
                                  .read(walletMappingsRepositoryProvider)
                                  .delete(mapping.id);
                              ref.invalidate(walletMappingsProvider);
                            },
                          ),
                          onTap: () =>
                              _editMapping(context, ref, existing: mapping),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editMapping(
    BuildContext context,
    WidgetRef ref, {
    WalletCardMapping? existing,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MappingSheet(existing: existing),
    );
    if (saved == true) ref.invalidate(walletMappingsProvider);
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lançar compras do Apple Pay sozinho',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '1. Abra o app Atalhos › Automação › Nova automação '
              '(Shortcuts › Automation › New Automation).\n'
              '2. Escolha "Transação" (Transaction) e marque seus cartões. '
              'Escolha "Executar imediatamente" (Run Immediately).\n'
              '3. Adicione a ação "Registrar gasto" do FinSight e toque em '
              'cada campo para escolher a variável da automação (o nome '
              'depende do idioma do iPhone):\n'
              '   • Valor → Quantia (Amount)\n'
              '   • Estabelecimento → Comerciante (Merchant)\n'
              '   • Cartão → Cartão ou Passe (Card or Pass)\n\n'
              'A compra é lançada sem abrir o app, com a tag usada da última '
              'vez no mesmo estabelecimento. Sem internet, o FinSight abre '
              'com o formulário já preenchido.',
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the FinSight card (crédito) or account (débito) a Wallet card is.
class _MappingSheet extends ConsumerStatefulWidget {
  const _MappingSheet({this.existing});

  final WalletCardMapping? existing;

  @override
  ConsumerState<_MappingSheet> createState() => _MappingSheetState();
}

class _MappingSheetState extends ConsumerState<_MappingSheet> {
  late final _nameController = TextEditingController(
    text: widget.existing?.walletName ?? '',
  );
  late String? _cardId = widget.existing?.cardId;
  late String? _accountId = widget.existing?.accountId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || (_cardId == null && _accountId == null)) {
      setState(() => _error = 'Informe o nome e escolha um cartão ou conta.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(walletMappingsRepositoryProvider)
          .save(walletName: name, cardId: _cardId, accountId: _accountId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Não foi possível salvar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardsListProvider).value ?? const [];
    final accounts = ref.watch(accountsListProvider).value ?? const [];

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
              'Vincular cartão da Carteira',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              autofocus: widget.existing == null,
              decoration: const InputDecoration(
                labelText: 'Nome na Carteira',
                helperText:
                    'Exatamente como aparece no app Carteira (ex.: "Nubank").',
              ),
            ),
            const SizedBox(height: 16),
            RadioGroup<String>(
              groupValue: _selection,
              onChanged: (value) => setState(() {
                final [kind, id] = value!.split(':');
                _cardId = kind == 'card' ? id : null;
                _accountId = kind == 'account' ? id : null;
              }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cards.isNotEmpty) ...[
                    Text(
                      'Crédito',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    for (final card in cards)
                      RadioListTile<String>(
                        value: 'card:${card.id}',
                        title: Text(card.name),
                      ),
                  ],
                  if (accounts.isNotEmpty) ...[
                    Text(
                      'Débito (lança como diário)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    for (final account in accounts)
                      RadioListTile<String>(
                        value: 'account:${account.id}',
                        title: Text(account.name),
                      ),
                  ],
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  String? get _selection => _cardId != null
      ? 'card:$_cardId'
      : _accountId != null
      ? 'account:$_accountId'
      : null;
}
