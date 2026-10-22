import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';

class LibraryNotifier extends StateNotifier<AsyncValue<List<Manga>>> {
  LibraryNotifier() : super(const AsyncValue.loading()) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    state = const AsyncValue.loading();
    try {
      final list = await AppDatabase.instance.getFavorites();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> toggleFavorite(Manga manga) async {
    final newStatus = await AppDatabase.instance.toggleFavorite(manga);
    await loadFavorites();
    return newStatus;
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, AsyncValue<List<Manga>>>((ref) {
  return LibraryNotifier();
});
