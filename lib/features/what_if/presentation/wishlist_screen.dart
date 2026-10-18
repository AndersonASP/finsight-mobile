import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../application/what_if_providers.dart';
import '../data/what_if.dart';
import '../data/what_if_repository.dart';
import 'what_if_result_view.dart';
import 'what_if_screen.dart';

/// "Quero comprar": purchases the user is waiting on, each with today's
/// "E se?" answer. The app re-checks them on every sync and notifies when
/// one starts to fit without breaking the savings target.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context, WishlistItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tirar da lista?'),
        content: Text(
          '${item.description} (${formatCurrency(item.amount)}) sai de Quero comprar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tirar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(wishlistProvider);
    // What the user has seen doesn't need a notification later.
    ref.listen(wishlistProvider, (_, next) {
      final items = next.value;
      if (items != null) ref.read(wishlistWatcherProvider).remember(items);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Quero comprar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const WhatIfScreen())),
        icon: const Icon(Icons.add),
        label: const Text('E se?'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(wishlistProvider.future),
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Não foi possível carregar: $e'),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nada por aqui. Simule uma compra em "E se?" e salve '
                        'aqui: o app avisa quando ela passar a caber sem furar '
                        'sua reserva.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context, item),
                      onDismissed: (_) async {
                        await ref
                            .read(whatIfRepositoryProvider)
                            .removeFromWishlist(item.id);
                        ref.invalidate(wishlistProvider);
                      },
                      child: ListTile(
                        title: Text(item.description),
                        subtitle: Text(
                          item.simulacao.manchete,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatCurrency(item.amount)),
                            const SizedBox(height: 4),
                            VerdictChip(item.simulacao.verdict),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _WishlistItemScreen(item: item),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _WishlistItemScreen extends StatelessWidget {
  const _WishlistItemScreen({required this.item});

  final WishlistItem item;

  @override
  Widget build(BuildContext context) =>
      WhatIfResultScreen(result: item.simulacao, title: item.description);
}
