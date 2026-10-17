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

  // Set once the user picks "criar tag" — switches the sheet to a color-
  // choosing step instead of creating immediately with a round-robin color.
  String? _pendingName;
  Color _pendingColor = categoryColorSwatches.first;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _pendingName;
    if (name == null) return;
    setState(() => _creating = true);
    try {
      final category = await ref
          .read(categoriesRepositoryProvider)
          .create(name: name, color: _pendingColor);
      ref.invalidate(categoriesListProvider);
      if (mounted) Navigator.of(context).pop(category);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível criar a tag: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);

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
        children: _pendingName != null
            ? _buildColorStep(context)
            : _buildSearchStep(context, categoriesAsync),
      ),
    );
  }

  List<Widget> _buildColorStep(BuildContext context) {
    return [
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _creating
                ? null
                : () => setState(() => _pendingName = null),
          ),
          Expanded(
            child: Text(
              'Cor da tag "$_pendingName"',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: categoryColorSwatches.map((color) {
          final selected = color.toARGB32() == _pendingColor.toARGB32();
          return GestureDetector(
            onTap: () => setState(() => _pendingColor = color),
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
        onPressed: _creating ? null : _create,
        child: _creating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Criar tag'),
      ),
    ];
  }

  List<Widget> _buildSearchStep(
    BuildContext context,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    return [
      Text('Tag', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Buscar ou criar uma tag',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
      const SizedBox(height: 8),
      Flexible(
        child: categoriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Erro: $e'),
          ),
          data: (categories) {
            final query = _query.trim().toLowerCase();
            final filtered = query.isEmpty
                ? categories
                : categories
                      .where((c) => c.name.toLowerCase().contains(query))
                      .toList();
            final exactMatch = categories.any(
              (c) => c.name.toLowerCase() == query,
            );

            return ListView(
              shrinkWrap: true,
              children: [
                if (query.isNotEmpty && !exactMatch)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text('Criar tag "${_searchController.text.trim()}"'),
                    onTap: () => setState(
                      () => _pendingName = _searchController.text.trim(),
                    ),
                  ),
                for (final category in filtered)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: category.color,
                      radius: 10,
                    ),
                    title: Text(category.name),
                    onTap: () => Navigator.of(context).pop(category),
                  ),
                if (filtered.isEmpty && (query.isEmpty || exactMatch))
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nenhuma tag ainda. Digite um nome acima para criar.',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ];
  }
}
