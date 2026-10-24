import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/app_database.dart';
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

class UnifiedHistoryData {
  final List<UnifiedHistoryItem> allItems;
  final int readCount;
  final int updateCount;
  final int unseenUpdateCount;

  const UnifiedHistoryData({
    required this.allItems,
    required this.readCount,
    required this.updateCount,
    required this.unseenUpdateCount,
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

      final combined = <UnifiedHistoryItem>[
        ...readEntries.map((e) => UnifiedHistoryItem.read(e)),
        ...updateEntries.map((u) => UnifiedHistoryItem.update(u)),
      ];

      // Sort descending by timestamp (newest first)
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final unseen = updateEntries.where((u) => !u.isSeen).length;

      state = AsyncValue.data(UnifiedHistoryData(
        allItems: combined,
        readCount: readEntries.length,
        updateCount: updateEntries.length,
        unseenUpdateCount: unseen,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
