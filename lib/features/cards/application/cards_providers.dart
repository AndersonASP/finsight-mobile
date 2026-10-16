import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/cards_repository.dart';
import '../data/fin_card.dart';

final cardsListProvider = FutureProvider.autoDispose<List<FinCard>>((ref) {
  return ref.watch(cardsRepositoryProvider).list();
});
