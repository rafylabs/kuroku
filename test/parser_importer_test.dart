import 'package:flutter_test/flutter_test.dart';
import 'package:kuroku/core/parser/dynamic_manga_parser.dart';
import 'package:kuroku/core/parser/parser_importer.dart';

void main() {
  group('ParserImporter JSON Spec Tests', () {
    test('Successfully import valid HTML scraper spec', () {
      final jsonStr = '''{
        "id": "flame_comics",
        "name": "Flame Comics",
        "domain": "flamecomics.xyz",
        "locale": "en",
        "type": "html",
        "headers": {
          "Referer": "https://flamecomics.xyz/"
        },
        "urls": {
          "list": "https://{domain}/series?page={page}",
          "search": "https://{domain}/series?search={query}"
        },
        "selectors": {
          "card": "div.series-card",
          "title": "h3.title",
          "cover": "img.thumbnail",
          "coverAttr": "data-src,src",
          "chapters": "div.chapter-list a",
          "chapterNumberRegex": "([0-9.]+)",
          "pages": "div.reading-content img",
          "pageAttr": "data-src,src"
        }
      }''';

      final config = ParserImporter.fromJsonString(jsonStr);
      expect(config.id, 'custom_flame_comics');
      expect(config.name, 'Flame Comics');
      expect(config.domain, 'flamecomics.xyz');
      expect(config.locale, 'en');
      expect(config.type, 'html');
      expect(config.customHeaders?['Referer'], 'https://flamecomics.xyz/');
      expect(config.urls?['list'], 'https://{domain}/series?page={page}');
      expect(config.selectors?['card'], 'div.series-card');
      expect(config.selectors?['coverAttr'], 'data-src,src');

      final parser = DynamicMangaParser(config);
      expect(parser.id, 'custom_flame_comics');
      expect(parser.name, 'Flame Comics');
      expect(parser.domain, 'flamecomics.xyz');
      expect(parser.headers['Referer'], 'https://flamecomics.xyz/');
    });

    test('Successfully import valid REST API spec', () {
      final jsonStr = '''{
        "id": "custom_api_source",
        "name": "Custom Manga API",
        "domain": "api.manga.io",
        "locale": "id",
        "type": "rest",
        "api": {
          "listEndpoint": "https://{domain}/v1/mangas?page={page}",
          "searchEndpoint": "https://{domain}/v1/search?query={query}",
          "listPath": "data.items",
          "idKey": "slug",
          "titleKey": "title",
          "coverKey": "cover_image",
          "chaptersEndpoint": "https://{domain}/v1/manga/{manga_id}/chapters",
          "chaptersPath": "data.chapters",
          "chapterIdKey": "id",
          "chapterTitleKey": "title",
          "chapterNumberKey": "chapter_number",
          "pagesEndpoint": "https://{domain}/v1/chapter/{chapter_id}/pages",
          "pagesPath": "data.images",
          "pageUrlKey": "url"
        }
      }''';

      final config = ParserImporter.fromJsonString(jsonStr);
      expect(config.id, 'custom_api_source');
      expect(config.name, 'Custom Manga API');
      expect(config.domain, 'api.manga.io');
      expect(config.type, 'rest');
      expect(config.api?['listEndpoint'], 'https://{domain}/v1/mangas?page={page}');
      expect(config.api?['listPath'], 'data.items');
    });

    test('Validate reject when missing required fields', () {
      // Missing domain
      expect(
        () => ParserImporter.fromJsonString('{"name": "No Domain"}'),
        throwsA(isA<FormatException>()),
      );

      // Missing name
      expect(
        () => ParserImporter.fromJsonString('{"domain": "example.com"}'),
        throwsA(isA<FormatException>()),
      );

      // Invalid type
      expect(
        () => ParserImporter.fromJsonString('{"name": "Test", "domain": "example.com", "type": "unknown_type"}'),
        throwsA(isA<FormatException>()),
      );

      // Empty JSON
      expect(
        () => ParserImporter.fromJsonString(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('Export and re-import roundtrip preserves all rules', () {
      final original = ParserImporter.fromJsonString(ParserImporter.sampleHtmlTemplate);
      final exportedJson = ParserImporter.exportToJson(original);
      final reimported = ParserImporter.fromJsonString(exportedJson);

      expect(reimported.name, original.name);
      expect(reimported.domain, original.domain);
      expect(reimported.type, original.type);
      expect(reimported.selectors?['card'], original.selectors?['card']);
      expect(reimported.selectors?['coverAttr'], original.selectors?['coverAttr']);
      expect(reimported.urls?['list'], original.urls?['list']);
    });

    test('SQLite map serialization and deserialization compatibility', () {
      final config = ParserImporter.fromJsonString(ParserImporter.sampleRestTemplate);
      final dbMap = config.toMap();

      expect(dbMap['id'], config.id);
      expect(dbMap['name'], config.name);
      expect(dbMap['domain'], config.domain);
      expect(dbMap['type'], 'rest');
      expect(dbMap['config'], isNotNull);

      // Restore from SQLite map
      final restored = CustomSourceConfig.fromMap(dbMap);
      expect(restored.id, config.id);
      expect(restored.name, config.name);
      expect(restored.domain, config.domain);
      expect(restored.type, 'rest');
      expect(restored.api?['listPath'], 'data.items');
    });
  });
}
