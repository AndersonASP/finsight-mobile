import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../../core/widgets/today_button.dart';
import '../application/categories_providers.dart';
import '../data/categories_repository.dart';
import '../data/category.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final month = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        leading: const TodayButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateCategorySheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthSelector(month: month),
          const Divider(height: 1),
          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Erro ao carregar tags: $error')),
              data: (categories) {
                if (categories.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma tag cadastrada ainda.'),
                  );
                }
                return ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _CategoryTile(category: categories[index], month: month),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateCategorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateCategorySheet(),
    );
  }
}

class _MonthSelector extends ConsumerWidget {
  const _MonthSelector({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                month.previousMonth,
          ),
          Text(
            formatMonth(month),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                month.nextMonth,
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category, required this.month});

  final Category category;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalFuture = ref
        .watch(categoriesRepositoryProvider)
        .getTotal(category.id, year: month.year, month: month.month);

    return ListTile(
      leading: CircleAvatar(backgroundColor: category.color, radius: 10),
      title: Text(category.name),
      trailing: FutureBuilder<String>(
        future: totalFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return Text(
            formatCurrency(snapshot.data!),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          );
        },
      ),
      onLongPress: () => _confirmDelete(context, ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir tag?'),
        content: Text('Remover "${category.name}" permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(categoriesRepositoryProvider).delete(category.id);
              ref.invalidate(categoriesListProvider);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _CreateCategorySheet extends ConsumerStatefulWidget {
  const _CreateCategorySheet();

  @override
  ConsumerState<_CreateCategorySheet> createState() =>
      _CreateCategorySheetState();
}

class _CreateCategorySheetState extends ConsumerState<_CreateCategorySheet> {
  final _nameController = TextEditingController();
  Color _color = categoryColorSwatches.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(categoriesRepositoryProvider)
        .create(name: _nameController.text.trim(), color: _color);
    ref.invalidate(categoriesListProvider);
    if (mounted) Navigator.of(context).pop();
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
          Text('Nova tag', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: categoryColorSwatches.map((color) {
              final selected = color.toARGB32() == _color.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _color = color),
                child: CircleAvatar(
                  backgroundColor: color,
                  radius: selected ? 16 : 13,
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
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
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
