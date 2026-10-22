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
  final String type; // 'madara', 'themesia', 'json'
  final Map<String, dynamic>? customSelectors;

  const CustomSourceConfig({
    required this.id,
    required this.name,
    required this.domain,
    this.locale = 'id',
    this.type = 'madara',
    this.customSelectors,
  });

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
    if (map['config'] != null && (map['config'] as String).isNotEmpty) {
      try {
        selectors = jsonDecode(map['config'] as String) as Map<String, dynamic>?;
      } catch (_) {}
    }

    return CustomSourceConfig(
      id: map['id'] as String,
      name: map['name'] as String,
      domain: (map['domain'] as String).replaceAll('https://', '').replaceAll('http://', '').replaceAll('/', ''),
      locale: map['locale'] as String? ?? 'id',
      type: map['type'] as String? ?? 'madara',
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
  Map<String, String> get headers => {
    'Referer': 'https://$domain/',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
  };

  @override
  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
  }) async {
    String url;
    if (sourceConfig.type == 'themesia') {
      url = query != null && query.trim().isNotEmpty
          ? 'https://$domain/?s=${Uri.encodeComponent(query.trim())}'
          : 'https://$domain/manga/?page=$page&order=update';
    } else {
      // Default: Madara (WordPress)
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

      final descEl = doc.querySelector('.description-summary, .entry-content, .sinopsis, .entry-content-single');
      final desc = descEl?.text.trim();

      final genres = <String>[];
      final genreLinks = doc.querySelectorAll('a[href*="/genres/"], a[href*="/genre/"]');
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
    try {
      final res = await KurokuHttpClient.instance.get<String>(
        manga.url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);

      final links = doc.querySelectorAll('li.wp-manga-chapter a, ul.sub-chap-list a, .eph-num a, div.bxcl ul li a');
      final chapters = <MangaChapter>[];

      for (int i = 0; i < links.length; i++) {
        final el = links[i];
        final href = el.attributes['href'];
        if (href == null || href.isEmpty) continue;

        final title = el.text.trim();
        final match = RegExp(r'([0-9.]+)').firstMatch(title);
        final chNum = double.tryParse(match?.group(1) ?? '0') ?? (links.length - i).toDouble();
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
    try {
      final res = await KurokuHttpClient.instance.get<String>(
        chapter.url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);

      final imgEls = doc.querySelectorAll('div.page-break img, div.reading-content img, #readerarea img, .reader-area img');
      final pages = <MangaPage>[];

      for (int i = 0; i < imgEls.length; i++) {
        final el = imgEls[i];
        final src = el.attributes['data-src'] ??
            el.attributes['data-lazy-src'] ??
            el.attributes['src'];

        if (src == null || src.isEmpty) continue;

        pages.add(MangaPage(
          index: i,
          url: src.trim().startsWith('http') ? src.trim() : 'https://$domain${src.trim()}',
          headers: headers,
        ));
      }

      return pages;
    } catch (_) {
      return [];
    }
  }
}
