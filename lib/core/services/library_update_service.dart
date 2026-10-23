import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../database/models/chapter_update.dart';
import '../parser/parser_registry.dart';
import '../notifications/notification_service.dart';

class LibraryUpdateService {
  static final LibraryUpdateService instance = LibraryUpdateService._internal();
  LibraryUpdateService._internal();

  final ValueNotifier<bool> isCheckingUpdates = ValueNotifier(false);
  final ValueNotifier<int> unseenUpdateCount = ValueNotifier(0);
  Timer? _periodicTimer;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await NotificationService.instance.init();
    await refreshUnseenCount();

    // Start periodic background check every 30 minutes while active
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      checkForUpdates(silent: false);
    });

    // Check shortly after app launch
    Future.delayed(const Duration(seconds: 4), () {
      checkForUpdates(silent: false);
    });
  }

  Future<void> refreshUnseenCount() async {
    final count = await AppDatabase.instance.getUnseenUpdateCount();
    unseenUpdateCount.value = count;
  }

  void dispose() {
    _periodicTimer?.cancel();
  }

  Future<int> checkForUpdates({bool silent = false}) async {
    if (isCheckingUpdates.value) return 0;
    isCheckingUpdates.value = true;

    int totalNewChaptersFound = 0;

    try {
      final favorites = await AppDatabase.instance.getFavorites();
      if (favorites.isEmpty) return 0;

      for (final manga in favorites) {
        try {
          final parser = ParserRegistry.instance.getParser(manga.sourceId);
          if (parser == null) continue;

          // Fetch latest chapters from remote source
          final remoteChapters = await parser.getChapters(manga);
          if (remoteChapters.isEmpty) continue;

          // Get existing local chapters from SQLite
          final localChapters = await AppDatabase.instance.getChapters(manga.id);

          if (localChapters.isEmpty) {
            // First time saving chapters: save without emitting spam notifications
            await AppDatabase.instance.upsertChapters(remoteChapters);
            continue;
          }

          final localIds = localChapters.map((c) => c.id).toSet();
          final maxLocalNumber = localChapters.isEmpty
              ? 0.0
              : localChapters.map((c) => c.number).reduce((a, b) => a > b ? a : b);

          // New chapters are those not in local database AND with chapter number >= maxLocalNumber
          final newChapters = remoteChapters.where((c) {
            return !localIds.contains(c.id) && c.number >= maxLocalNumber;
          }).toList();

          if (newChapters.isNotEmpty) {
            newChapters.sort((a, b) => b.number.compareTo(a.number));
            totalNewChaptersFound += newChapters.length;

            // Save new chapters to SQLite
            await AppDatabase.instance.upsertChapters(newChapters);

            // Create update logs
            final now = DateTime.now();
            final updates = newChapters.map((ch) {
              return ChapterUpdate(
                id: 'upd_${manga.id}_${ch.id}_${now.millisecondsSinceEpoch}',
                mangaId: manga.id,
                mangaTitle: manga.title,
                coverUrl: manga.coverUrl,
                sourceId: manga.sourceId,
                chapterId: ch.id,
                chapterTitle: ch.title,
                chapterNumber: ch.number,
                detectedAt: now,
              );
            }).toList();

            await AppDatabase.instance.saveChapterUpdates(updates);

            if (!silent) {
              final notifId = manga.id.hashCode.abs() % 100000;
              await NotificationService.instance.showChapterUpdateNotification(
                id: notifId,
                mangaTitle: manga.title,
                chapterTitle: newChapters.first.title,
                newCount: newChapters.length,
                payload: manga.id,
              );
            }
          }
        } catch (_) {}
      }

      await refreshUnseenCount();
    } finally {
      isCheckingUpdates.value = false;
    }

    return totalNewChaptersFound;
  }
}
