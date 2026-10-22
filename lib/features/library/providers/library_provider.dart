import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';

enum LibraryFilter { favorites, downloaded }

final libraryFilterProvider = StateProvider<LibraryFilter>((ref) => LibraryFilter.favorites);

class LibraryNotifier extends StateNotifier<AsyncValue<List<Manga>>> {
  final Ref ref;

  LibraryNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadManga();
  }

  Future<void> loadManga() async {
    state = const AsyncValue.loading();
    try {
      final filter = ref.read(libraryFilterProvider);
      final list = filter == LibraryFilter.favorites
          ? await AppDatabase.instance.getFavorites()
          : await AppDatabase.instance.getDownloadedManga();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> toggleFavorite(Manga manga) async {
    final newStatus = await AppDatabase.instance.toggleFavorite(manga);
    await loadManga();
    return newStatus;
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, AsyncValue<List<Manga>>>((ref) {
  ref.watch(libraryFilterProvider);
  return LibraryNotifier(ref);
});
