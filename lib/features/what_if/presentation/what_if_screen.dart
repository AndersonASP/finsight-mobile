import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../cards/application/cards_providers.dart';
import '../../purchases/presentation/add_purchase_sheet.dart';
import '../../transactions/data/transaction_type.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import '../application/what_if_providers.dart';
import '../data/what_if.dart';
import '../data/what_if_repository.dart';
import 'what_if_result_view.dart';
import 'wishlist_screen.dart';

/// "E se?" — what happens to the saldo and to the savings target if this is
/// bought today. Nothing is saved unless the user taps "lançar de verdade"
/// or keeps it in "Quero comprar".
class WhatIfScreen extends ConsumerStatefulWidget {
  const WhatIfScreen({super.key});

  @override
  ConsumerState<WhatIfScreen> createState() => _WhatIfScreenState();
}

/// Sentinel ids for the payment chips that aren't a card.
const _decide = '__decide';
const _pix = '__pix';

class _WhatIfScreenState extends ConsumerState<WhatIfScreen> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _discount = TextEditingController();

  bool _recurring = false;
  String _payment = _decide;
  int _installments = 1;
  int _interestFree = 1;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _discount.dispose();
    super.dispose();
  }

  double? get _discountPercent {
    final value = double.tryParse(_discount.text.replaceAll(',', '.'));
    return value == null || value <= 0 ? null : value;
  }

  WhatIfRequest? _request() {
    final amount = BrlAmountField.toApiAmount(_amount.text);
    if (amount == null || (double.tryParse(amount) ?? 0) <= 0) return null;
    return WhatIfRequest(
      amount: amount,
      description: _description.text,
      recurring: _recurring,
      payment: switch (_payment) {
        _decide => const PayDecide(),
        _pix => const PayPix(),
        final cardId => PayCard(
          cardId: cardId,
          installments: _recurring ? 1 : _installments,
        ),
      },
      pixDiscountPercent: _recurring ? null : _discountPercent,
      interestFreeInstallments: _recurring ? null : _interestFree,
    );
  }

  Future<void> _simulate() async {
    final request = _request();
    if (request == null) {
      setState(() => _error = 'Informe quanto custa.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(whatIfRepositoryProvider).simulate(request);
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WhatIfResultScreen(
            result: result,
            title: _description.text.trim().isEmpty
                ? 'E se?'
                : _description.text.trim(),
            onSave: _saveToWishlist,
            onLaunch: () => _launchForReal(result),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível simular: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _saveToWishlist() async {
    final amount = BrlAmountField.toApiAmount(_amount.text);
    if (amount == null) return false;
    final description = _description.text.trim().isEmpty
        ? 'Compra de ${_amount.text}'
        : _description.text.trim();
    try {
      await ref
          .read(whatIfRepositoryProvider)
          .addToWishlist(
            description: description,
            amount: amount,
            pixDiscountPercent: _discountPercent,
            interestFreeInstallments: _interestFree,
          );
      ref.invalidate(wishlistProvider);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salvo em Quero comprar. Aviso quando passar a caber.'),
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
      }
      return false;
    }
  }

  void _launchForReal(WhatIfResult result) {
    final option = result.escolhida;
    final description = _description.text.trim().isEmpty
        ? null
        : _description.text.trim();
    if (option.isCard) {
      showAddPurchaseSheet(
        context,
        initialAmount: option.valorTotal,
        initialDescription: description,
        initialCardId: option.cardId,
      );
    } else {
      showAddTransactionForm(
        context,
        type: FinTransactionType.diario,
        initialAmount: option.valorTotal,
        initialDescription: description,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ref.watch(cardsListProvider).value ?? const [];
    final isCard = _payment != _decide && _payment != _pix;

    return Scaffold(
      appBar: AppBar(
        title: const Text('E se?'),
        actions: [
          IconButton(
            tooltip: 'Quero comprar',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const WishlistScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'O que é?',
              hintText: 'Bike, notebook, academia…',
            ),
          ),
          const SizedBox(height: 16),
          BrlAmountField(controller: _amount),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Compra única')),
              ButtonSegment(value: true, label: Text('Todo mês')),
            ],
            selected: {_recurring},
            onSelectionChanged: (s) => setState(() => _recurring = s.first),
          ),
          const SizedBox(height: 20),
          Text('Como vai pagar?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Me ajuda a decidir'),
                selected: _payment == _decide,
                onSelected: (_) => setState(() => _payment = _decide),
              ),
              ChoiceChip(
                label: const Text('Pix/débito'),
                selected: _payment == _pix,
                onSelected: (_) => setState(() => _payment = _pix),
              ),
              for (final card in cards)
                ChoiceChip(
                  avatar: const Icon(
                    Icons.credit_card,
                    size: 16,
                    color: AppColors.cartao,
                  ),
                  label: Text(card.name),
                  selected: _payment == card.id,
                  onSelected: (_) => setState(() => _payment = card.id),
                ),
            ],
          ),
          if (isCard && !_recurring)
            _Stepper(
              label: 'Parcelas',
              value: _installments,
              format: (v) => v == 1 ? 'à vista (1x)' : '${v}x',
              onChanged: (v) => setState(() => _installments = v),
            ),
          if (!_recurring) ...[
            const SizedBox(height: 8),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Condições da loja'),
                subtitle: Text(
                  'Desconto no Pix e parcelas sem juros',
                  style: theme.textTheme.bodySmall,
                ),
                children: [
                  TextField(
                    controller: _discount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Desconto à vista no Pix',
                      suffixText: '%',
                    ),
                  ),
                  _Stepper(
                    label: 'Parcela sem juros em até',
                    value: _interestFree,
                    format: (v) => '${v}x',
                    onChanged: (v) => setState(() => _interestFree = v),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _simulate,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: const Text('Simular'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Comprando hoje. Nada é salvo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String Function(int) format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      SizedBox(
        width: 84,
        child: Text(format(value), textAlign: TextAlign.center),
      ),
      IconButton(
        onPressed: value < 24 ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}
