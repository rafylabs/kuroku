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
  };

  @override
  List<String> get availableCategories => const [
    'All',
    'Manhwa',
    'Manga',
    'Manhua',
    'Project',
  ];

  @override
  List<String> get availableGenres => const [
    'All',
    'Action',
    'Adventure',
    'Comedy',
    'Cooking',
    'Crime',
    'Demon',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Fight',
    'Game',
    'Gender Bender',
    'Harem',
    'Historical',
    'Horror',
    'Isekai',
    'Josei',
    'Magic',
    'Martial Arts',
    'Mature',
    'Mecha',
    'Medical',
    'Murim',
    'Mystery',
    'Psychological',
    'Regression',
    'Reincarnation',
    'Revenge',
    'Romance',
    'School Life',
    'Sci-fi',
    'Seinen',
    'Shoujo',
    'Shounen',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
    'Tragedy',
    'Wuxia',
  ];

  static const Map<String, String> _genreSlugMap = {
    'action': 'action',
    'adaptation': 'adaptation',
    'adult': 'adult',
    'adventure': 'adventure',
    'comedy': 'comedy',
    'cooking': 'cooking',
    'crime': 'crime',
    'demon': 'demon',
    'demons': 'demons',
    'drama': 'drama',
    'ecchi': 'ecchi',
    'fantasy': 'fantasy',
    'fight': 'fight',
    'fighting': 'fighting-genre',
    'game': 'game',
    'gender bender': 'gender-bender',
    'harem': 'harem',
    'historical': 'historical',
    'horror': 'horror',
    'isekai': 'isekai',
    'josei': 'josei-genre',
    'latest': 'latest',
    'love': 'love',
    'magic': 'magic',
    'martial arts': 'martial-arts',
    'mature': 'mature',
    'mecha': 'mecha',
    'medical': 'medical',
    'murim': 'murim',
    'mystery': 'mystery',
    'philosophical': 'philosophical',
    'psychological': 'psychological',
    'regression': 'regression',
    'reincarnation': 'reincarnation-genre',
    'revenge': 'revenge',
    'romance': 'romance',
    'school life': 'school-life',
    'sci-fi': 'sci-fi',
    'seinen': 'seinen',
    'shoujo': 'shoujo',
    'shounen': 'shounen',
    'slice of life': 'slice-of-life',
    'smut': 'smut',
    'sports': 'sports',
    'supernatural': 'supernatural',
    'supranatural': 'supranatural',
    'thriller': 'thriller',
    'tragedy': 'tragedy',
    'violence': 'violence',
    'wuxia': 'wuxia',
  };

  String _toGenreSlug(String genre) {
    final lower = genre.trim().toLowerCase();
    return _genreSlugMap[lower] ?? lower.replaceAll(' ', '-');
  }

  @override
  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
    String? category,
  }) async {
    final sort = order == SortOrder.popular ? 'popularity' : 'latest';
    String url = '$_apiBase/manga/list?page=$page&page_size=24&sort=$sort&sort_order=desc';

    if (query != null && query.trim().isNotEmpty) {
      final q = Uri.encodeComponent(query.trim());
      url += '&q=$q';
    }

    if (category != null && category.trim().isNotEmpty && category.trim().toLowerCase() != 'all') {
      final cat = category.trim().toLowerCase();
      if (cat == 'project' || cat == 'mirror') {
        url += '&type=$cat';
      } else {
        url += '&format=$cat';
      }
    }

    if (genre != null && genre.trim().isNotEmpty && genre.trim().toLowerCase() != 'all') {
      final slug = _toGenreSlug(genre);
      url += '&genre=${Uri.encodeComponent(slug)}';
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

        String coverUrl = '';
        final portrait = item['cover_portrait_url'] as String?;
        final cover = item['cover_image_url'] as String?;
        if (portrait != null && portrait.trim().isNotEmpty) {
          coverUrl = portrait.trim();
        } else if (cover != null && cover.trim().isNotEmpty) {
          coverUrl = cover.trim();
        }

        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = coverUrl.startsWith('/') ? '$_cdnBase$coverUrl' : '$_cdnBase/$coverUrl';
        }

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

      final authors = <String>[];
      final authorList = tax?['Author'] as List<dynamic>?;
      if (authorList != null) {
        for (final a in authorList) {
          if (a is Map<String, dynamic> && a['name'] != null) {
            authors.add(a['name'] as String);
          }
        }
      }

      final artists = <String>[];
      final artistList = tax?['Artist'] as List<dynamic>?;
      if (artistList != null) {
        for (final a in artistList) {
          if (a is Map<String, dynamic> && a['name'] != null) {
            artists.add(a['name'] as String);
          }
        }
      }

      final altTitle = data['alternative_title'] as String?;
      final rawStatus = data['status'];
      MangaStatus status = manga.status;
      if (rawStatus == 1 || rawStatus == '1' || rawStatus == 'Ongoing') {
        status = MangaStatus.ongoing;
      } else if (rawStatus == 2 || rawStatus == '2' || rawStatus == 'Completed') {
        status = MangaStatus.completed;
      }

      String coverUrl = manga.coverUrl;
      if (coverUrl.isEmpty) {
        final portrait = data['cover_portrait_url'] as String?;
        final cover = data['cover_image_url'] as String?;
        if (portrait != null && portrait.trim().isNotEmpty) {
          coverUrl = portrait.trim();
        } else if (cover != null && cover.trim().isNotEmpty) {
          coverUrl = cover.trim();
        }
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = coverUrl.startsWith('/') ? '$_cdnBase$coverUrl' : '$_cdnBase/$coverUrl';
        }
      }

      return manga.copyWith(
        description: desc ?? manga.description,
        genres: genres,
        coverUrl: coverUrl.isNotEmpty ? coverUrl : manga.coverUrl,
        author: authors.isNotEmpty ? authors.join(', ') : manga.author,
        artist: artists.isNotEmpty ? artists.join(', ') : manga.artist,
        altTitle: (altTitle != null && altTitle.trim().isNotEmpty) ? altTitle.trim() : manga.altTitle,
        status: status,
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

        final releaseDateStr = item['release_date'] as String? ?? item['created_at'] as String?;
        final uploadDate = releaseDateStr != null ? DateTime.tryParse(releaseDateStr) : null;

        chapters.add(MangaChapter(
          id: '${id}_${manga.id}_$chId',
          mangaId: manga.id,
          title: title,
          number: chNum,
          url: chId, // Store raw chapter_id in url field
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
