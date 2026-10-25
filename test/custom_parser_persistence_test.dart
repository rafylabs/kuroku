import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kuroku/core/parser/parser_registry.dart';
import 'package:kuroku/core/parser/parser_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Parser Persistence & Dynamic Selector Tests', () {
    test('Custom source dual-persistence in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final jsonStr = '''{
        "spec_version": 1,
        "id": "custom_feed",
        "name": "Custom Feed",
        "domain": "example-source.com",
        "locale": "en",
        "type": "html",
        "selectors": {
          "card": "div.grid > div",
          "title": "div.line-clamp-2",
          "cover": "img",
          "chapters": "div#chapters a",
          "pages": "img.js-page"
        }
      }''';

      final config = ParserImporter.fromJsonString(jsonStr);
      await ParserRegistry.instance.addCustomSource(config);

      // Verify registered
      final registered = ParserRegistry.instance.getParser(config.id);
      expect(registered, isNotNull);
      expect(registered!.name, 'Custom Feed');

      // Verify persisted to SharedPreferences backup
      final backup = prefs.getStringList('persisted_custom_sources_v1');
      expect(backup, isNotNull);
      expect(backup!.length, 1);
      final decodedMap = jsonDecode(backup.first) as Map<String, dynamic>;
      expect(decodedMap['id'], 'custom_feed');

      // Verify active parser save & restore
      await ParserRegistry.instance.setActiveParserId(config.id);
      expect(ParserRegistry.instance.activeParser.id, 'custom_feed');
      expect(prefs.getString('kuroku_active_parser_id'), 'custom_feed');

      // Simulate app restart: re-run loadCustomSources() with SharedPreferences
      await ParserRegistry.instance.loadCustomSources();
      expect(ParserRegistry.instance.getParser('custom_feed'), isNotNull);
      expect(ParserRegistry.instance.activeParser.id, 'custom_feed');
    });

    test('DynamicMangaParser parses DOM structures with flexible alias selectors', () async {
      const listHtml = '''
        <div class="container">
          <div class="grid">
            <div>
              <a href="/manga/1/sample-series" class="relative block">
                <figure class="w-full h-52 overflow-hidden bg-card rounded-md">
                  <img data-src="https://cdn.example.com/cover/1.jpeg" alt="Sample Series" class="lazy object-cover"/>
                </figure>
              </a>
              <div class="flex flex-col justify-end">
                <a href="/manga/1/sample-series" class="mb-2">
                  <div class="mt-3 font-black leading-tight line-clamp-2">Sample Series</div>
                </a>
              </div>
            </div>
          </div>
        </div>
      ''';

      const detailHtml = '''
        <div class="container">
          <p class="text-sm">Sample synopsis description...</p>
          <a href="/search?genre=Action">Action</a>
          <a href="/search?genre=Fantasy">Fantasy</a>
          <div id="chapters" class="p-3">
            <a href="/chapters/1-20386000/sample-chapter-386" title=" Group 2 Chapter 386">Group 2 Chapter 386</a>
            <a href="/chapters/1-20385000/sample-chapter-385" title=" Group 2 Chapter 385">Group 2 Chapter 385</a>
          </div>
        </div>
      ''';

      const readerHtml = '''
        <div class="reader-container">
          <img class="js-page" data-src="https://cdn.example.com/pages/1.jpeg" alt="Page 1"/>
          <img class="js-page" data-src="https://cdn.example.com/pages/2.jpeg" alt="Page 2"/>
        </div>
      ''';

      final jsonStr = '''{
        "spec_version": 1,
        "id": "alias_source",
        "name": "Alias Source",
        "domain": "example-source.com",
        "locale": "en",
        "type": "html",
        "headers": {
          "Referer": "https://example-source.com/"
        },
        "urls": {
          "list": "https://example-source.com/search?status=publishing&page={page}",
          "search": "https://example-source.com/search?q={query}&page={page}"
        },
        "selectors": {
          "card": "div.container div.grid > div",
          "card_title": "div.mt-3.font-black, div.line-clamp-2",
          "card_cover": "img",
          "card_cover_attr": "data-src,src",
          "detail_description": "p.text-sm",
          "detail_genres": "a[href*=\\"/search?genre=\\"]",
          "chapter_item": "div#chapters a",
          "chapter_number_regex": "Chapter\\\\s+([0-9.]+)",
          "page_images": "img.js-page",
          "page_image_attr": "data-src,src"
        }
      }''';

      final config = ParserImporter.fromJsonString(jsonStr);
      final selectors = config.selectors!;

      // 1. Verify Card, Title, Cover parsing
      final listDoc = html_parser.parse(listHtml);
      final cardSelector = selectors['card'] as String;
      final titleSelector = selectors['card_title'] as String;
      final coverSelector = selectors['card_cover'] as String;
      final coverAttrs = (selectors['card_cover_attr'] as String).split(',');

      final elements = listDoc.querySelectorAll(cardSelector);
      final mangaCards = <Map<String, String>>[];
      for (final el in elements) {
        final a = el.localName == 'a' ? el : el.querySelector('a');
        if (a == null) continue;
        final href = a.attributes['href'];
        if (href == null || !href.contains('/manga/')) continue;

        final titleEl = el.querySelector(titleSelector) ?? el.parent?.querySelector(titleSelector);
        final title = titleEl?.text.trim() ?? a.attributes['title']?.trim() ?? '';
        if (title.isEmpty) continue;

        final img = el.querySelector(coverSelector) ?? el.parent?.querySelector(coverSelector);
        String cover = '';
        if (img != null) {
          for (final attr in coverAttrs) {
            final v = img.attributes[attr.trim()];
            if (v != null && v.isNotEmpty) {
              cover = v;
              break;
            }
          }
        }
        mangaCards.add({'title': title, 'href': href, 'cover': cover});
      }

      expect(mangaCards.length, 1);
      expect(mangaCards.first['title'], 'Sample Series');
      expect(mangaCards.first['href'], '/manga/1/sample-series');
      expect(mangaCards.first['cover'], startsWith('https://cdn.example.com/cover/1.jpeg'));

      // 2. Verify Chapter parsing
      final detailDoc = html_parser.parse(detailHtml);
      final chSelector = selectors['chapter_item'] as String;
      final chElements = detailDoc.querySelectorAll(chSelector);
      expect(chElements.length, 2);

      final regex = RegExp(selectors['chapter_number_regex'] as String);
      final firstTitle = chElements.first.text.trim();
      final match = regex.firstMatch(firstTitle);
      expect(match, isNotNull);
      expect(match!.group(1), '386');

      // 3. Verify Reader Page parsing
      final readerDoc = html_parser.parse(readerHtml);
      final pageSelector = selectors['page_images'] as String;
      final pageAttrs = (selectors['page_image_attr'] as String).split(',');
      final imgElements = readerDoc.querySelectorAll(pageSelector);
      expect(imgElements.length, 2);

      String? firstPageUrl;
      for (final attr in pageAttrs) {
        final val = imgElements.first.attributes[attr.trim()];
        if (val != null && val.isNotEmpty) {
          firstPageUrl = val;
          break;
        }
      }
      expect(firstPageUrl, isNotNull);
      expect(firstPageUrl, startsWith('https://cdn.example.com/pages/1.jpeg'));
    });
  });
}
