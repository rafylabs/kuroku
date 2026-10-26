import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kuroku/core/parser/parser_registry.dart';
import 'package:kuroku/core/parser/parser_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Parser Persistence & Default Parser Architecture Tests', () {
    test('Default source is registered as default parser in ParserRegistry', () async {
      SharedPreferences.setMockInitialValues({});
      ParserRegistry.instance.resetForTesting();

      // App initial load
      await ParserRegistry.instance.loadCustomSources();

      // Default parser is mangapill
      expect(ParserRegistry.instance.defaultParser.id, 'mangapill');
      expect(ParserRegistry.instance.activeParser.id, 'mangapill');

      // 3 built-in parsers registered
      final parsers = ParserRegistry.instance.allParsers;
      expect(parsers.length, 3);
      final ids = parsers.map((p) => p.id).toList();
      expect(ids, containsAll(['mangapill', 'shinigami', 'weebcentral']));
    });

    test('Active parser selection and domain overrides persist across app restart', () async {
      SharedPreferences.setMockInitialValues({});
      ParserRegistry.instance.resetForTesting();
      final prefs = await SharedPreferences.getInstance();

      // 1. Initial load
      await ParserRegistry.instance.loadCustomSources();
      expect(ParserRegistry.instance.activeParser.id, 'mangapill');

      // 2. User switches active parser to weebcentral
      await ParserRegistry.instance.setActiveParserId('weebcentral');
      expect(ParserRegistry.instance.activeParser.id, 'weebcentral');
      expect(prefs.getString('kuroku_active_parser_id'), 'weebcentral');

      // 3. User updates custom domain
      await ParserRegistry.instance.updateSourceDomain('mangapill', 'mirror.mangapill.com');
      expect(prefs.getString('domain_mangapill'), 'mirror.mangapill.com');
      expect(ParserRegistry.instance.getParser('mangapill')!.domain, 'mirror.mangapill.com');

      // 4. Simulate app restart
      ParserRegistry.instance.resetForTesting();
      await ParserRegistry.instance.loadCustomSources();

      // Active parser restored to weebcentral
      expect(ParserRegistry.instance.activeParser.id, 'weebcentral');

      // Overridden domain restored
      expect(ParserRegistry.instance.getParser('mangapill')!.domain, 'mirror.mangapill.com');
    });

    test('Legacy custom source ID mapping (custom_mangapill -> mangapill)', () {
      final parser = ParserRegistry.instance.getParser('custom_mangapill');
      expect(parser, isNotNull);
      expect(parser!.id, 'mangapill');
    });

    test('HTML selector and regex extraction logic compatibility', () {
      const listHtml = '''
        <div class="container">
          <div class="grid">
            <div>
              <a href="/manga/1/sample-series">
                <img data-src="https://cdn.example.com/cover/1.jpeg" alt="Cover" />
              </a>
              <div class="mt-3 font-black">Sample Series</div>
            </div>
          </div>
        </div>
      ''';

      const detailHtml = '''
        <div id="chapters">
          <a href="/chapters/1-10001/sample-series-chapter-386">Chapter 386</a>
          <a href="/chapters/1-10002/sample-series-chapter-385">Chapter 385</a>
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
