import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/data/account.dart';
import '../../wealth/application/wealth_providers.dart';
import '../data/asset_purchase.dart';
import '../data/what_if_repository.dart';
import 'what_if_result_view.dart' show verdictColor, verdictIcon;

/// "Compra de bem" (método R5): quanto custa de verdade (preço + impostos +
/// documentação), como paga (entrada e financiamento) e o impacto no
/// patrimônio — total, líquido, % líquido, reserva e divisão. Can then
/// register it the right way (bem pelo custo total + financiamento como dívida).
class AssetPurchaseScreen extends ConsumerStatefulWidget {
  const AssetPurchaseScreen({super.key});

  @override
  ConsumerState<AssetPurchaseScreen> createState() =>
      _AssetPurchaseScreenState();
}

class _AssetPurchaseScreenState extends ConsumerState<AssetPurchaseScreen> {
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _taxes = TextEditingController();
  final _fees = TextEditingController();
  final _downPayment = TextEditingController();
  final _installments = TextEditingController();
  final _installmentAmount = TextEditingController();
  final _principal = TextEditingController();

  String _kind = 'imovel';
  bool _producesIncome = false;
  bool _financed = true;
  String? _downPaymentAccountId;
  bool _loading = false;
  String? _error;
  AssetPurchaseResult? _result;
  AssetPurchaseRequest? _lastRequest;

