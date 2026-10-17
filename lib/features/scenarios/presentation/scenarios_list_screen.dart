import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/scenarios_providers.dart';
import '../data/scenario.dart';
import '../data/scenarios_repository.dart';
import 'scenario_detail_screen.dart';

class ScenariosListScreen extends ConsumerWidget {
  const ScenariosListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenariosAsync = ref.watch(scenariosListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Simulações')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: scenariosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (scenarios) {
          if (scenarios.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma simulação ainda.\nToque em + para criar um cenário.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            itemCount: scenarios.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final scenario = scenarios[index];
              return ListTile(
                leading: Icon(switch (scenario.status) {
                  ScenarioStatus.draft => Icons.science_outlined,
                  ScenarioStatus.confirmed => Icons.check_circle_outline,
                  ScenarioStatus.discarded => Icons.delete_outline,
                }),
                title: Text(scenario.name),
                subtitle: Text(scenario.status.label),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ScenarioDetailScreen(scenarioId: scenario.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateScenarioSheet(),
    );
  }
}

class _CreateScenarioSheet extends ConsumerStatefulWidget {
  const _CreateScenarioSheet();

  @override
  ConsumerState<_CreateScenarioSheet> createState() =>
      _CreateScenarioSheetState();
}

class _CreateScenarioSheetState extends ConsumerState<_CreateScenarioSheet> {
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final scenario = await ref
        .read(scenariosRepositoryProvider)
        .create(name: _nameController.text.trim());
    ref.invalidate(scenariosListProvider);
    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScenarioDetailScreen(scenarioId: scenario.id),
        ),
      );
    }
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
          Text('Novo cenário', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome (ex: E se eu comprar um notebook?)',
            ),
            autofocus: true,
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
                : const Text('Criar'),
          ),
        ],
      ),
    );
  }
}
