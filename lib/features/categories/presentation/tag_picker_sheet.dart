import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/categories_providers.dart';
import '../data/categories_repository.dart';
import '../data/category.dart';

/// Lets the user search their existing tags, or create a new one on the spot
/// if none matches — so adding a transaction never blocks on "go create the
/// tag first". Returns the chosen/created [Category], or null if dismissed.
Future<Category?> showTagPickerSheet(BuildContext context) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TagPickerSheet(),
  );
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet();

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _creating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createAndSelect(String name, List<Category> existing) async {
    setState(() => _creating = true);
    final color = categoryColorSwatches[existing.length % categoryColorSwatches.length];
    try {
      final category = await ref.read(categoriesRepositoryProvider).create(name: name.trim(), color: color);
      ref.invalidate(categoriesListProvider);
      if (mounted) Navigator.of(context).pop(category);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível criar a tag: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tag', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Buscar ou criar uma tag', prefixIcon: Icon(Icons.search)),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: categoriesAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Erro: $e')),
              data: (categories) {
                final query = _query.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? categories
                    : categories.where((c) => c.name.toLowerCase().contains(query)).toList();
                final exactMatch = categories.any((c) => c.name.toLowerCase() == query);

                return ListView(
                  shrinkWrap: true,
                  children: [
                    if (query.isNotEmpty && !exactMatch)
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline),
                        title: Text('Criar tag "${_searchController.text.trim()}"'),
                        enabled: !_creating,
                        onTap: () => _createAndSelect(_searchController.text, categories),
                      ),
                    for (final category in filtered)
                      ListTile(
                        leading: CircleAvatar(backgroundColor: category.color, radius: 10),
                        title: Text(category.name),
                        onTap: () => Navigator.of(context).pop(category),
                      ),
                    if (filtered.isEmpty && (query.isEmpty || exactMatch))
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhuma tag ainda. Digite um nome acima para criar.'),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
