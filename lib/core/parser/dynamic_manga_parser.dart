import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import '../database/models/manga.dart';
import '../database/models/chapter.dart';
import '../database/models/manga_page.dart';
import '../network/http_client.dart';
import 'manga_parser.dart';

class CustomSourceConfig {
  final String id;
  final String name;
  final String domain;
  final String locale;
  final String type; // 'madara', 'themesia', 'html', 'rest', 'json_api'
  final Map<String, dynamic>? customSelectors;

  const CustomSourceConfig({
    required this.id,
    required this.name,
    required this.domain,
    this.locale = 'id',
    this.type = 'madara',
    this.customSelectors,
  });

  Map<String, String>? get customHeaders {
    final raw = customSelectors?['headers'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return null;
  }

  Map<String, dynamic>? get urls {
    final raw = customSelectors?['urls'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  Map<String, dynamic>? get selectors {
    final raw = customSelectors?['selectors'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  Map<String, dynamic>? get api {
    final raw = customSelectors?['api'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'domain': domain,
      'locale': locale,
      'type': type,
      'config': customSelectors != null ? jsonEncode(customSelectors) : null,
    };
  }

  factory CustomSourceConfig.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? selectors;
    final rawConfig = map['config'];
    if (rawConfig != null) {
      if (rawConfig is String && rawConfig.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawConfig);
          if (decoded is Map<String, dynamic>) {
            selectors = decoded;
          }
        } catch (_) {}
      } else if (rawConfig is Map<String, dynamic>) {
        selectors = rawConfig;
      }
    }

    if (selectors == null && map.containsKey('selectors') && map['selectors'] is Map<String, dynamic>) {
      selectors = map;
    }

    final id = map['id']?.toString() ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final name = map['name']?.toString() ?? 'Custom Source';
    final domain = (map['domain']?.toString() ?? '')
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('/', '')
        .trim();
    final locale = map['locale']?.toString() ?? 'id';
    final type = map['type']?.toString() ?? 'madara';

    return CustomSourceConfig(
      id: id,
      name: name,
      domain: domain,
      locale: locale,
      type: type,
      customSelectors: selectors,
    );
  }
}

class DynamicMangaParser extends MangaParser {
  final CustomSourceConfig sourceConfig;

  DynamicMangaParser(this.sourceConfig);

  @override
  String get id => sourceConfig.id;

  @override
  String get name => sourceConfig.name;

  @override
  String get domain => sourceConfig.domain;

  @override
  String get locale => sourceConfig.locale;

  @override
  Map<String, String> get headers {
    final defaultHeaders = {
      'Referer': 'https://$domain/',
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
    };
    if (sourceConfig.customHeaders != null) {
      defaultHeaders.addAll(sourceConfig.customHeaders!);
    }
    return defaultHeaders;
  }

  String _formatUrl(String template, {int page = 1, String? query, String? mangaId, String? chapterId}) {
    return template
        .replaceAll('{domain}', domain)
        .replaceAll('{page}', page.toString())
        .replaceAll('{query}', query != null ? Uri.encodeComponent(query.trim()) : '')
        .replaceAll('{manga_id}', mangaId ?? '')
        .replaceAll('{chapter_id}', chapterId ?? '');
  }

  dynamic _traverseJson(dynamic current, String path) {
    if (path.isEmpty || current == null) return current;
    final keys = path.split('.');
    dynamic value = current;
    for (final key in keys) {
      if (value is Map && value.containsKey(key)) {
        value = value[key];
      } else if (value is List && int.tryParse(key) != null) {
        final idx = int.parse(key);
        if (idx >= 0 && idx < value.length) {
          value = value[idx];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    return value;
  }

  @override
  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
    List<String>? genres,
    String? category,
  }) async {
    final type = sourceConfig.type.toLowerCase();

    // 1. REST API Parser
    if (type == 'rest' || type == 'json_api') {
      return _getListRest(page: page, query: query);
    }

    // 2. Custom HTML Selector Parser
    if (type == 'html' || sourceConfig.selectors != null) {
      return _getListHtml(page: page, query: query);
    }

    // 3. Fallback: Legacy Themesia / Madara
    return _getListLegacy(page: page, query: query);
  }

  Future<List<Manga>> _getListRest({required int page, String? query}) async {
    try {
      final api = sourceConfig.api ?? {};
      final isSearch = query != null && query.trim().isNotEmpty;
      final endpointTemplate = isSearch
          ? (api['searchEndpoint'] as String? ?? api['listEndpoint'] as String?)
          : (api['listEndpoint'] as String?);

      if (endpointTemplate == null) return [];

      final url = _formatUrl(endpointTemplate, page: page, query: query);
      final res = await KurokuHttpClient.instance.get<dynamic>(
        url,
        headers: headers,
        responseType: ResponseType.json,
      );

      dynamic rawData = res.data;
      if (rawData is String) {
        rawData = jsonDecode(rawData);
      }

      final listPath = api['listPath'] as String? ?? 'data';
      final rawList = _traverseJson(rawData, listPath);
      if (rawList is! List) return [];

      final idKey = api['idKey'] as String? ?? 'id';
      final titleKey = api['titleKey'] as String? ?? 'title';
      final coverKey = api['coverKey'] as String? ?? 'cover';
      final urlKey = api['urlKey'] as String?;

      final list = <Manga>[];
      for (final item in rawList) {
        if (item is! Map) continue;
        final rawItemId = item[idKey]?.toString() ?? '';
        final title = item[titleKey]?.toString().trim() ?? '';
        if (rawItemId.isEmpty || title.isEmpty) continue;

        final rawCover = item[coverKey]?.toString().trim() ?? '';
        final coverUrl = rawCover.startsWith('http')
            ? rawCover
            : (rawCover.isNotEmpty ? 'https://$domain/$rawCover' : '');

        final mangaUrl = urlKey != null && item[urlKey] != null
            ? item[urlKey].toString()
            : 'https://$domain/manga/$rawItemId';

        list.add(Manga(
          id: '${id}_$rawItemId',
          title: title,
          url: mangaUrl,
          coverUrl: coverUrl,
          sourceId: id,
          status: MangaStatus.ongoing,
        ));
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<Manga>> _getListHtml({required int page, String? query}) async {
    try {
      final urls = sourceConfig.urls;
      final selectors = sourceConfig.selectors ?? {};
      final isSearch = query != null && query.trim().isNotEmpty;

      String url;
      if (isSearch && urls != null && urls['search'] != null) {
        url = _formatUrl(urls['search'] as String, page: page, query: query);
      } else if (urls != null && urls['list'] != null) {
        url = _formatUrl(urls['list'] as String, page: page, query: query);
      } else {
        url = isSearch
            ? 'https://$domain/?s=${Uri.encodeComponent(query.trim())}'
            : 'https://$domain/manga?page=$page';
      }

      final res = await KurokuHttpClient.instance.get<String>(
        url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);

      final cardSelector = selectors['card'] as String? ??
          selectors['card_item'] as String? ??
          selectors['cardItem'] as String? ??
          'div.page-item-detail, div.manga, div.bsx, div.grid > div';
      final elements = doc.querySelectorAll(cardSelector);

      final titleSelector = selectors['title'] as String? ??
          selectors['card_title'] as String? ??
          selectors['cardTitle'] as String? ??
          '.post-title, h3, h4, h5, .tt, div.line-clamp-2, div.font-black';
      final coverSelector = selectors['cover'] as String? ??
          selectors['card_cover'] as String? ??
          selectors['cardCover'] as String? ??
          'img';
      final coverAttrs = (selectors['coverAttr'] as String? ??
              selectors['cover_attr'] as String? ??
              selectors['card_cover_attr'] as String? ??
              selectors['cardCoverAttr'] as String?)
          ?.split(',') ?? ['data-src', 'data-lazy-src', 'src', 'data-original'];

      final list = <Manga>[];
      for (final el in elements) {
        final a = el.localName == 'a' ? el : el.querySelector('a');
        if (a == null) continue;

        final href = a.attributes['href'];
        if (href == null || href.isEmpty) continue;

        final titleEl = el.querySelector(titleSelector) ?? el.parent?.querySelector(titleSelector);
        var title = titleEl?.text.trim() ?? a.attributes['title']?.trim() ?? '';
        if (title.isEmpty) {
          final img = el.querySelector('img') ?? el.parent?.querySelector('img');
          title = img?.attributes['alt']?.trim() ?? '';
        }
        if (title.isEmpty) continue;

        final img = el.querySelector(coverSelector) ?? el.parent?.querySelector(coverSelector);
        String coverUrl = '';
        if (img != null) {
          for (final attr in coverAttrs) {
            final val = img.attributes[attr.trim()];
            if (val != null && val.trim().isNotEmpty && !val.trim().startsWith('data:')) {
              coverUrl = val.trim();
              break;
            }
          }
        }

        final cleanSlug = href.split('/').where((s) => s.isNotEmpty).last;

        list.add(Manga(
          id: '${id}_$cleanSlug',
          title: title,
          url: href.startsWith('http') ? href : 'https://$domain$href',
          coverUrl: coverUrl.startsWith('http') ? coverUrl : (coverUrl.isNotEmpty ? 'https://$domain$coverUrl' : ''),
          sourceId: id,
          status: MangaStatus.ongoing,
        ));
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<Manga>> _getListLegacy({required int page, String? query}) async {
    String url;
    if (sourceConfig.type == 'themesia') {
      url = query != null && query.trim().isNotEmpty
          ? 'https://$domain/?s=${Uri.encodeComponent(query.trim())}'
          : 'https://$domain/manga/?page=$page&order=update';
    } else {
      url = query != null && query.trim().isNotEmpty
          ? 'https://$domain/?s=${Uri.encodeComponent(query.trim())}&post_type=wp-manga'
          : 'https://$domain/manga/page/$page/?m_orderby=latest';
    }

    try {
      final res = await KurokuHttpClient.instance.get<String>(
        url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);

      final elements = sourceConfig.type == 'themesia'
          ? doc.querySelectorAll('div.bsx')
          : doc.querySelectorAll('div.page-item-detail, div.manga, div.badge-pos-1');

      final list = <Manga>[];
      for (final el in elements) {
        final a = el.querySelector('a');
        if (a == null) continue;

        final href = a.attributes['href'];
        if (href == null || href.isEmpty) continue;

        final titleEl = el.querySelector('.post-title, h3, h4, h5, .tt');
        final title = titleEl?.text.trim() ?? a.attributes['title']?.trim() ?? '';
        if (title.isEmpty) continue;

        final img = el.querySelector('img');
        final coverUrl = img?.attributes['data-src'] ??
            img?.attributes['data-lazy-src'] ??
            img?.attributes['src'] ??
            '';

        final cleanSlug = href.split('/').where((s) => s.isNotEmpty).last;

        list.add(Manga(
          id: '${id}_$cleanSlug',
          title: title,
          url: href.startsWith('http') ? href : 'https://$domain$href',
          coverUrl: coverUrl,
          sourceId: id,
          status: MangaStatus.ongoing,
        ));
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Manga> getDetails(Manga manga) async {
    try {
      final res = await KurokuHttpClient.instance.get<String>(
        manga.url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return manga;
      final doc = html_parser.parse(res.data);

      final selectors = sourceConfig.selectors;
      final descSelector = selectors?['description'] as String? ??
          selectors?['detail_description'] as String? ??
          selectors?['detailDescription'] as String? ??
          '.description-summary, .entry-content, .sinopsis, .entry-content-single, div.desc, p.text-sm';
      final descEl = doc.querySelector(descSelector);
      final desc = descEl?.text.trim();

      final genreSelector = selectors?['genre'] as String? ??
          selectors?['genres'] as String? ??
          selectors?['detail_genres'] as String? ??
          selectors?['detailGenres'] as String? ??
          'a[href*="/genres/"], a[href*="/genre/"], a[href*="/search?genre="]';
      final genres = <String>[];
      final genreLinks = doc.querySelectorAll(genreSelector);
      for (final g in genreLinks) {
        final text = g.text.trim();
        if (text.isNotEmpty && !genres.contains(text)) {
          genres.add(text);
        }
      }

      return manga.copyWith(
        description: desc ?? manga.description,
        genres: genres.isNotEmpty ? genres : manga.genres,
      );
    } catch (_) {
      return manga;
    }
  }

  @override
  Future<List<MangaChapter>> getChapters(Manga manga) async {
    final type = sourceConfig.type.toLowerCase();

    // 1. REST API Chapters
    if (type == 'rest' || type == 'json_api') {
      final api = sourceConfig.api;
      if (api != null && api['chaptersEndpoint'] != null) {
        try {
          final cleanMangaId = manga.id.replaceFirst('${id}_', '');
          final url = _formatUrl(api['chaptersEndpoint'] as String, mangaId: cleanMangaId);
          final res = await KurokuHttpClient.instance.get<dynamic>(
            url,
            headers: headers,
            responseType: ResponseType.json,
          );

          dynamic rawData = res.data;
          if (rawData is String) rawData = jsonDecode(rawData);

          final chaptersPath = api['chaptersPath'] as String? ?? 'data';
          final rawList = _traverseJson(rawData, chaptersPath);
          if (rawList is List) {
            final chIdKey = api['chapterIdKey'] as String? ?? 'id';
            final chTitleKey = api['chapterTitleKey'] as String? ?? 'title';
            final chNumberKey = api['chapterNumberKey'] as String? ?? 'chapter_number';
            final chUrlKey = api['chapterUrlKey'] as String?;

            final chapters = <MangaChapter>[];
            for (final ch in rawList) {
              if (ch is! Map) continue;
              final chId = ch[chIdKey]?.toString() ?? '';
              if (chId.isEmpty) continue;

              final title = ch[chTitleKey]?.toString().trim() ?? 'Chapter $chId';
              final chNum = double.tryParse(ch[chNumberKey]?.toString() ?? '') ?? 0.0;
              final chUrl = chUrlKey != null && ch[chUrlKey] != null
                  ? ch[chUrlKey].toString()
                  : 'https://$domain/chapter/$chId';

              chapters.add(MangaChapter(
                id: '${id}_${manga.id}_$chId',
                mangaId: manga.id,
                title: title,
                number: chNum,
                url: chUrl,
              ));
            }
            chapters.sort((a, b) => b.number.compareTo(a.number));
            return chapters;
          }
        } catch (_) {}
      }
    }

    // 2. Custom HTML Selector / Legacy Chapters
    try {
      final res = await KurokuHttpClient.instance.get<String>(
        manga.url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);

      final selectors = sourceConfig.selectors;
      final chSelector = selectors?['chapters'] as String? ??
          selectors?['chapter_item'] as String? ??
          selectors?['chapterItem'] as String? ??
          'li.wp-manga-chapter a, ul.sub-chap-list a, .eph-num a, div.bxcl ul li a, div#chapters a';
      final links = doc.querySelectorAll(chSelector);
      final chapters = <MangaChapter>[];

      final regexPattern = selectors?['chapterNumberRegex'] as String? ??
          selectors?['chapter_number_regex'] as String? ??
          selectors?['chapterRegex'] as String? ??
          r'([0-9.]+)';
      final numberRegex = RegExp(regexPattern);

      for (int i = 0; i < links.length; i++) {
        final el = links[i];
        final href = el.attributes['href'];
        if (href == null || href.isEmpty) continue;

        final title = el.text.trim();
        final match = numberRegex.firstMatch(title);
        final rawNum = match != null ? (match.groupCount >= 1 ? match.group(1) : match.group(0)) : null;
        final chNum = double.tryParse(rawNum ?? '') ?? (links.length - i).toDouble();
        final chSlug = href.split('/').where((s) => s.isNotEmpty).last;

        chapters.add(MangaChapter(
          id: '${id}_${manga.id}_$chSlug',
          mangaId: manga.id,
          title: title.isNotEmpty ? title : 'Chapter $chNum',
          number: chNum,
          url: href.startsWith('http') ? href : 'https://$domain$href',
        ));
      }

      chapters.sort((a, b) => b.number.compareTo(a.number));
      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<MangaPage>> getPages(MangaChapter chapter) async {
    final type = sourceConfig.type.toLowerCase();

    // 1. REST API Pages
    if (type == 'rest' || type == 'json_api') {
      final api = sourceConfig.api;
      if (api != null && api['pagesEndpoint'] != null) {
        try {
          final cleanChapterId = chapter.id.split('_').last;
          final url = _formatUrl(api['pagesEndpoint'] as String, chapterId: cleanChapterId);
          final res = await KurokuHttpClient.instance.get<dynamic>(
            url,
            headers: headers,
            responseType: ResponseType.json,
          );

          dynamic rawData = res.data;
          if (rawData is String) rawData = jsonDecode(rawData);

          final pagesPath = api['pagesPath'] as String? ?? 'data';
          final rawList = _traverseJson(rawData, pagesPath);
          if (rawList is List) {
            final pageUrlKey = api['pageUrlKey'] as String? ?? 'url';
            final pages = <MangaPage>[];
            for (int i = 0; i < rawList.length; i++) {
              final p = rawList[i];
              final rawUrl = p is Map ? p[pageUrlKey]?.toString() : p?.toString();
              if (rawUrl == null || rawUrl.trim().isEmpty) continue;

              final imgUrl = rawUrl.trim().startsWith('http')
                  ? rawUrl.trim()
                  : 'https://$domain${rawUrl.trim()}';

              pages.add(MangaPage(
                index: i,
                url: imgUrl,
                headers: headers,
              ));
            }
            return pages;
          }
        } catch (_) {}
      }
    }

    // 2. Custom HTML Selector / Legacy Pages
    try {
      final res = await KurokuHttpClient.instance.get<String>(
        chapter.url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);

      final selectors = sourceConfig.selectors;
      final pageSelector = selectors?['pages'] as String? ??
          selectors?['page_images'] as String? ??
          selectors?['pageImages'] as String? ??
          'div.page-break img, div.reading-content img, #readerarea img, .reader-area img, img.js-page';
      final pageAttrs = (selectors?['pageAttr'] as String? ??
              selectors?['page_attr'] as String? ??
              selectors?['page_image_attr'] as String? ??
              selectors?['pageImageAttr'] as String?)
          ?.split(',') ??
          ['data-src', 'data-lazy-src', 'src', 'data-original'];

      final imgEls = doc.querySelectorAll(pageSelector);
      final pages = <MangaPage>[];

      for (int i = 0; i < imgEls.length; i++) {
        final el = imgEls[i];
        String? src;
        for (final attr in pageAttrs) {
          final val = el.attributes[attr.trim()];
          if (val != null && val.trim().isNotEmpty) {
            src = val.trim();
            break;
          }
        }

        if (src == null || src.isEmpty) continue;

        pages.add(MangaPage(
          index: i,
          url: src.startsWith('http') ? src : 'https://$domain$src',
          headers: headers,
        ));
      }

      return pages;
    } catch (_) {
      return [];
    }
  }
}
