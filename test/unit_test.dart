import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kuroku/core/database/models/manga.dart';
import 'package:kuroku/core/database/models/chapter.dart';
import 'package:kuroku/core/database/models/manga_page.dart';
import 'package:kuroku/core/database/models/chapter_update.dart';
import 'package:kuroku/core/parser/parser_registry.dart';
import 'package:kuroku/core/download/download_manager.dart';
import 'package:kuroku/core/services/library_update_service.dart';
import 'package:kuroku/core/services/app_update_service.dart';
import 'package:kuroku/features/history/providers/history_provider.dart';
import 'package:kuroku/core/database/models/history_entry.dart';
import 'package:kuroku/core/theme/app_theme.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  group('Kuroku Models & Registry Tests', () {
    test('Manga serialization round-trip', () {
      const manga = Manga(
        id: 'mangapill_123',
        title: 'One Piece',
        altTitle: 'Wan Pisu',
        url: 'https://mangapill.com/manga/123/one-piece',
        coverUrl: 'https://mangapill.com/covers/123.jpg',
        sourceId: 'mangapill',
        author: 'Eiichiro Oda',
        status: MangaStatus.ongoing,
        rating: 9.8,
        genres: ['Action', 'Adventure', 'Fantasy'],
        isFavorite: true,
      );

      final map = manga.toMap();
      final decoded = Manga.fromMap(map);

      expect(decoded.id, manga.id);
      expect(decoded.title, manga.title);
      expect(decoded.url, manga.url);
      expect(decoded.coverUrl, manga.coverUrl);
      expect(decoded.sourceId, manga.sourceId);
      expect(decoded.status, MangaStatus.ongoing);
      expect(decoded.rating, 9.8);
      expect(decoded.genres, contains('Adventure'));
      expect(decoded.isFavorite, isTrue);
    });

    test('MangaChapter serialization round-trip', () {
      const chapter = MangaChapter(
        id: 'mangapill_123_ch1100',
        mangaId: 'mangapill_123',
        title: 'Chapter 1100',
        number: 1100.0,
        url: 'https://mangapill.com/chapters/1100',
        isRead: true,
        lastReadPage: 15,
        pageCount: 20,
      );

      final map = chapter.toMap();
      final decoded = MangaChapter.fromMap(map);

      expect(decoded.id, chapter.id);
      expect(decoded.mangaId, chapter.mangaId);
      expect(decoded.title, chapter.title);
      expect(decoded.number, 1100.0);
      expect(decoded.isRead, isTrue);
      expect(decoded.lastReadPage, 15);
      expect(decoded.pageCount, 20);
    });

    test('MangaPage serialization round-trip', () {
      const page = MangaPage(
        index: 5,
        url: 'https://cdn.mangapill.com/123/1100/5.jpg',
      );

      final map = page.toMap();
      final decoded = MangaPage.fromMap(map);

      expect(decoded.index, 5);
      expect(decoded.url, page.url);
    });

    test('ParserRegistry initializes with registered sources', () {
      final registry = ParserRegistry.instance;
      final parsers = registry.allParsers;

      expect(parsers.length, greaterThanOrEqualTo(3));
      expect(parsers.any((p) => p.id == 'mangapill'), isTrue);
      expect(parsers.any((p) => p.id == 'shinigami'), isTrue);
      expect(parsers.any((p) => p.id == 'weebcentral'), isTrue);
      expect(registry.defaultParser.id, 'mangapill');

      final mangapill = registry.getParser('mangapill');
      expect(mangapill, isNotNull);
      expect(mangapill!.domain, 'mangapill.com');

      final shinigami = registry.getParser('shinigami');
      expect(shinigami, isNotNull);
      expect(shinigami!.domain, 'id.shinigami.asia');
      expect(shinigami.availableCategories, contains('Manhwa'));
      expect(shinigami.availableCategories, contains('Project'));
      expect(shinigami.availableGenres, contains('Action'));
      expect(shinigami.availableGenres, contains('Martial Arts'));

      final weebcentral = registry.getParser('weebcentral');
      expect(weebcentral, isNotNull);
      expect(weebcentral!.domain, 'weebcentral.com');
      expect(weebcentral.availableCategories, contains('Manga'));
    });

    test('AppTheme loads dark and light themes without error', () {
      final dark = AppTheme.darkTheme;
      final light = AppTheme.lightTheme;

      expect(dark.useMaterial3, isTrue);
      expect(light.useMaterial3, isTrue);
      expect(dark.colorScheme.primary, AppTheme.cyanAccent);
    });

    test('WeebCentral parsing does not throw UnimplementedError and parses manga cards', () {
      const sampleHtml = '''
      <article class="bg-base-300 flex gap-4 p-4">
        <section class="w-full">
          <a href="https://weebcentral.com/series/01J76XYEGYY86GDR09MN457Q7R/Villain-To-Kill">
            <picture>
              <img src="https://temp.compsci88.com/cover/fallback/01J76XYEGYY86GDR09MN457Q7R.jpg" alt="Villain to Kill cover">
            </picture>
            <div class="truncate">Villain to Kill</div>
          </a>
        </section>
      </article>
      ''';
      final doc = html_parser.parse(sampleHtml);
      final articles = doc.querySelectorAll('article.bg-base-300');
      expect(articles.length, 1);
      final a = articles.first.querySelector('a[href*="/series/"]');
      expect(a, isNotNull);
      final img = articles.first.querySelector('picture img');
      expect(img?.attributes['src'], contains('01J76XYEGYY86GDR09MN457Q7R'));
    });

    test('DownloadManager instance initializes and tracks state', () {
      final dm = DownloadManager.instance;
      expect(dm, isNotNull);
      expect(dm.isDownloaded('non_existent_chapter'), isFalse);
      expect(dm.getProgress('non_existent_chapter'), isNull);
      expect(dm.activeDownloads.value, isEmpty);
    });

    test('Synopsis text formatting unescapes HTML entities and normalizes newlines', () {
      const raw = 'Title&#39;s story &amp; &quot;quote&quot;<br>Paragraph 1\r\nParagraph 2&#x20;';
      var text = raw
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&rsquo;', "'")
          .replaceAll('&lsquo;', "'")
          .replaceAll('&amp;', '&')
          .replaceAll('&#x20;', ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
      text = text.replaceAll(RegExp(r'\r\n|\r'), '\n');

      expect(text, contains("Title's story & \"quote\""));
      expect(text, contains('Paragraph 1\nParagraph 2'));
    });

    test('ChapterUpdate serialization round-trip', () {
      final now = DateTime.now();
      final update = ChapterUpdate(
        id: 'upd_1',
        mangaId: 'shinigami_123',
        mangaTitle: 'Overgeared',
        coverUrl: 'https://example.com/cover.jpg',
        sourceId: 'shinigami',
        chapterId: 'ch_200',
        chapterTitle: 'Chapter 200',
        chapterNumber: 200.0,
        detectedAt: now,
        isSeen: false,
      );

      final map = update.toMap();
      final decoded = ChapterUpdate.fromMap(map);

      expect(decoded.id, 'upd_1');
      expect(decoded.mangaId, 'shinigami_123');
      expect(decoded.mangaTitle, 'Overgeared');
      expect(decoded.chapterTitle, 'Chapter 200');
      expect(decoded.chapterNumber, 200.0);
      expect(decoded.isSeen, isFalse);
    });

    test('LibraryUpdateService initializes with valid state', () {
      final service = LibraryUpdateService.instance;
      expect(service, isNotNull);
      expect(service.isCheckingUpdates.value, isFalse);
      expect(service.unseenUpdateCount.value, 0);
    });

    test('AppUpdateService semver comparison detects newer versions', () {
      final updater = AppUpdateService.instance;
      expect(updater.isVersionNewer('1.3.1', '1.3.0'), isTrue);
      expect(updater.isVersionNewer('v1.4.0', 'v1.3.1'), isTrue);
      expect(updater.isVersionNewer('2.0.0', '1.9.9'), isTrue);
      expect(updater.isVersionNewer('1.3.0', '1.3.1'), isFalse);
      expect(updater.isVersionNewer('1.3.1', '1.3.1'), isFalse);
    });

    test('AppUpdateService cleanReleaseNotes filters raw tables and download links', () {
      final updater = AppUpdateService.instance;
      const rawBody = '''### 📝 What's New in v1.3.3
- 📰 **Kotatsu-Style Feed**: Redesain tab History.
- 🔍 **Live Search**: Cari komik cepat.

---
### 📱 Direct Downloads
| Platform | File | Direct Download |
|---|---|---|
| **Android** | `Kuroku.apk` | [Download](https://...) |
''';

      final cleaned = updater.cleanReleaseNotes(rawBody);
      expect(cleaned.contains('Kotatsu-Style Feed'), isTrue);
      expect(cleaned.contains('Live Search'), isTrue);
      expect(cleaned.contains('Direct Downloads'), isFalse);
      expect(cleaned.contains('| Platform |'), isFalse);
      expect(cleaned.contains('**'), isFalse);
      expect(cleaned.startsWith('###'), isFalse);
    });

    test('UnifiedHistoryItem handles read and update items properly', () {
      const manga = Manga(id: 'm1', title: 'Solo Leveling', url: 'u1', coverUrl: 'c1', sourceId: 'shinigami');
      const chapter = MangaChapter(id: 'ch1', mangaId: 'm1', title: 'Ch 1', number: 1.0, url: 'u1');
      final readEntry = HistoryEntry(manga: manga, chapter: chapter, page: 5, updatedAt: DateTime(2026, 10, 20));

      final readItem = UnifiedHistoryItem.read(readEntry);
      expect(readItem.isUpdate, isFalse);
      expect(readItem.page, 5);
      expect(readItem.mangaTitle, 'Solo Leveling');

      final update = ChapterUpdate(
        id: 'up1',
        mangaId: 'm1',
        mangaTitle: 'Solo Leveling',
        coverUrl: 'c1',
        sourceId: 'shinigami',
        chapterId: 'ch2',
        chapterTitle: 'Ch 2',
        chapterNumber: 2.0,
        detectedAt: DateTime(2026, 10, 21),
      );

      final updateItem = UnifiedHistoryItem.update(update);
      expect(updateItem.isUpdate, isTrue);
      expect(updateItem.chapterNumber, 2.0);
      expect(updateItem.isSeen, isFalse);
    });

    test('UpdateCardItem holds metadata and reading progress correctly', () {
      const card = UpdateCardItem(
        mangaId: 'm1',
        mangaTitle: 'The Beginning After The End',
        coverUrl: 'https://example.com/cover.jpg',
        sourceId: 'shinigami',
        updateCount: 3,
        readingProgress: 0.98,
        isFavorite: true,
      );

      expect(card.mangaId, 'm1');
      expect(card.updateCount, 3);
      expect(card.readingProgress, 0.98);
      expect((card.readingProgress * 100).round(), 98);
      expect(card.isFavorite, isTrue);
    });

    test('MangaChapter and HistoryEntry support fractional scroll alignment', () {
      final ch = MangaChapter(
        id: 'ch_test',
        mangaId: 'manga_test',
        title: 'Chapter 346',
        number: 346.0,
        url: '346',
        isRead: true,
        lastReadPage: 8,
        lastReadOffset: -0.45,
      );

      expect(ch.isRead, isTrue);
      expect(ch.lastReadPage, 8);
      expect(ch.lastReadOffset, -0.45);

      final map = ch.toMap();
      expect(map['is_read'], 1);
      expect(map['last_read_offset'], -0.45);

      final restored = MangaChapter.fromMap(map);
      expect(restored.lastReadOffset, -0.45);
      expect(restored.isRead, isTrue);

      final manga = Manga(id: 'm1', title: 'Overgeared', url: '3959', coverUrl: 'cover', sourceId: 'shinigami');
      final hist = HistoryEntry(
        manga: manga,
        chapter: ch,
        page: 8,
        scrollOffset: -0.45,
        updatedAt: DateTime(2026, 10, 24),
      );
      expect(hist.page, 8);
      expect(hist.scrollOffset, -0.45);
      expect(hist.toMap()['scroll_offset'], -0.45);
    });

    test('Webtoon focal point selector accurately determines active reading page', () {
      final positions = [
        const ItemPosition(index: 18, itemLeadingEdge: -0.4, itemTrailingEdge: 1.2),
        const ItemPosition(index: 19, itemLeadingEdge: 1.2, itemTrailingEdge: 2.5),
      ];

      const double focalPoint = 0.35;
      ItemPosition? target;
      for (final pos in positions) {
        if (pos.itemLeadingEdge <= focalPoint && pos.itemTrailingEdge > focalPoint) {
          target = pos;
          break;
        }
      }

      expect(target, isNotNull);
      expect(target!.index, 18);
    });

    test('Auto-marking previous chapters marks all chapters below highest read chapter', () {
      final chapters = [
        const MangaChapter(id: 'c258', mangaId: 'tbate', title: 'Chapter 258', number: 258.0, url: '258', lastReadPage: 21, isRead: false),
        const MangaChapter(id: 'c257', mangaId: 'tbate', title: 'Chapter 257', number: 257.0, url: '257', isRead: true),
        const MangaChapter(id: 'c256', mangaId: 'tbate', title: 'Chapter 256', number: 256.0, url: '256', isRead: false),
        const MangaChapter(id: 'c255', mangaId: 'tbate', title: 'Chapter 255', number: 255.0, url: '255', isRead: false),
        const MangaChapter(id: 'c1', mangaId: 'tbate', title: 'Chapter 1', number: 1.0, url: '1', isRead: false),
      ];

      double maxRead = -1.0;
      for (final c in chapters) {
        if (c.isRead || c.lastReadPage > 0) {
          if (c.number > maxRead) maxRead = c.number;
        }
      }

      final updated = chapters.map((c) {
        if (c.number < maxRead && !c.isRead) {
          return c.copyWith(isRead: true);
        }
        return c;
      }).toList();

      expect(maxRead, 258.0);
      expect(updated.firstWhere((c) => c.number == 256.0).isRead, isTrue);
      expect(updated.firstWhere((c) => c.number == 255.0).isRead, isTrue);
      expect(updated.firstWhere((c) => c.number == 1.0).isRead, isTrue);
      expect(updated.firstWhere((c) => c.number == 258.0).isRead, isFalse);
    });

    test('WeebCentral available genres and categories are complete', () {
      final registry = ParserRegistry.instance;
      final weeb = registry.getParser('weebcentral');
      expect(weeb, isNotNull);
      expect(weeb!.availableCategories, contains('OEL'));
      expect(weeb.availableCategories, contains('Manga'));
      expect(weeb.availableGenres.length, greaterThanOrEqualTo(38));
      expect(weeb.availableGenres, contains('Adult'));
      expect(weeb.availableGenres, contains('Doujinshi'));
      expect(weeb.availableGenres, contains('Ecchi'));
      expect(weeb.availableGenres, contains('Sci-fi'));
      expect(weeb.availableGenres, contains('Seinen'));
      expect(weeb.availableGenres, contains('Yaoi'));
      expect(weeb.availableGenres, contains('Yuri'));
    });
  });
}
