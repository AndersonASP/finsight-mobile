import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/wealth_providers.dart';
import '../data/settings_repository.dart';

final _reserveTargetProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(settingsRepositoryProvider).reserveTargetMonths(),
);

/// Metas: how many months of cost of living the emergency reserve should
/// cover. Every screen (Patrimônio, "E se?", the destination of the month's
/// savings) reads this one number from the API.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(_reserveTargetProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      body: target.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erro ao carregar: $e'),
        ),
        data: (months) => _ReserveTargetForm(initial: months),
      ),
    );
  }
}

class _ReserveTargetForm extends ConsumerStatefulWidget {
  const _ReserveTargetForm({required this.initial});

  final int initial;

  @override
  ConsumerState<_ReserveTargetForm> createState() => _ReserveTargetFormState();
}

class _ReserveTargetFormState extends ConsumerState<_ReserveTargetForm> {
  late double _months = widget.initial.toDouble();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setReserveTargetMonths(_months.round());
      ref.invalidate(_reserveTargetProvider);
      refreshWealth(ref);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = _months.round();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Reserva de emergência', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Quantos meses do seu custo de vida a reserva deve cobrir. '
          'O mínimo recomendado são 8 meses; 12 ou mais é o ideal, e mais '
          'ainda se você tem dependentes ou renda instável. Enquanto a '
          'reserva não chega aqui, ela é a prioridade do que sobra.',
        ),
        const SizedBox(height: 24),
        Text(
          '$months ${months == 1 ? 'mês' : 'meses'}',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        Slider(
          value: _months,
          min: 1,
          max: 36,
          divisions: 35,
          label: '$months',
          onChanged: (v) => setState(() => _months = v),
        ),
        if (months < 8)
          Text(
            'Abaixo do mínimo de 8 meses recomendado.',
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 24),
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
    );
  }
}
