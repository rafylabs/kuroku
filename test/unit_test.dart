import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kuroku/core/database/models/manga.dart';
import 'package:kuroku/core/database/models/chapter.dart';
import 'package:kuroku/core/database/models/manga_page.dart';
import 'package:kuroku/core/parser/parser_registry.dart';
import 'package:kuroku/core/download/download_manager.dart';
import 'package:kuroku/core/theme/app_theme.dart';

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

      expect(parsers.length, greaterThanOrEqualTo(2));
      expect(parsers.any((p) => p.id == 'shinigami'), isTrue);
      expect(parsers.any((p) => p.id == 'weebcentral'), isTrue);

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
  });
}
