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

  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
  });

  Future<Manga> getDetails(Manga manga);

  Future<List<MangaChapter>> getChapters(Manga manga);

  Future<List<MangaPage>> getPages(MangaChapter chapter);
}
