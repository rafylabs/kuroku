import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import '../../database/models/manga.dart';
import '../../database/models/chapter.dart';
import '../../database/models/manga_page.dart';
import '../../network/http_client.dart';
import '../manga_parser.dart';

class WeebCentralParser extends MangaParser {
  String? _customDomain;

  void setCustomDomain(String newDomain) {
    _customDomain = newDomain.replaceAll('https://', '').replaceAll('http://', '').replaceAll('/', '').trim();
  }

  @override
  String get id => 'weebcentral';

  @override
  String get name => 'Weeb Central (EN)';

  @override
  String get domain => _customDomain ?? 'weebcentral.com';

  @override
  String get locale => 'en';

  @override
  Map<String, String> get headers => {
    'Referer': 'https://$domain/',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
  };

  @override
  List<String> get availableCategories => const ['All', 'Manga', 'Manhwa', 'Manhua', 'OEL'];

  @override
  List<String> get availableGenres => const [
    'All',
    'Action',
    'Adult',
    'Adventure',
    'Comedy',
    'Doujinshi',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Gender Bender',
    'Harem',
    'Hentai',
    'Historical',
    'Horror',
    'Isekai',
    'Josei',
    'Lolicon',
    'Martial Arts',
    'Mature',
    'Mecha',
    'Mystery',
    'Psychological',
    'Romance',
    'School Life',
    'Sci-fi',
    'Seinen',
    'Shotacon',
    'Shoujo',
    'Shoujo Ai',
    'Shounen',
    'Shounen Ai',
    'Slice of Life',
    'Smut',
    'Sports',
    'Supernatural',
    'Tragedy',
    'Yaoi',
    'Yuri',
    'Other',
  ];

  @override
  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
    List<String>? genres,
    String? category,
  }) async {
    final offset = (page - 1) * 32;
    String url = 'https://$domain/search/data?limit=32&offset=$offset&official=Any&anime=Any&adult=Any&display_mode=Full+Display';

    if (query != null && query.trim().isNotEmpty) {
      final cleanQuery = query.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').trim();
      url += '&text=${Uri.encodeComponent(cleanQuery)}';
    }

    if (category != null && category.trim().isNotEmpty && category.trim().toLowerCase() != 'all') {
      url += '&included_type=${Uri.encodeComponent(category.trim())}';
    }

    String normalizeTag(String tag) {
      final t = tag.trim();
      for (final g in availableGenres) {
        if (g.toLowerCase() == t.toLowerCase()) return g;
      }
      return t;
    }

    final activeTags = <String>{};
    if (genres != null && genres.isNotEmpty) {
      for (final g in genres) {
        if (g.trim().isNotEmpty && g.trim().toLowerCase() != 'all') {
          activeTags.add(normalizeTag(g));
        }
      }
    } else if (genre != null && genre.trim().isNotEmpty && genre.trim().toLowerCase() != 'all') {
      activeTags.add(normalizeTag(genre));
    }

    for (final tag in activeTags) {
      url += '&included_tag=${Uri.encodeComponent(tag)}';
    }

    url += order == SortOrder.popular
        ? '&sort=Popularity&order=Descending'
        : '&sort=Latest+Updates&order=Descending';

    try {
      final res = await KurokuHttpClient.instance.get<String>(
        url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);
      final articles = doc.querySelectorAll('article.bg-base-300');

      final list = <Manga>[];
      for (final el in articles) {
        final a = el.querySelector('a[href*="/series/"]');
        if (a == null) continue;

        final href = a.attributes['href'];
        if (href == null) continue;

        final pathSegments = Uri.parse(href).pathSegments;
        if (pathSegments.length < 2) continue;
        final mangaId = pathSegments[1];

        final titleEl = el.querySelector('.truncate') ??
            el.querySelector('.text-ellipsis') ??
            el.querySelector('div.text-lg');
        final title = titleEl?.text.trim() ?? 'Unknown';

        final img = el.querySelector('picture img') ?? el.querySelector('img');
        String coverUrl = img?.attributes['src']?.trim() ?? '';
        if (coverUrl.isEmpty) {
          final source = el.querySelector('picture source');
          coverUrl = source?.attributes['srcset']?.trim() ?? '';
        }

        list.add(Manga(
          id: '${id}_$mangaId',
          title: title,
          url: mangaId,
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
    final mangaId = manga.url;
    try {
      final res = await KurokuHttpClient.instance.get<String>(
        'https://$domain/series/$mangaId',
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return manga;
      final doc = html_parser.parse(res.data);

      final title = doc.querySelector('h1')?.text.trim() ?? manga.title;
      final descEl = doc.querySelector('p.whitespace-pre-wrap') ?? doc.querySelector('p');
      final desc = descEl?.text.trim();

      final genres = <String>[];
      final tagEls = doc.querySelectorAll('a[href*="included_tag="]');
      for (final t in tagEls) {
        final text = t.text.trim();
        if (text.isNotEmpty && !genres.contains(text)) {
          genres.add(text);
        }
      }

      final authorEls = doc.querySelectorAll('a[href*="author="]');
      final authors = authorEls.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();

      final statusEl = doc.querySelector('a[href*="included_status="]');
      final statusText = statusEl?.text.trim().toLowerCase();
      MangaStatus status = manga.status;
      if (statusText != null) {
        if (statusText.contains('ongoing')) {
          status = MangaStatus.ongoing;
        } else if (statusText.contains('complete')) {
          status = MangaStatus.completed;
        }
      }

      return manga.copyWith(
        title: title,
        description: desc ?? manga.description,
        genres: genres.isNotEmpty ? genres : manga.genres,
        author: authors.isNotEmpty ? authors.join(', ') : manga.author,
        status: status,
      );
    } catch (_) {
      return manga;
    }
  }

  @override
  Future<List<MangaChapter>> getChapters(Manga manga) async {
    final mangaId = manga.url;
    try {
      // 1. Fetch full chapter list
      final res = await KurokuHttpClient.instance.get<String>(
        'https://$domain/series/$mangaId/full-chapter-list',
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);
      final links = doc.querySelectorAll('a[href*="/chapters/"]');

      final chapters = <MangaChapter>[];
      for (int i = 0; i < links.length; i++) {
        final el = links[i];
        final href = el.attributes['href'];
        if (href == null) continue;

        final pathSegments = Uri.parse(href.startsWith('http') ? href : 'https://$domain$href').pathSegments;
        if (pathSegments.length < 2) continue;
        final chapterId = pathSegments[1];

        final name = el.querySelector('span.grow span')?.text.trim() ??
            el.querySelector('span')?.text.trim() ??
            'Chapter $i';

        final match = RegExp(r'([0-9.]+)').firstMatch(name);
        final chNum = double.tryParse(match?.group(1) ?? '0') ?? (links.length - i).toDouble();

        final dateStr = el.querySelector('time')?.attributes['datetime'];
        final uploadDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

        chapters.add(MangaChapter(
          id: '${id}_${manga.id}_$chapterId',
          mangaId: manga.id,
          title: name,
          number: chNum,
          url: chapterId,
          uploadDate: uploadDate,
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
    final chapterId = chapter.url;
    final url = 'https://$domain/chapters/$chapterId/images?is_prev=False&reading_style=long_strip';

    try {
      final res = await KurokuHttpClient.instance.get<String>(
        url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);
      final imgEls = doc.querySelectorAll('section[x-data] img, img.max-w-full');

      final pages = <MangaPage>[];
      for (int i = 0; i < imgEls.length; i++) {
        final src = imgEls[i].attributes['src'];
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
