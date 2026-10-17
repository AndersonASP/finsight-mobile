import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../data/wealth.dart';
import '../data/wealth_repository.dart';

/// Creates or edits a bem / valor a receber. Returns true when saved/deleted.
Future<bool?> showAssetSheet(
  BuildContext context, {
  WealthItem? existing,
  AssetKind? kind,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AssetForm(existing: existing, initialKind: kind),
  );
}

class _AssetForm extends ConsumerStatefulWidget {
  const _AssetForm({this.existing, this.initialKind});

  final WealthItem? existing;
  final AssetKind? initialKind;

  @override
  ConsumerState<_AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends ConsumerState<_AssetForm> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _value = TextEditingController(
    text: widget.existing == null
        ? ''
        : BrlAmountField.fromApiAmount(widget.existing!.value),
  );
  late AssetKind _kind = widget.existing != null
      ? AssetKind.fromApi(widget.existing!.details['assetKind'] as String)
      : widget.initialKind ?? AssetKind.imovel;
  late bool _isLiquid = widget.existing != null
      ? widget.existing!.details['isLiquid'] as bool
      : _kind == AssetKind.aReceber;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final value = BrlAmountField.toApiAmount(_value.text);
    if (name.isEmpty || value == null) {
      setState(() => _error = 'Informe o nome e o valor.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(wealthRepositoryProvider)
          .saveAsset(
            id: widget.existing?.id,
            name: name,
            kind: _kind,
            value: value,
            isLiquid: _isLiquid,
          );
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
    final theme = Theme.of(context);
    final isReceivable = _kind == AssetKind.aReceber;
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
              widget.existing == null
                  ? (isReceivable ? 'Valor a receber' : 'Novo bem')
                  : 'Editar',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<AssetKind>(
              segments: [
                for (final k in AssetKind.values)
                  ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                if (widget.existing == null) {
                  _isLiquid = _kind == AssetKind.aReceber;
                }
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: isReceivable
                    ? 'De quem / o quê (ex.: reembolso, FGTS)'
                    : 'Nome (ex.: Apartamento, Carro)',
              ),
            ),
            const SizedBox(height: 16),
            Text(isReceivable ? 'Valor a receber' : 'Quanto vale hoje'),
            if (!isReceivable)
              Text(
                'Uma estimativa honesta: o preço que você conseguiria vender '
                'hoje (FIPE para veículos, anúncios parecidos para imóveis).',
                style: theme.textTheme.bodySmall,
              ),
            BrlAmountField(controller: _value),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Conta como dinheiro disponível'),
              subtitle: const Text(
                'Entra no patrimônio financeiro (o que dá para usar). Bens '
                'que você não pretende vender ficam de fora.',
              ),
              value: _isLiquid,
              onChanged: (v) => setState(() => _isLiquid = v),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Salvar'),
            ),
            if (widget.existing != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: () async {
                  await ref
                      .read(wealthRepositoryProvider)
                      .deleteAsset(widget.existing!.id);
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                child: const Text('Excluir'),
              ),
          ],
        ),
      ),
    );
  }
}

/// What the "atualizar valor" sheet ended with.
enum UpdateValueResult { saved, skipped }

/// "Quanto vale hoje?" for one informed item (investment, bem, a receber,
/// saldo devedor), the previous value pre-filled.
Future<UpdateValueResult?> showUpdateValueSheet(
  BuildContext context,
  WealthItem item, {
  String? progress,
}) {
  return showModalBottomSheet<UpdateValueResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _UpdateValueForm(item: item, progress: progress),
  );
}

class _UpdateValueForm extends ConsumerStatefulWidget {
  const _UpdateValueForm({required this.item, this.progress});

  final WealthItem item;
  final String? progress;

  @override
  ConsumerState<_UpdateValueForm> createState() => _UpdateValueFormState();
}

class _UpdateValueFormState extends ConsumerState<_UpdateValueForm> {
  late final _value = TextEditingController(
    text: BrlAmountField.fromApiAmount(widget.item.value),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  String get _question => switch (widget.item.kind) {
    WealthItemKind.debt => 'Quanto você deve hoje?',
    WealthItemKind.account => 'Quanto vale hoje? (veja no app da corretora)',
    _ => 'Quanto vale hoje?',
  };

  Future<void> _save() async {
    final value = BrlAmountField.toApiAmount(_value.text);
    if (value == null) return;
    setState(() => _saving = true);
    final repository = ref.read(wealthRepositoryProvider);
    try {
      switch (widget.item.kind) {
        case WealthItemKind.account:
          await repository.updateInvestmentValue(widget.item.id, value);
        case WealthItemKind.asset:
          await repository.updateAssetValue(widget.item.id, value);
        case WealthItemKind.debt:
          await repository.updateDebtBalance(widget.item.id, value);
        case WealthItemKind.card:
          return;
      }
      if (mounted) Navigator.of(context).pop(UpdateValueResult.saved);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Não foi possível salvar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.progress != null)
            Text(widget.progress!, style: theme.textTheme.labelMedium),
          Text(item.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            item.asOf == null
                ? 'Nunca atualizado · ${formatCurrency(item.value)}'
                : 'Último valor: ${formatCurrency(item.value)} em '
                      '${item.asOf!.day.toString().padLeft(2, '0')}/'
                      '${item.asOf!.month.toString().padLeft(2, '0')}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(_question),
          BrlAmountField(controller: _value, autofocus: true),
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Salvar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(UpdateValueResult.skipped),
            child: Text(widget.progress != null ? 'Pular' : 'Cancelar'),
          ),
        ],
      ),
    );
  }
}
