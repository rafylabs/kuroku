import '../../database/models/manga.dart';
import '../../database/models/chapter.dart';
import '../../database/models/manga_page.dart';
import '../../network/http_client.dart';
import '../manga_parser.dart';

class ShinigamiParser extends MangaParser {
  String? _customDomain;

  void setCustomDomain(String newDomain) {
    _customDomain = newDomain.replaceAll('https://', '').replaceAll('http://', '').replaceAll('/', '').trim();
  }

  @override
  String get id => 'shinigami';

  @override
  String get name => 'Shinigami (ID)';

  @override
  String get domain => _customDomain ?? 'id.shinigami.asia';

  @override
  String get locale => 'id';

  final String _apiBase = 'https://api.shngm.io/v1';
  final String _cdnBase = 'https://storage.shngm.id';

  @override
  Map<String, String> get headers => {
    'Referer': 'https://$domain/',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
    'sec-fetch-dest': 'empty',
  };

  @override
  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
  }) async {
    final sort = order == SortOrder.popular ? 'popularity' : 'latest';
    String url = '$_apiBase/manga/list?page=$page&page_size=24&sort=$sort&sort_order=desc';

    if (query != null && query.trim().isNotEmpty) {
      final q = Uri.encodeComponent(query.trim());
      url += '&q=$q';
    }

    try {
      final res = await KurokuHttpClient.instance.get<Map<String, dynamic>>(
        url,
        headers: headers,
      );

      final dataList = res.data?['data'] as List<dynamic>? ?? [];
      final list = <Manga>[];

      for (final item in dataList) {
        if (item is! Map<String, dynamic>) continue;

        final mId = item['manga_id'] as String? ?? '';
        final title = item['title'] as String? ?? '';
        if (mId.isEmpty || title.isEmpty) continue;

        final coverUrl = item['cover_portrait_url'] as String? ??
            item['cover_image_url'] as String? ??
            '';

        final statusVal = item['status'] as int? ?? 0;
        final status = statusVal == 2
            ? MangaStatus.completed
            : statusVal == 1
                ? MangaStatus.ongoing
                : MangaStatus.unknown;

        list.add(Manga(
          id: '${id}_$mId',
          title: title,
          altTitle: item['alternative_title'] as String?,
          url: mId, // Store raw manga_id in url field
          coverUrl: coverUrl,
          sourceId: id,
          status: status,
          description: item['description'] as String?,
        ));
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Manga> getDetails(Manga manga) async {
    final mId = manga.url;
    try {
      final res = await KurokuHttpClient.instance.get<Map<String, dynamic>>(
        '$_apiBase/manga/detail/$mId',
        headers: headers,
      );

      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return manga;

      final desc = data['description'] as String?;
      final genres = <String>[];
      final tax = data['taxonomy'] as Map<String, dynamic>?;
      final genreList = tax?['Genre'] as List<dynamic>?;
      if (genreList != null) {
        for (final g in genreList) {
          if (g is Map<String, dynamic> && g['name'] != null) {
            genres.add(g['name'] as String);
          }
        }
      }

      return manga.copyWith(
        description: desc ?? manga.description,
        genres: genres,
      );
    } catch (_) {
      return manga;
    }
  }

  @override
  Future<List<MangaChapter>> getChapters(Manga manga) async {
    final mId = manga.url;
    try {
      final res = await KurokuHttpClient.instance.get<Map<String, dynamic>>(
        '$_apiBase/chapter/$mId/list?page=1&page_size=9999&sort_by=chapter_number&sort_order=desc',
        headers: headers,
      );

      final dataList = res.data?['data'] as List<dynamic>? ?? [];
      final chapters = <MangaChapter>[];

      for (final item in dataList) {
        if (item is! Map<String, dynamic>) continue;

        final chId = item['chapter_id'] as String? ?? '';
        final chNum = (item['chapter_number'] as num?)?.toDouble() ?? 0.0;
        final rawTitle = item['chapter_title'] as String?;
        final title = (rawTitle != null && rawTitle.trim().isNotEmpty)
            ? 'Chapter $chNum: $rawTitle'
            : 'Chapter $chNum';

        chapters.add(MangaChapter(
          id: '${id}_${manga.id}_$chId',
          mangaId: manga.id,
          title: title,
          number: chNum,
          url: chId, // Store raw chapter_id in url field
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
    final chId = chapter.url;
    try {
      final res = await KurokuHttpClient.instance.get<Map<String, dynamic>>(
        '$_apiBase/chapter/detail/$chId',
        headers: headers,
      );

      final data = res.data?['data'] as Map<String, dynamic>?;
      final chData = data?['chapter'] as Map<String, dynamic>?;
      final basePath = chData?['path'] as String? ?? '';
      final images = chData?['data'] as List<dynamic>? ?? [];

      final pages = <MangaPage>[];
      for (int i = 0; i < images.length; i++) {
        final imgExt = images[i] as String;
        pages.add(MangaPage(
          index: i,
          url: '$_cdnBase$basePath$imgExt',
          headers: headers,
        ));
      }

      return pages;
    } catch (_) {
      return [];
    }
  }
}
