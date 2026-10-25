import 'dart:convert';
import 'package:dio/dio.dart';
import '../network/http_client.dart';
import 'dynamic_manga_parser.dart';

class ParserImporter {
  static const int currentSpecVersion = 1;

  /// Parse and validate JSON string into a CustomSourceConfig.
  static CustomSourceConfig fromJsonString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Parser spec string is empty');
    }

    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Parser spec root must be a JSON object');
    }

    return fromJson(decoded);
  }

  /// Parse and validate JSON map into a CustomSourceConfig.
  static CustomSourceConfig fromJson(Map<String, dynamic> map) {
    final validationError = validate(map);
    if (validationError != null) {
      throw FormatException(validationError);
    }

    final rawId = (map['id'] as String? ?? '').trim();
    final cleanId = rawId.isNotEmpty
        ? rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase()
        : 'custom_${DateTime.now().millisecondsSinceEpoch}';

    final finalId = cleanId.startsWith('custom_') ? cleanId : 'custom_$cleanId';
    final name = (map['name'] as String).trim();
    final domain = (map['domain'] as String)
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('/', '')
        .trim();
    final locale = (map['locale'] as String? ?? 'id').trim().toLowerCase();
    final type = (map['type'] as String? ?? 'html').trim().toLowerCase();

    return CustomSourceConfig(
      id: finalId,
      name: name,
      domain: domain,
      locale: locale,
      type: type,
      customSelectors: map,
    );
  }

  /// Validate required parser fields. Returns null if valid, error message if invalid.
  static String? validate(Map<String, dynamic> map) {
    if (!map.containsKey('name') || (map['name'] as String? ?? '').trim().isEmpty) {
      return 'Missing required field: "name"';
    }

    if (!map.containsKey('domain') || (map['domain'] as String? ?? '').trim().isEmpty) {
      return 'Missing required field: "domain"';
    }

    final type = (map['type'] as String? ?? 'html').toLowerCase();
    const validTypes = ['html', 'rest', 'json_api', 'madara', 'themesia'];
    if (!validTypes.contains(type)) {
      return 'Invalid type "$type". Allowed: ${validTypes.join(', ')}';
    }

    if (type == 'html') {
      final selectors = map['selectors'];
      if (selectors != null && selectors is! Map) {
        return '"selectors" must be an object of CSS selectors';
      }
    } else if (type == 'rest' || type == 'json_api') {
      final api = map['api'];
      if (api != null && api is! Map) {
        return '"api" must be an object of API endpoints and keys';
      }
    }

    return null;
  }

  /// Export CustomSourceConfig back to pretty formatted JSON.
  static String exportToJson(CustomSourceConfig config) {
    final baseMap = config.customSelectors != null
        ? Map<String, dynamic>.from(config.customSelectors!)
        : <String, dynamic>{};

    baseMap['kuroku_spec_version'] = currentSpecVersion;
    baseMap['id'] = config.id.replaceFirst('custom_', '');
    baseMap['name'] = config.name;
    baseMap['domain'] = config.domain;
    baseMap['locale'] = config.locale;
    baseMap['type'] = config.type;

    return const JsonEncoder.withIndent('  ').convert(baseMap);
  }

  /// Fetch parser spec JSON from a remote URL.
  static Future<CustomSourceConfig> fetchFromUrl(String url) async {
    final cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      throw const FormatException('URL must start with http:// or https://');
    }

    final res = await KurokuHttpClient.instance.get<String>(
      cleanUrl,
      responseType: ResponseType.plain,
    );

    if (res.data == null || res.data!.trim().isEmpty) {
      throw Exception('Empty response from URL: $cleanUrl');
    }

    return fromJsonString(res.data!);
  }

  /// Sample HTML selector template for user guidance.
  static String get sampleHtmlTemplate {
    return '''{
  "kuroku_spec_version": 1,
  "id": "contoh_komik",
  "name": "Contoh Komik",
  "domain": "contohkomik.com",
  "locale": "id",
  "type": "html",
  "headers": {
    "Referer": "https://contohkomik.com/"
  },
  "urls": {
    "list": "https://{domain}/manga?page={page}",
    "search": "https://{domain}/search?q={query}"
  },
  "selectors": {
    "card": "div.comic-card",
    "title": "h3.title",
    "cover": "img.cover",
    "coverAttr": "data-src,src",
    "chapters": "ul.chapters-list a",
    "chapterNumberRegex": "([0-9.]+)",
    "pages": "div.reading-content img",
    "pageAttr": "data-src,src"
  }
}''';
  }

  /// Sample REST API template for user guidance.
  static String get sampleRestTemplate {
    return '''{
  "kuroku_spec_version": 1,
  "id": "contoh_api",
  "name": "Contoh REST API",
  "domain": "api.contoh.com",
  "locale": "en",
  "type": "rest",
  "headers": {
    "Referer": "https://api.contoh.com/"
  },
  "api": {
    "listEndpoint": "https://{domain}/v1/mangas?page={page}",
    "searchEndpoint": "https://{domain}/v1/search?q={query}",
    "listPath": "data.items",
    "idKey": "id",
    "titleKey": "title",
    "coverKey": "thumbnail",
    "chaptersEndpoint": "https://{domain}/v1/manga/{manga_id}/chapters",
    "chaptersPath": "data.chapters",
    "chapterIdKey": "id",
    "chapterTitleKey": "title",
    "chapterNumberKey": "chapter_number",
    "pagesEndpoint": "https://{domain}/v1/chapter/{chapter_id}/pages",
    "pagesPath": "data.pages",
    "pageUrlKey": "url"
  }
}''';
  }
}
