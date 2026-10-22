import '../database/models/manga.dart';
import '../database/models/chapter.dart';
import '../database/models/manga_page.dart';

abstract class MangaParser {
  String get id;
  String get name;
  String get domain;
  String get locale;
  String get iconUrl => 'https://$domain/favicon.ico';

  Map<String, String> get headers => {
    'Referer': 'https://$domain/',
  };

  List<String> get availableCategories => const ['All', 'Manhwa', 'Manga', 'Manhua'];
  List<String> get availableGenres => const [
    'All',
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
    'Horror',
    'Isekai',
    'Martial Arts',
    'Mystery',
    'Psychological',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Supernatural',
    'Thriller',
  ];

  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
    String? category,
  });

  Future<Manga> getDetails(Manga manga);

  Future<List<MangaChapter>> getChapters(Manga manga);

  Future<List<MangaPage>> getPages(MangaChapter chapter);
}
