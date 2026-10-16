import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/day_detail_item.dart';
import '../../reports/data/reports_repository.dart';

final dayDetailProvider = FutureProvider.autoDispose.family<List<DayDetailItem>, DateTime>((ref, date) {
  return ref.watch(reportsRepositoryProvider).dayDetail(date);
});
