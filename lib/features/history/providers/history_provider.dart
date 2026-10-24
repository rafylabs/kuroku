import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/database/models/history_entry.dart';
import '../../../core/database/models/chapter_update.dart';

enum HistoryFilter {
  all,
  readOnly,
  updatesOnly,
}

class UnifiedHistoryItem {
  final String id;
  final String mangaId;
  final String mangaTitle;
  final String coverUrl;
  final String sourceId;
  final String chapterId;
  final String chapterTitle;
  final double chapterNumber;
  final DateTime timestamp;
  final bool isUpdate;
  final int page;
  final bool isSeen;
  final HistoryEntry? readEntry;
  final ChapterUpdate? updateEntry;

  UnifiedHistoryItem.read(HistoryEntry entry)
      : id = 'read_${entry.manga.id}_${entry.chapter.id}',
        mangaId = entry.manga.id,
        mangaTitle = entry.manga.title,
        coverUrl = entry.manga.coverUrl,
        sourceId = entry.manga.sourceId,
        chapterId = entry.chapter.id,
        chapterTitle = entry.chapter.title,
        chapterNumber = entry.chapter.number,
        timestamp = entry.updatedAt,
        isUpdate = false,
        page = entry.page,
        isSeen = true,
        readEntry = entry,
        updateEntry = null;

  UnifiedHistoryItem.update(ChapterUpdate update)
      : id = 'update_${update.id}',
        mangaId = update.mangaId,
        mangaTitle = update.mangaTitle,
        coverUrl = update.coverUrl,
        sourceId = update.sourceId,
        chapterId = update.chapterId,
        chapterTitle = update.chapterTitle,
        chapterNumber = update.chapterNumber,
        timestamp = update.detectedAt,
        isUpdate = true,
        page = 0,
        isSeen = update.isSeen,
        readEntry = null,
        updateEntry = update;
}

class UpdateCardItem {
  final String mangaId;
  final String mangaTitle;
  final String coverUrl;
  final String sourceId;
  final int updateCount;
  final double readingProgress;
  final bool isFavorite;

  const UpdateCardItem({
    required this.mangaId,
    required this.mangaTitle,
    required this.coverUrl,
    required this.sourceId,
    required this.updateCount,
    required this.readingProgress,
    required this.isFavorite,
  });
}

class UnifiedHistoryData {
  final List<UnifiedHistoryItem> allItems;
  final List<UpdateCardItem> updateCards;
  final int readCount;
  final int updateCount;
  final int unseenUpdateCount;
  final Set<String> favoriteMangaIds;

  const UnifiedHistoryData({
    required this.allItems,
    required this.updateCards,
    required this.readCount,
    required this.updateCount,
    required this.unseenUpdateCount,
    required this.favoriteMangaIds,
  });
}

class HistoryNotifier extends StateNotifier<AsyncValue<UnifiedHistoryData>> {
  HistoryNotifier() : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final readEntries = await AppDatabase.instance.getHistory();
      final updateEntries = await AppDatabase.instance.getRecentUpdates(limit: 100);
      final favorites = await AppDatabase.instance.getFavorites();
      final favIds = favorites.map((m) => m.id).toSet();

      final combined = <UnifiedHistoryItem>[
        ...readEntries.map((e) => UnifiedHistoryItem.read(e)),
        ...updateEntries.map((u) => UnifiedHistoryItem.update(u)),
      ];

      // Sort descending by timestamp (newest first)
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final unseen = updateEntries.where((u) => !u.isSeen).length;

      // Build update cards for top carousel
      final Map<String, int> mangaUpdateCounts = {};
      final Map<String, ChapterUpdate> mangaLatestUpdate = {};
      for (final u in updateEntries) {
        mangaUpdateCounts[u.mangaId] = (mangaUpdateCounts[u.mangaId] ?? 0) + 1;
        mangaLatestUpdate.putIfAbsent(u.mangaId, () => u);
      }

      final targetMangaIds = <String>{};
      targetMangaIds.addAll(mangaLatestUpdate.keys);
      if (targetMangaIds.length < 5) {
        for (final r in readEntries) {
          targetMangaIds.add(r.manga.id);
          if (targetMangaIds.length >= 10) break;
        }
      }

      final progressMap = await AppDatabase.instance.getReadingProgressForManga(targetMangaIds.toList());

      final List<UpdateCardItem> updateCards = [];
      for (final mid in targetMangaIds) {
        if (mangaLatestUpdate.containsKey(mid)) {
          final u = mangaLatestUpdate[mid]!;
          updateCards.add(UpdateCardItem(
            mangaId: u.mangaId,
            mangaTitle: u.mangaTitle,
            coverUrl: u.coverUrl,
            sourceId: u.sourceId,
            updateCount: mangaUpdateCounts[mid] ?? 1,
            readingProgress: progressMap[mid] ?? 0.0,
            isFavorite: favIds.contains(mid),
          ));
        } else {
          final r = readEntries.firstWhere((element) => element.manga.id == mid);
          updateCards.add(UpdateCardItem(
            mangaId: r.manga.id,
            mangaTitle: r.manga.title,
            coverUrl: r.manga.coverUrl,
            sourceId: r.manga.sourceId,
            updateCount: 0,
            readingProgress: progressMap[mid] ?? 0.0,
            isFavorite: favIds.contains(mid),
          ));
        }
      }

      state = AsyncValue.data(UnifiedHistoryData(
        allItems: combined,
        updateCards: updateCards,
        readCount: readEntries.length,
        updateCount: updateEntries.length,
        unseenUpdateCount: unseen,
        favoriteMangaIds: favIds,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleFavorite(String mangaId, String title, String coverUrl, String sourceId) async {
    final manga = await AppDatabase.instance.getManga(mangaId) ??
        Manga(id: mangaId, title: title, url: mangaId, coverUrl: coverUrl, sourceId: sourceId);
    await AppDatabase.instance.toggleFavorite(manga);
    await loadHistory();
  }

  Future<void> markAllUpdatesSeen() async {
    await AppDatabase.instance.markAllUpdatesSeen();
    await loadHistory();
  }

  Future<void> clearReadingHistory() async {
    await AppDatabase.instance.clearHistory();
    await loadHistory();
  }

  Future<void> clearUpdateNotifications() async {
    await AppDatabase.instance.clearUpdates();
    await loadHistory();
  }

  Future<void> clearAll() async {
    await AppDatabase.instance.clearHistory();
    await AppDatabase.instance.clearUpdates();
    await loadHistory();
  }

  Future<void> deleteItem(UnifiedHistoryItem item) async {
    if (item.isUpdate) {
      if (item.updateEntry != null) {
        final db = await AppDatabase.instance.database;
        await db.delete('chapter_updates', where: 'id = ?', whereArgs: [item.updateEntry!.id]);
      }
    } else {
      if (item.readEntry != null) {
        await AppDatabase.instance.deleteHistoryEntry(item.mangaId, item.chapterId);
      }
    }
    await loadHistory();
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, AsyncValue<UnifiedHistoryData>>((ref) {
  return HistoryNotifier();
});