  @override
  void dispose() {
    for (final c in [
      _description,
      _price,
      _taxes,
      _fees,
      _downPayment,
      _installments,
      _installmentAmount,
      _principal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _amount(TextEditingController c) =>
      c.text.trim().isEmpty ? null : BrlAmountField.toApiAmount(c.text);

  AssetPurchaseRequest? _request(List<Account> accounts) {
    final price = _amount(_price);
    final account = _downPaymentAccountId ?? _defaultAccount(accounts);
    if (price == null || account == null) return null;
    AssetFinancing? financing;
    if (_financed) {
      final n = int.tryParse(_installments.text);
      final installment = _amount(_installmentAmount);
      if (n == null || n < 1 || installment == null) return null;
      financing = AssetFinancing(
        installments: n,
        installmentAmount: installment,
        principal: _amount(_principal),
      );
    }
    return AssetPurchaseRequest(
      description: _description.text,
      assetKind: _kind,
      producesIncome: _producesIncome,
      price: price,
      taxes: _amount(_taxes),
      fees: _amount(_fees),
      downPayment: _amount(_downPayment),
      downPaymentAccountId: account,
      financing: financing,
    );
  }

  String? _defaultAccount(List<Account> accounts) {
    if (accounts.isEmpty) return null;
    final checking = accounts.where((a) => a.type == AccountType.checking);
    return (checking.isNotEmpty ? checking : accounts).first.id;
  }

  Future<void> _simulate(List<Account> accounts) async {
    final request = _request(accounts);
    if (request == null) {
      setState(
        () => _error = _financed
            ? 'Informe o preço, a conta da entrada, as parcelas e o valor da parcela.'
            : 'Informe o preço e a conta de onde sai o dinheiro.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(whatIfRepositoryProvider)
          .simulateAssetPurchase(request);
      setState(() {
        _result = result;
        _lastRequest = request;
      });
    } catch (e) {
      setState(() => _error = 'Não foi possível simular: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final request = _lastRequest;
    if (request == null) return;
    final name = _description.text.trim().isEmpty
        ? (_kind == 'veiculo' ? 'Carro' : 'Imóvel')
        : _description.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar a compra?'),
        content: Text(
          'Vou lançar "$name" no patrimônio por ${formatCurrency(_result!.totalCost)}, '
          'a entrada como saída da conta escolhida (fora do custo de vida)'
          '${request.financing != null ? ', o financiamento como dívida e as parcelas como saída mensal' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(whatIfRepositoryProvider)
          .registerAssetPurchase(request, name: name);
      refreshWealth(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"$name" registrado.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível registrar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsListProvider).value ?? const [];
    final accountId = _downPaymentAccountId ?? _defaultAccount(accounts);
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Compra de bem')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const Text(
            '1. Quanto custa de verdade · 2. Como você paga · 3. O que '
            'acontece com seu patrimônio.',
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'imovel', label: Text('Imóvel')),
              ButtonSegment(value: 'veiculo', label: Text('Veículo')),
              ButtonSegment(value: 'outro', label: Text('Outro')),
            ],
            selected: {_kind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'O quê (ex.: Apto)'),
          ),
          if (_kind == 'imovel')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vai gerar renda (alugar)'),
              value: _producesIncome,
              onChanged: (v) => setState(() => _producesIncome = v),
            ),
          const SizedBox(height: 12),
          Text('1. Quanto custa', style: theme.textTheme.titleMedium),
          const Text('Preço'),
          BrlAmountField(controller: _price),
          const Text('Impostos (ITBI, IPVA…)'),
          BrlAmountField(controller: _taxes),
          const Text('Documentação (escritura, registro, despachante…)'),
          BrlAmountField(controller: _fees),
          const SizedBox(height: 12),
          Text('2. Como você paga', style: theme.textTheme.titleMedium),
          DropdownButtonFormField<String>(
            initialValue: accounts.any((a) => a.id == accountId)
                ? accountId
                : null,
            decoration: const InputDecoration(
              labelText: 'De onde sai a entrada',
            ),
            items: [
              for (final a in accounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} · ${a.type.label.toLowerCase()}'),
                ),
            ],
            onChanged: (v) => setState(() => _downPaymentAccountId = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vai financiar'),
            value: _financed,
            onChanged: (v) => setState(() => _financed = v),
          ),
          Text(_financed ? 'Entrada' : 'Valor pago (vazio = custo total)'),
          BrlAmountField(controller: _downPayment),
          if (_financed) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _installments,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Parcelas'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Valor da parcela'),
                      BrlAmountField(controller: _installmentAmount),
                    ],
                  ),
                ),
              ],
            ),
            const Text('Saldo financiado (do contrato, opcional)'),
            BrlAmountField(controller: _principal),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : () => _simulate(accounts),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simular'),
          ),
          if (result != null) ...[
            const SizedBox(height: 24),
            _ResultCard(result: result),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_home_work_outlined),
              label: const Text('Registrar a compra'),
              onPressed: _register,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final AssetPurchaseResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = verdictColor(result.verdict);
    String pct(String? v) => v == null ? '—' : '${v.replaceAll('.', ',')}%';
    String meses(String? v) => v == null ? '—' : v.replaceAll('.', ',');
    TableRow row(String label, String before, String after) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label),
        ),
        Text(before, textAlign: TextAlign.right),
        Text(after, textAlign: TextAlign.right),
      ],
    );
    final b = result.before;
    final a = result.after;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(verdictIcon(result.verdict), color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {0: FlexColumnWidth(1.4)},
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    Text(
                      'antes',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(
                      'depois',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                row('Total', formatCurrency(b.total), formatCurrency(a.total)),
                row(
                  'Saldo devedor',
                  formatCurrency(b.saldoDevedor),
                  formatCurrency(a.saldoDevedor),
                ),
                row(
                  'Líquido',
                  formatCurrency(b.liquido),
                  formatCurrency(a.liquido),
                ),
                row('% líquido', pct(b.percentLiquido), pct(a.percentLiquido)),
                row(
                  'Reserva (meses)',
                  meses(b.reservaMeses),
                  meses(a.reservaMeses),
                ),
                for (final (key, label) in const [
                  ('reserva', 'Bloco reserva'),
                  ('investimentos', 'Bloco investimentos'),
                  ('outros', 'Bloco outros'),
                ])
                  row(
                    label,
                    pct(b.blocoPercent(key)),
                    pct(a.blocoPercent(key)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final line in result.lines) ...[
              Text(line),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}
