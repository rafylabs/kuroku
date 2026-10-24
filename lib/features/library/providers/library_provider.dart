import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/database/models/chapter_update.dart';
import '../../../core/services/library_update_service.dart';

enum LibraryFilter { favorites, downloaded, updates }

final libraryFilterProvider = StateProvider<LibraryFilter>((ref) => LibraryFilter.favorites);

final updatesListProvider = FutureProvider<List<ChapterUpdate>>((ref) async {
  return await AppDatabase.instance.getRecentUpdates();
});

final libraryProgressProvider = FutureProvider<Map<String, double>>((ref) async {
  final libraryAsync = ref.watch(libraryProvider);
  final items = libraryAsync.value ?? [];
  if (items.isEmpty) return {};
  final ids = items.map((m) => m.id).toList();
  return await AppDatabase.instance.getReadingProgressForManga(ids);
});

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

  Future<int> checkUpdates({bool silent = false}) async {
    final count = await LibraryUpdateService.instance.checkForUpdates(silent: silent);
    await loadManga();
    ref.invalidate(updatesListProvider);
    return count;
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, AsyncValue<List<Manga>>>((ref) {
  ref.watch(libraryFilterProvider);
  return LibraryNotifier(ref);
});
