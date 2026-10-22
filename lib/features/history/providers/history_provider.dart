import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/history_entry.dart';

class HistoryNotifier extends StateNotifier<AsyncValue<List<HistoryEntry>>> {
  HistoryNotifier() : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final list = await AppDatabase.instance.getHistory();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, AsyncValue<List<HistoryEntry>>>((ref) {
  return HistoryNotifier();
});
