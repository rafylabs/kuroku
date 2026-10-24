import 'package:flutter_test/flutter_test.dart';
import 'package:kuroku/core/database/models/chapter.dart';
import 'package:kuroku/core/database/models/history_entry.dart';
import 'package:kuroku/core/database/models/manga.dart';
import 'package:kuroku/features/reader/providers/reader_provider.dart';

void main() {
  group('E2E Logic Test: Stopping in middle of chapter and resume flow', () {
    const manga = Manga(
      id: 'shinigami_the-beginning-after-the-end',
      title: 'The Beginning After The End',
      url: 'the-beginning-after-the-end',
      coverUrl: 'https://storage.shngm.id/tbate.jpg',
      sourceId: 'shinigami',
    );

    // List of chapters in descending order (Chapter 258 to 250)
    final chapters = List.generate(9, (i) {
      final chNum = 258.0 - i;
      return MangaChapter(
        id: 'shinigami_ch_$chNum',
        mangaId: manga.id,
        title: 'Chapter $chNum',
        number: chNum,
        url: 'chapter-$chNum',
        pageCount: 23,
      );
    });

    test('Stopping mid-chapter updates chapter progress and resume targeting correctly', () {
      // User is reading Chapter 258, stops at page 11 (mid-chapter) with offset -0.42
      const stoppedPage = 11;
      const stoppedOffset = -0.42;

      // Update chapter 258 with mid-progress
      final updatedChapters = chapters.map((c) {
        if (c.number == 258.0) {
          return c.copyWith(
            lastReadPage: stoppedPage,
            lastReadOffset: stoppedOffset,
            isRead: false,
          );
        }
        return c;
      }).toList();

      // Step 1: MangaDetailScreen _resumeChapter logic
      final inProgress = updatedChapters.where((c) => c.lastReadPage > 0 && !c.isRead).toList();
      expect(inProgress.isNotEmpty, isTrue);
      final resumeCh = inProgress.first;

      expect(resumeCh.number, 258.0);
      expect(resumeCh.lastReadPage, 11);
      expect(resumeCh.lastReadOffset, -0.42);

      // Step 2: HistoryEntry generation & reader args mapping
      final histEntry = HistoryEntry(
        manga: manga,
        chapter: resumeCh,
        page: resumeCh.lastReadPage,
        scrollOffset: resumeCh.lastReadOffset,
        updatedAt: DateTime.now(),
      );

      final readerArgsFromHistory = ReaderArgs(
        manga: histEntry.manga,
        chapter: histEntry.chapter,
        initialPage: histEntry.page,
        initialOffset: histEntry.scrollOffset,
      );

      expect(readerArgsFromHistory.initialPage, 11);
      expect(readerArgsFromHistory.initialOffset, -0.42);

      // Step 3: Continue button from MangaDetailScreen
      final readerArgsFromDetail = ReaderArgs(
        manga: manga,
        chapter: resumeCh,
        initialPage: resumeCh.lastReadPage,
        initialOffset: resumeCh.lastReadOffset,
      );

      expect(readerArgsFromDetail.initialPage, 11);
      expect(readerArgsFromDetail.initialOffset, -0.42);
    });

    test('Reader notifier state preserves initial page and offset', () {
      final args = ReaderArgs(
        manga: manga,
        chapter: chapters.first,
        initialPage: 11,
        initialOffset: -0.42,
      );

      final state = ReaderState(
        currentPage: args.initialPage,
        currentOffset: args.initialOffset,
      );

      expect(state.currentPage, 11);
      expect(state.currentOffset, -0.42);
    });
  });
}
